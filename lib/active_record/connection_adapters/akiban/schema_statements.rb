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
            WHERE table_schema = '#{name}'
          end_sql
        end

        # Maps logical Rails types to Akiban-specific data types.
        def type_to_sql(type, limit = nil, precision = nil, scale = nil)
          case type.to_s
          when 'integer'
            return 'integer' unless limit
            case limit
              when 1, 2; 'smallint'
              when 3, 4; 'integer'
              when 5..8; 'bigint'
              else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
            end
          when 'decimal'
            # Akiban supports precision up to 31
            if precision > 32
              precision = 31
            end
            super
          else
            super
          end
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
            WHERE c.table_name = '#{table_name}'
            ORDER BY c.position
          end_sql
        end

      end # SchemaStatements

    end # Akiban

  end # ConnectionAdapters

end # ActiveRecord
