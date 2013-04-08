module ActiveRecord

  module ConnectionAdapters

    module Akiban

      module SchemaStatements

       NATIVE_DATABASE_TYPES = {
          primary_key: "serial primary key",
          string:      { name: "varchar", limit: 255 },
          text:        { name: "clob" },
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

        def recreate_database(name, options = {})
          drop_database(name)
          create_database(name, options)
        end

        def create_database(name, options = {})
          # TODO: use options
          execute "CREATE SCHEMA #{quote_table_name(name)}"
        end

        def drop_database(name)
          execute "DROP SCHEMA IF EXISTS #{quote_table_name(name)} CASCADE"
        end

        def columns(table_name, name = nil)
          return [] if table_name.blank?
          column_definitions(table_name).map do |column_name, type, nullable|
            AkibanColumn.new(column_name, nil, type, nullable == 'YES')
          end
        end

        def tables(name = nil)
          query(<<-end_sql).map { |row| row[0] }
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = #{name ? "'#{name}'" : "CURRENT_SCHEMA"}
            ORDER BY table_name
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
            AND table_schema = #{schema ? "'#{schema}'" : "CURRENT_SCHEMA"}
          sql
        end

        def indexes(table_name, name = nil)
          result = query(<<-sql, 'SCHEMA')
            SELECT   DISTINCT i.index_name, i.is_unique
            FROM     information_schema.indexes i
            WHERE    i.table_name = '#{table_name}'
            AND      i.schema_name = #{name ? "'#{name}'" : "CURRENT_SCHEMA"}
            AND      i.index_type <> 'PRIMARY'
            AND      i.index_name <> 'id'
            ORDER BY i.index_name
          sql

          indexes = []
          result.map do |row|
            index_name = row[0]
            unique = row[1] == 'YES'
            idx_columns = Hash[query(<<-sql, 'SCHEMA')]
              SELECT ic.column_name, ic.is_ascending
              FROM   information_schema.index_columns ic
              WHERE  ic.index_table_name = '#{table_name}'
                     AND ic.schema_name = #{name ? "'#{name}'" : "CURRENT_SCHEMA"}
                     AND ic.index_name = '#{index_name}'
              sql

            unless idx_columns.empty?
              # TODO: use the ASC/DESC information for each index column
              indexes << IndexDefinition.new(table_name, index_name, unique, idx_columns.keys)
            end
          end

          indexes
        end

        def schema_exists?(name)
          exec_query(<<-sql, 'SCHEMA').rows.first[0].to_i > 0
            SELECT COUNT(*)
            FROM   information_schema.schemata
            WHERE schema_name = '#{name}'
          sql
        end

        # Returns the current schema name.
        def current_schema
          query('SELECT current_schema')[0][0]
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

        def remove_index!(table_name, index_name) #:nodoc:
          execute "DROP INDEX #{quote_table_name(table_name)}.#{quote_table_name(index_name)}"
        end

        def add_grouping_foreign_key(child_table, parent_table, child_column, parent_column = nil)
            add_grouping(child_table, parent_table, child_column, parent_column)
        end

        def drop_grouping_foreign_key(child_table)
          remove_grouping(child_table)
        end

        def create_table(table_name, options = {})
          super(table_name, options)
          if options[:grouping_foreign_key]
            add_grouping(table_name, options[:parent_table], options[:grouping_foreign_key])
          end
        end

        def drop_table(table_name, options = {})
          if options[:drop_group]
            execute "DROP GROUP #{quote_table_name(table_name)}"
          else
            super(table_name, options)
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

        # Returns a SELECT DISTINCT clause for a given set of columns
        # and a given ORDER BY clause.
        #
        # Akiban requires that the ORDER BY columns in the SELECT list
        # for DISTINCT queries, and requires that the ORDER BY include
        # the DISTINCT column.
        def distinct(columns, orders) #:nodoc:
          return "DISTINCT #{columns}" if orders.empty?
          # Construct a clean list of column names from the ORDER BY clause, removing
          # any ASC/DESC modifiers
          order_columns = orders.collect { |s| s.gsub(/\s+(ASC|DESC)\s*(NULLS\s+(FIRST|LAST)\s*)?/i, '') }
          order_columns.delete_if { |c| c.blank? }
          order_columns = order_columns.zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

          "DISTINCT #{columns}, #{order_columns * ', '}"
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
            AND c.schema_name = CURRENT_SCHEMA
            ORDER BY c.position
          end_sql
        end

        # Return the name of the sequence associated with the given
        # column from the given table.
        def get_seq_name(table_name, schema_name, col_name)
          #table_name.gsub!(/"/, '')
          #col_name.gsub!(/"/, '')
          row = exec_query(<<-end_sql).rows.first
            SELECT c.sequence_name
            FROM   information_schema.columns c
            WHERE  c.table_name = '#{table_name}'
            AND c.schema_name = '#{schema_name}'
            AND c.column_name = '#{col_name}'
          end_sql
          row && row.first
        end

      private

        def add_grouping(child_table, parent_table, child_column, parent_column = nil)
          execute "ALTER TABLE #{quote_table_name(child_table)} ADD GROUPING FOREIGN KEY (#{quote_column_name(child_column)}) REFERENCES #{quote_table_name(parent_table)} #{"(#{quote_column_name(quote_parent_column)})" if parent_column}"
        end

        def remove_grouping(child_table)
          execute "ALTER TABLE #{quote_table_name(child_table)} DROP GROUPING FORIEGN KEY"
        end

        def extract_schema_and_table(name)
          table, schema = name.scan(/[^".\s]+|"[^"]*"/)[0..1].collect{|m| m.gsub(/(^"|"$)/,'') }.reverse
          [schema, table]
        end

      end # SchemaStatements

    end # Akiban

  end # ConnectionAdapters

end # ActiveRecord
