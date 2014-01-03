module ActiveRecord

  module ConnectionAdapters

    module FdbSql

      module SchemaStatements

        # Returns a Hash of mappings from the abstract data types to the native
        # database types. See TableDefinition#column for details on the recognized
        # abstract data types.
        def native_database_types
          NATIVE_DATABASE_TYPES
        end

        # Returns true if table exists.
        # If the schema is not specified as part of +name+ then it will only find tables within
        # the current schema search path (regardless of permissions to access tables in other schemas)
        def table_exists?(table_name)
          return false unless table_name
          schema, table = split_table_name(table_name)
          tables(nil, schema, table).any?
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil)
          select_rows(
            "SELECT index_name, "+
            "       is_unique "+
            "FROM information_schema.indexes "+
            "WHERE table_schema = CURRENT_SCHEMA "+
            "  AND table_name = '#{quote_string(table_name.to_s)}' "+
            "  AND index_type <> 'PRIMARY' "+
            "ORDER BY index_name",
            name || SCHEMA_LOG_NAME
          ).map { |row|
            cols = select_rows(
              "SELECT column_name "+
              "FROM information_schema.index_columns "+
              "WHERE index_table_schema = CURRENT_SCHEMA "+
              "  AND index_table_name = '#{quote_string(table_name.to_s)}' "+
              "  AND index_name = '#{quote_string(row[0])}' "+
              "ORDER BY ordinal_position",
              name || SCHEMA_LOG_NAME
            ).map { |col_row|
              col_row[0]
            }
            IndexDefinition.new(table_name, row[0], row[1] == 'YES', cols, [], {})
          }
        end

        # Returns an array of Column objects for the table specified by +table_name+.
        # See the concrete implementation for details on the expected parameter values.
        def columns(table_name, name = nil)
          select_rows(
            "SELECT column_name, "+
            "       column_default, "+
            "       REPLACE(COLUMN_TYPE_STRING(table_schema, table_name, column_name), ' ', ''), "+
            "       is_nullable "+
            "FROM information_schema.columns "+
            "WHERE table_schema = CURRENT_SCHEMA "+
            "  AND table_name = '#{quote_string(table_name.to_s)}' "+
            "ORDER BY ordinal_position",
            name || SCHEMA_LOG_NAME
          ).map { |row|
            FdbSqlColumn.new(row[0], row[1], row[2], row[3] == 'YES')
          }
        end

        # Returns the sequence name for the table specified by +table_name+.
        def default_sequence_name(table_name, column = nil)
          pk, seq = pk_and_sequence_for(table_name)
          if column && (pk != column)
            # Is this ever actually called with a non-pk column?
            nil
          else
            seq
          end
        rescue
          nil
        end

        # Renames a table
        def rename_table(old_name, new_name)
          execute(
            "RENAME TABLE #{quote_table_name(old_name)} TO #{quote_table_name(new_name)}",
            SCHEMA_LOG_NAME
          )
        end

        # Adds a new column to the named table.
        # See TableDefinition#column for details of the options you can use.
        def add_column(table_name, column_name, type, options = {})
          # As of 1.9.2, identity cannot be present in ADD COLUMN. Perform in two statements.
          sql = "ALTER TABLE #{quote_table_name(table_name)} "+
                "ADD COLUMN #{quote_column_name(column_name)} "+
                "#{(type == :primary_key) ? PK_TYPE_BASE : type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(sql, options)
          if type == :primary_key
            sql = sql + "; "+
                  "ALTER TABLE #{quote_table_name(table_name)} "+
                  "ALTER COLUMN #{quote_column_name(column_name)} "+
                  "SET #{GENERATED_IDENTITY}"
          end
          execute(sql, SCHEMA_LOG_NAME)
        end

        # Removes the column(s) from the table definition.
        def remove_column(table_name, *column_names)
          if column_names.flatten!
            ActiveSupport::Deprecation.warn(
              'Passing array to remove_columns is deprecated, use multiple arguments',
              caller
            )
          end
          columns_for_remove(table_name, *column_names).each do |column_name|
            # column_name already quoted
            execute(
              "ALTER TABLE #{quote_table_name(table_name)} DROP COLUMN #{column_name}",
               SCHEMA_LOG_NAME
            )
          end
        end

        # Changes the column's definition according to the new options.
        # See TableDefinition#column for details of the options you can use.
        def change_column(table_name, column_name, type, options = {})
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} "+
            "ALTER COLUMN #{quote_column_name(column_name)} "+
            "SET DATA TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}",
            SCHEMA_LOG_NAME
          )
          change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
          change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
        end

        # Sets a new default value for a column.
        def change_column_default(table_name, column_name, default)
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN "+
            "#{quote_column_name(column_name)} SET DEFAULT #{quote(default)}",
            SCHEMA_LOG_NAME
          )
        end

        # Renames a column.
        def rename_column(table_name, column_name, new_column_name)
          unless columns(table_name).detect{ |c| c.name == column_name.to_s }
            raise ActiveRecord::ActiveRecordError, "No such column #{table_name}.#{column_name}"
          end
          clear_cache!
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN "+
            "#{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}",
            SCHEMA_LOG_NAME
          )
        end

        def remove_index!(table_name, index_name)
          execute(
            "DROP INDEX #{quote_table_name(table_name)}.#{quote_table_name(index_name)}",
            SCHEMA_LOG_NAME
          )
        end

        # Rename an index.
        def rename_index(table_name, old_name, new_name)
          # TODO: Implement when syntax is supported
          super
        end

        def type_to_sql(type, limit = nil, precision = nil, scale = nil)
          case type.to_s
          when 'integer'
            case limit
              when nil, 1..4; 'int'
              when 5..8; 'bigint'
              else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a decimal with precision 0 instead.")
            end
          when 'decimal'
            # NB: Maximum supported as of 1.9.2
            precision = 31 if precision.to_i > 31
            super
          else
            super
          end
        end

        # Returns a SELECT DISTINCT clause for a given set of columns
        # and a given ORDER BY clause.
        #
        # As with Postgres (where this was lifted from), the DISTINCT columns
        # must be present in the ORDER BY clause.
        def distinct(columns, orders)
          return super if orders.empty?

          # Construct a clean list of column names from the ORDER BY clause, removing
          # any ASC/DESC modifiers
          order_columns = orders.collect { |s| s.gsub(/\s+(ASC|DESC)\s*(NULLS\s+(FIRST|LAST)\s*)?/i, '') }
          order_columns.delete_if { |c| c.blank? }
          order_columns = order_columns.zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

          "DISTINCT #{columns}, #{order_columns * ', '}"
        end


        # EXTRA METHODS ============================================
        # Unspecified in base but a) used via responds_to or b) common among other adapters

        # Returns the list of all tables in the schema search path or a specified schema.
        def tables(name = nil, schema = nil, table = nil)
          schema = schema ? "'#{quote_string(schema)}'" : 'CURRENT_SCHEMA'
          select_rows(
            "SELECT table_name "+
            "FROM information_schema.tables "+
            "WHERE table_type = 'TABLE' "+
            "  AND table_schema = #{schema} "+
            (table ? "AND table_name = '#{quote_string(table)}'" : ""),
            SCHEMA_LOG_NAME
          ).map { |row|
            row[0]
          }
        end

        # Change a columns NULL-ability
        def change_column_null(table_name, column_name, null, default = nil)
          execute(
            "ALTER TABLE #{quote_table_name(table_name)} "+
            "ALTER COLUMN #{quote_column_name(column_name)} "+
            "#{null ? '' : 'NOT'} NULL",
            SCHEMA_LOG_NAME
          )
        end

        # Drops the schema specified on the +name+ attribute
        # and creates it again using the provided +options+.
        def recreate_database(name, options = {})
          drop_database(name)
          create_database(name, options)
        end

        # Create a new schema. As of 1.9.2, there are no supported options.
        def create_database(name, options = {})
          execute(
            "CREATE SCHEMA #{quote_table_name(name)}",
            SCHEMA_LOG_NAME
          )
        end

        # Drop the schema.
        def drop_database(name)
          execute(
            "DROP SCHEMA IF EXISTS #{quote_table_name(name)} CASCADE",
            SCHEMA_LOG_NAME
          )
        end

        # Returns a table's PRIMARY KEY column
        def primary_key(table_name)
          pk_and_sequence_for(table_name)[0]
        rescue
          nil
        end

        # Returns a table's PRIMARY KEY column and associated sequence.
        # May return nil if none, [pk_col, nil] if no sequence or [pk_col, seq_name]
        def pk_and_sequence_for(table_name, with_seq_schema = false)
          result = select_rows(
            "SELECT kc.column_name, "+
            (with_seq_schema ? "c.sequence_schema, " : "") +
            "       c.sequence_name "+
            "FROM information_schema.table_constraints tc "+
            "INNER JOIN information_schema.key_column_usage kc "+
            "  ON  tc.table_schema = kc.table_schema "+
            "  AND tc.table_name = kc.table_name "+
            "  AND tc.constraint_name = kc.constraint_name "+
            "LEFT JOIN information_schema.columns c "+
            "  ON  kc.table_schema = c.table_schema "+
            "  AND kc.table_name = c.table_name "+
            "  AND kc.column_name = c.column_name "+
            "WHERE tc.table_schema = CURRENT_SCHEMA "+
            "  AND tc.table_name = '#{table_name}' "+
            "  AND tc.constraint_type = 'PRIMARY KEY'",
            SCHEMA_LOG_NAME
          )
          (result.length == 1) ? result[0] : nil
        rescue
          nil
        end

        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table_name, primary_key=nil, sequence_name=nil)
          primary_key, seq_schema, sequence_name = pk_and_sequence_for(table_name, true)
          if primary_key && !sequence_name
            @logger.warn "#{table_name} has primary key #{primary_key} with no sequence" if @logger
          end

          if primary_key && sequence_name
            seq_from_where = "FROM information_schema.sequences "+
                             "WHERE sequence_schema='#{quote_string(seq_schema)}' "+
                             "AND sequence_name='#{quote_string(sequence_name)}'"
            result = select_rows(
              "SELECT COALESCE(MAX(#{quote_column_name(primary_key)} + (SELECT increment #{seq_from_where})), "+
              "       (SELECT minimum_value #{seq_from_where})) "+
              "FROM #{quote_table_name(table_name)}",
              SCHEMA_LOG_NAME
            )

            if result.length == 1
              # The COMMIT; BEGIN; can go away when 1) transactional DDL is available 2) There is a better restart/set function
              execute(
                "COMMIT; "+
                "CALL sys.alter_seq_restart('#{quote_string(seq_schema)}', '#{quote_string(sequence_name)}', #{result[0][0]}); "+
                "BEGIN;",
                SCHEMA_LOG_NAME
              )
            else
              @logger.warn "Unable to determin max value for #{table_name}.#{primary_key}" if @logger
            end
          end
        end


        protected

          # None


        private

          SCHEMA_LOG_NAME = 'FDB_SCHEMA'
          PK_TYPE_BASE = 'bigint not null primary key'
          GENERATED_IDENTITY = 'generated by default as identity'

          NATIVE_DATABASE_TYPES = {
            :primary_key  => { name: "#{PK_TYPE_BASE} #{GENERATED_IDENTITY}" }, # NB: Not using SERIAL to avoid double index
            :string       => { name: "varchar", limit: 255 },
            :text         => { name: "clob" },
            :integer      => { name: "integer" },
            :float        => { name: "float" },
            :decimal      => { name: "decimal" },
            :datetime     => { name: "datetime" },
            :timestamp    => { name: "timestamp" }, # NB: Alias for DATETIME as of 1.9.2
            :time         => { name: "time" },
            :date         => { name: "date" },
            :binary       => { name: "blob" },
            :boolean      => { name: "boolean" }
          }

      end

    end

  end

end

