require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/connection_adapters/postgresql/oid/type_map_initializer'

module ActiveRecord
  module ConnectionHandling

    def redshift_connection(config)

      conn_params = config.symbolize_keys

      conn_params.delete_if { |_, v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PG::Connection.connect.
      valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
      conn_params.slice!(*valid_conn_param_keys)

      # The postgres drivers don't allow the creation of an unconnected PG::Connection object,
      # so just pass a nil connection object for the time being.
      ConnectionAdapters::RedshiftAdapter.new(nil, logger, conn_params, config)

    end

  end

  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      def configure_connection
        if @config[:encoding]
          @connection.set_client_encoding(@config[:encoding])
        end
        self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

        # SET statements from :variables config hash
        # http://www.postgresql.org/docs/8.3/static/sql-set.html
        variables = @config[:variables] || {}
        variables.map do |k, v|
          if v == ':default' || v == :default
            # Sets the value to the global or compile default
            execute("SET SESSION #{k} TO DEFAULT", 'SCHEMA')
          elsif !v.nil?
            execute("SET SESSION #{k} TO #{quote(v)}", 'SCHEMA')
          end
        end
      end


      def load_additional_types(oids = nil)
        initializer = OID::TypeMapInitializer.new(type_map)

        # rails 6.1 dropped support for supports_ranges? and PG below 9.3
        # https://guides.rubyonrails.org/6_1_release_notes.html#active-record
        # Solution:
        # check if adapter has supports_ranges? defined.
        # if YES we will use it and if NO we will assume it is true

        supports_ranges = true
        if self.method_defined? :supports_ranges?
          supports_ranges = supports_ranges?
        end

        if supports_ranges
          query = <<-SQL
            SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype
            FROM pg_type as t
            LEFT JOIN pg_range as r ON oid = rngtypid
          SQL
        else
          query = <<-SQL
            SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, t.typtype, t.typbasetype
            FROM pg_type as t
          SQL
        end

        if oids
          query += "WHERE t.oid::integer IN (%s)" % oids.join(", ")
        end

        execute_and_clear(query, 'SCHEMA', []) do |records|
          initializer.run(records)
        end
      end
    end

    class RedshiftAdapter < PostgreSQLAdapter

      def initialize(connection, logger, connection_parameters, config)
        @connection = PG::Connection.connect(connection_parameters)
        super(@connection, logger, connection_parameters, config)
        @use_insert_returning = @config.key?(:insert_returning) ? self.class.type_cast_config_to_boolean(@config[:insert_returning]) : false
      end


      def set_standard_conforming_strings
      end
      def client_min_messages=(level)
      end

      def database_version
        90500
      end

      def supports_statement_cache?
        false
      end

      def supports_index_sort_order?
        false
      end

      def supports_partial_index?
        false
      end

      def supports_transaction_isolation?
        false
      end

      def supports_foreign_keys?
        false
      end

      def supports_views?
        false
      end

      def supports_extensions?
        false
      end

      def supports_ranges?
        false
      end

      def supports_materialized_views?
        false
      end

      def use_insert_returning?
        false
      end

      def supports_advisory_locks?
        false
      end

      def supports_ranges?
        false
      end


      # remove pg_collation join
      def column_definitions(table_name)
        query(<<-end_sql, "SCHEMA")
            SELECT a.attname, format_type(a.atttypid, a.atttypmod),
                   pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod,
                   col_description(a.attrelid, a.attnum) AS comment
              FROM pg_attribute a
              LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
              LEFT JOIN pg_type t ON a.atttypid = t.oid
             WHERE a.attrelid = #{quote(quote_table_name(table_name))}::regclass
               AND a.attnum > 0 AND NOT a.attisdropped
             ORDER BY a.attnum
        end_sql
      end

      # FIX primary keys to not include generate_subscripts
      def primary_keys(table_name) # :nodoc:
        scope = quoted_scope(table_name)
        select_values(<<-SQL.strip_heredoc, "SCHEMA")
          SELECT column_name
            FROM information_schema.key_column_usage kcu
            JOIN information_schema.table_constraints tc
           USING (table_schema, table_name, constraint_name)
           WHERE constraint_type = 'PRIMARY KEY'
             AND kcu.table_name = #{scope[:name]}
             AND kcu.table_schema = #{scope[:schema]}
           ORDER BY kcu.ordinal_position
        SQL
      end

      def execute(sql, name=nil)
        if name == "SCHEMA" && sql.start_with?("SET time zone")
          return
        else
          super
        end
      end
    end
  end
end


