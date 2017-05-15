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
    class RedshiftAdapter < PostgreSQLAdapter
      def set_standard_conforming_strings
      end
      def client_min_messages=(level)
      end 

      def postgresql_version
        90100
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


