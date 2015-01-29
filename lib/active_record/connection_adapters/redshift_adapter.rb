require 'active_record/connection_adapters/postgresql_adapter'


module ActiveRecord
  module ConnectionHandling

    def redshift_connection(config)
      conn_params = config.symbolize_keys

      conn_params.delete_if { |_, v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PGconn.connect.
      conn_params.keep_if { |k, _| VALID_CONN_PARAMS.include?(k) }

      # The postgres drivers don't allow the creation of an unconnected PGconn object,
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
        80200
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

