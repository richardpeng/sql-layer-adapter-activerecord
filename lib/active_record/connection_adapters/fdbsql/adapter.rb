require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'arel/visitors/bind_visitor'

require 'active_record/connection_adapters/fdbsql/column'
require 'active_record/connection_adapters/fdbsql/database_limits'
require 'active_record/connection_adapters/fdbsql/database_statements'
require 'active_record/connection_adapters/fdbsql/quoting'
require 'active_record/connection_adapters/fdbsql/schema_statements'
require 'active_record/connection_adapters/fdbsql/statement_pool'

# FoundationDB SQL Layer currently uses the Postgres protocol
gem 'pg', '~> 0.11'
require 'pg'

module ActiveRecord

  class Base

    def self.fdbsql_connection(config)
      config = config.symbolize_keys
      host = config[:host] || "localhost"
      port = config[:port] || 15432
      user = config[:username].to_s if config[:username]
      pass = config[:password].to_s if config[:password]

      if config.key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing config option: database"
      end

      # pg doesn't allow unconnected connections so just forward parameters
      conn_hash = {
        :host => host,
        :port => port,
        :dbname => database,
        :user => user,
        :password => pass
      }
      ConnectionAdapters::FdbSqlAdapter.new(nil, logger, conn_hash, config)
    end

  end


  module ConnectionAdapters

    class FdbSqlAdapter < AbstractAdapter

      class Arel::Visitors::FdbSql < Arel::Visitors::ToSql
        private
          # NB: Second argument added in 4.0.1
          def visit_Arel_Nodes_Lock(o, a = nil)
            # Locks not supported
          end
      end


      class BindSubstitution < Arel::Visitors::FdbSql
        include Arel::Visitors::BindVisitor
      end


      include FdbSql::DatabaseLimits
      include FdbSql::DatabaseStatements
      include FdbSql::Quoting
      include FdbSql::SchemaStatements


      def initialize(connection, logger, connection_hash, config)
        super(connection, logger)
        if config.fetch(:prepared_statements) { true }
          @visitor = Arel::Visitors::FdbSql.new self
        else
          @visitor = BindSubstitution.new self
        end
        @connection_hash = connection_hash
        @config = config
        connect
        @statements = FdbSql::StatementPool.new(@connection, config.fetch(:statement_limit) { 1000 })
      end


      # ADAPTER ==================================================

      def adapter_name
        ADAPTER_NAME
      end

      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_count_distinct?
        true
      end

      def supports_ddl_transactions?
        false
      end

      def supports_bulk_alter?
        false
      end

      def supports_savepoints?
        false
      end

      def prefetch_primary_key?(table_name = nil)
        false
      end

      def supports_index_sort_order?
        # As of 1.9.2, DESC is parsed but rejected
        false
      end

      def supports_explain?
        true
      end

      def supports_insert_with_returning?
        true
      end


      # REFERENTIAL INTEGRITY ====================================

      def disable_referential_integrity
        # Not yet supported
        yield
      end


      # CONNECTION MANAGEMENT ====================================

      def active?
        @connection.query 'SELECT 1'
        true
      rescue PGError
        false
      end

      def reconnect!
        super
        clear_cache!
        @connection.reset
        @open_transactions = 0
        configure_connection
      end

      def disconnect!
        super
        clear_cache!
        @connection.close
      rescue
        nil
      end

      def reset!
        super
        clear_cache!
      end

      def clear_cache!
        @statements.clear
      end


      protected

        def translate_exception(exception, message)
          case exception.result.try(:error_field, PGresult::PG_DIAG_SQLSTATE)
          when DUPLICATE_KEY_CODE
            RecordNotUnique.new(message, exception)
          when FK_REFERENCING_VIOLATION_CODE, FK_REFERENCED_VIOLATION_CODE
            InvalidForeignKey.new(message, exception)
          else
            super
          end
        end

        def stmt_cache_prefix
          @config[:database]
        end

      private

        ADAPTER_NAME = 'FDBSQL'.freeze
        DUPLICATE_KEY_CODE = '23501'
        FK_REFERENCING_VIOLATION_CODE = '23503'
        FK_REFERENCED_VIOLATION_CODE = '23504'


        def connect
          @connection = PG::Connection.new(@connection_hash)
          # Swallow warnings
          @connection.set_notice_receiver { |proc| }
          # TODO: Check FDB SQL version
        end

        def configure_connection
          if @config[:encoding]
            @connection.set_client_encoding(@config[:encoding])
          end

          # TODO: Timezone when supported by SQL Layer
          #if ActiveRecord::Base.default_timezone == :utc
          #  # Set conn to UTC
          #elsif @local_tz
          #  # SET conn to @local_tz
          #end
        end

    end

  end

end

