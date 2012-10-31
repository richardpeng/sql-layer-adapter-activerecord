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

        # Returns true if table exists.
        # If the schema is not specified as part of +name+ then it will 
        # find tables that match from any schema.
        # TODO: are we doing the correct thing when no schema is specified?
        def table_exists?(name)
          schema, table = extract_schema_and_table(name.to_s)
          return false unless table

          binds = [[nil, table]]
          binds << [nil, schema] if schema

          exec_query(<<-sql, 'SCHEMA', binds).rows.first[0].to_i > 0
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_name = $1
            #{schema ? 'AND table_schema = $2' : ''}
          sql
        end

        # Returns the current schema name.
        # TODO: use current_schema function when it is available.
        def current_schema
          query('SELECT current_user')[0][0]
        end

        def rename_table(old_name, new_name)
          execute "RENAME TABLE #{quote_table_name(old_name)} TO #{quote_table_name(new_name)}"
        end

        def add_column(table_name, column_name, type, options = {})
          add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(add_column_sql, options)
          execute add_column_sql
        end

        def change_column(table_name, column_name, type, options = {})
          execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DATA TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
          change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
        end

        def change_column_default(table_name, column_name, default)
          execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}"
        end

        def change_column_null(table_name, column_name, null, default = nil)
          execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} #{null ? '' : 'NOT'} NULL")
        end

        def remove_column(table_name, *column_names)
          column_names.flatten.each do |column_name|
            execute "ALTER TABLE #{quote_table_name(table_name)} DROP COLUMN #{quote_column_name(column_name)}"
          end
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

      private

        def extract_schema_and_table(name)
          table, schema = name.scan(/[^".\s]+|"[^"]*"/)[0..1].collect{|m| m.gsub(/(^"|"$)/,'') }.reverse
          [schema, table]
        end

      end # SchemaStatements

    end # Akiban

  end # ConnectionAdapters

end # ActiveRecord
