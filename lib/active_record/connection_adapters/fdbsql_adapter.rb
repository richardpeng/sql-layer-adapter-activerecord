require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/fdbsql/database_statements'
require 'active_record/connection_adapters/fdbsql/quoting'
require 'active_record/connection_adapters/fdbsql/schema_statements'
require 'arel/visitors/bind_visitor'

# FoundationDB SQL Layer implements the PostgreSQL protocol
require 'pg'

module ActiveRecord

  class Base

    def self.fdbsql_connection(config)
      conn_params = config.symbolize_keys
      # Forward any unused config params to PGconn.connect.
      [:statement_limit, :encoding, :min_messages, :schema_search_path,
       :schema_order, :adapter, :pool, :checkout_timeout, :timeout, :template,
       :reaping_frequency, :mode, :insert_returning].each do |key|
        conn_params.delete key
      end
      conn_params.delete_if { |k,v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # The postgres drivers don't allow the creation of an unconnected PGconn object,
      # so just pass a nil connection object for the time being.
      ConnectionAdapters::FDBSQLAdapter.new(nil, logger, conn_params, config)
    end

  end # Base

  module ConnectionAdapters

    class FDBSQLColumn < Column

      def initialize(name, default, sql_type = nil, null = true)
        super(name, default, sql_type, null)
      end

    end # FDBSQLColumn

    class FDBSQLAdapter < AbstractAdapter

      include FDBSQL::DatabaseStatements
      include FDBSQL::Quoting
      include FDBSQL::SchemaStatements

      class Arel::Visitors::FDBSQL < Arel::Visitors::PostgreSQL
        # Don't support FOR UPDATE (and don't have row locks anyway).
        def visit_Arel_Nodes_Lock o
          nil
        end
      end

      class BindSubstitution < Arel::Visitors::FDBSQL
        include Arel::Visitors::BindVisitor
      end

      ADAPTER_NAME = 'FDBSQL'.freeze

      # Initializes and connects a FDBSQL adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger)
        if config.fetch(:prepared_statements) { true}
          @visitor = Arel::Visitors::FDBSQL.new self
        else
          @visitor = BindSubstitution.new self
        end
        connection_parameters.delete :prepared_statements
        @connection_parameters, @config = connection_parameters, config
        connect
      end

      # ABSTRACT ADAPTER ========================================

      def adapter_name
        ADAPTER_NAME
      end

      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_index_sort_order?
        true
      end

      def supports_explain?
        true
      end

      def supports_insert_with_returning?
        true
      end

      # QUOTING ==================================================

      # REFERENTIAL INTEGRITY ====================================

      # CONNECTION MANAGEMENT ====================================

      def active?
        @connection.query 'SELECT 1'
        true
      rescue PGError
        false
      end

      def reconnect!
        super
        @connection.reset
      end

      def disconnect!
        @connection.close rescue nil
      end

      def reset!
        super
      end

      # ABSTRACT ADAPTER (MISC SUPPORT) =========================

      def primary_key(table_name)
        row = exec_query(<<-sql, 'SCHEMA').rows.first
          SELECT DISTINCT(ic.column_name)
          FROM information_schema.index_columns ic
          WHERE ic.index_table_name = '#{table_name}'
          AND ic.schema_name = CURRENT_SCHEMA
          AND ic.index_name = 'PRIMARY'
        sql
        row && row.first
      end

      protected

      # FOUNDATIONDB SQL SPECIFIC =========================================

      UNIQUE_VIOLATION = "23501"

      def translate_exception(exception, message)
        case exception.result.try(:error_field, PGresult::PG_DIAG_SQLSTATE)
        when UNIQUE_VIOLATION
          RecordNotUnique.new(message, exception)
        else
          super
        end
      end

      def connect
        @connection = PGconn.connect(@connection_parameters)
        # swallow warnings for now
        @connection.set_notice_receiver { |proc| }
      end

    end # FDBSQLAdapter

  end # ConnectionAdapters

end # ActiveRecord
