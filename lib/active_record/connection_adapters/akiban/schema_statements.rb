module ActiveRecord

  module ConnectionAdapters

    module Akiban

      module SchemaStatements

       NATIVE_DATABASE_TYPES = {
          primary_key: "serial primary key",
          string:      { name: "varchar", limit: 255 },
          text:        { name: "blob" },
          integer:     { name: "integer" },
          float:       { name: "float" },
          decimal:     { name: "decimal" },
          datetime:    { name: "datetime" },
          timestamp:   { name: "timestamp" },
          time:        { name: "time" },
          date:        { name: "date" },
          binary:      { name: "blob" },
          boolean:     { name: "boolean" }
        }

        def native_database_types
          NATIVE_DATABASE_TYPES
        end

        def columns(table_name, name = nil)
          return [] if table_name.blank?
          column_definitions(table_name).map do |column_name, type, nullable|
            AkibanColumn.new(column_name, nil, type, nullable == 'YES')
          end
        end

        def tables(name = nil)
          exec_query(<<-end_sql).rows
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = '#{quote_table_name(name)}'
          end_sql
        end

        protected

        # AKIBAN SPECIFIC =======================================

        # Returns the list of a table's column names, data types, and default
        # values.
        #
        # The underlying query is roughly:
        #
        #  SELECT c.column_name, c.type, c.nullable
        #  FROM information_schema.columns c
        #  WHERE c.table_name = 'table_name'
        #  ORDER BY c.position
        #
        # TODO: default values need to be retrieved.
        def column_definitions(table_name)
          exec_query(<<-end_sql).rows
            SELECT c.column_name, c.type, c.nullable
            FROM information_schema.columns c
            WHERE c.table_name = '#{quote_table_name(table_name)}'
            ORDER BY c.position
          end_sql
        end

      end # SchemaStatements

    end # Akiban

  end # ConnectionAdapters

end # ActiveRecord
