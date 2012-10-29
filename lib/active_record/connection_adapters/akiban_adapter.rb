require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/akiban/database_statements'
require 'active_record/connection_adapters/akiban/quoting'
require 'active_record/connection_adapters/akiban/schema_statements'
require 'arel/visitors/bind_visitor'

# Akiban implements the PostgreSQL protocol
require 'pg'

module ActiveRecord

  class Base

    def self.akiban_connection(config) #:nodoc:
      conn_params = config.symbolize_keys
      # Forward any unused config params to PGconn.connect.
      [:statement_limit, :encoding, :min_messages, :schema_search_path,
       :schema_order, :adapter, :pool, :checkout_timeout, :template,
       :reaping_frequency, :mode, :insert_returning].each do |key|
        conn_params.delete key
      end
      conn_params.delete_if { |k,v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # The postgres drivers don't allow the creation of an unconnected PGconn object,
      # so just pass a nil connection object for the time being.
      ConnectionAdapters::AkibanAdapter.new(nil, logger, conn_params, config)
    end

  end # Base

  module ConnectionAdapters

    class AkibanColumn < Column

      def initialize(name, default, sql_type = nil, null = true)
        super(name, default, sql_type, null)
      end

    end # AkibanColumn

    class AkibanAdapter < AbstractAdapter

      include Akiban::DatabaseStatements
      include Akiban::Quoting
      include Akiban::SchemaStatements

      class BindSubstitution < Arel::Visitors::PostgreSQL
        include Arel::Visitors::BindVisitor
      end

      ADAPTER_NAME = 'Akiban'.freeze

      # Initializes and connects an Akiban adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger)
        # we can reuse from PostgreSQL adapter here
        if config.fetch(:prepared_statements) { true}
          @visitor = Arel::Visitors::PostgreSQL.new self
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

      protected

      # AKIBAN SPECIFIC =========================================

      def connect
        @connection = PGconn.connect(@connection_parameters)
      end

    end # AkibanAdapter

  end # ConnectionAdapters

end # ActiveRecord
