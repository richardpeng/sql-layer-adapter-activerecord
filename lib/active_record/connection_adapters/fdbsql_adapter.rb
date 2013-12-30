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

      def supports_ddl_transactions?
        false
      end

      def index_name_length
        # pg driver has a hard limit of NAMEDATALEN-1
        63
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
          AND ic.index_table_schema = CURRENT_SCHEMA
          AND ic.index_name = 'PRIMARY'
        sql
        row && row.first
      end


      # ABSTRACT ADAPTER (OPTIONAL TEST METHODS) ======================

      # Resets the sequence of a table's primary key to the maximum value.
      def reset_pk_sequence!(table) #:nodoc:
        pk_col, seq_schema, seq_name = pk_and_sequence_for(table)

        if pk_col && !seq_schema
          @logger.warn "#{table} has primary key #{pk_col} with no sequence" if @logger
        end

        if pk_col && seq_schema
          quoted_col = quote_column_name(pk_col)
          seq_from_where = "FROM information_schema.sequences WHERE sequence_schema='#{seq_schema}' AND sequence_name='#{seq_name}'"
          result = query(<<-end_sql, 'FDBSQL')
            SELECT COALESCE(MAX(#{quoted_col} + (SELECT increment #{seq_from_where})), (SELECT minimum_value #{seq_from_where})) FROM #{quote_table_name(table)}
          end_sql

          if result.length == 1
            @logger.debug "Resetting sequence #{seq_schema}.#{seq_name} to #{result}" if @logger
            # The COMMIT .. BEGIN can go away when 1) transactional DDL is available 2) There is a better restart/set function
            query(<<-end_sql, 'FDBSQL')
              COMMIT; CALL sys.alter_seq_restart('#{seq_schema}', '#{seq_name}', #{result[0][0]}); BEGIN;
            end_sql
          else
            @logger.warn "Unable to determin max value for #{table}.#{pk_col}" if @logger
          end
        end
      end#


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


      private

      # Returns a table's primary key and associated sequence or nil if none
      def pk_and_sequence_for(table) #:nodoc:
        result = query(<<-end_sql, 'FDBSQL')
          SELECT kc.column_name,
                 c.sequence_schema,
                 c.sequence_name
          FROM information_schema.table_constraints tc
          INNER JOIN information_schema.key_column_usage kc
            ON  tc.table_name=kc.table_name
            AND tc.constraint_name=kc.constraint_name
          INNER JOIN information_schema.columns c
            ON  kc.table_name=c.table_name
            AND kc.column_name=c.column_name
          WHERE tc.table_name='#{table}'
            AND tc.constraint_type='PRIMARY KEY'
        end_sql
        return (result.length == 1) ? result[0] : nil
      rescue
        nil
      end

    end # FDBSQLAdapter

  end # ConnectionAdapters

end # ActiveRecord
