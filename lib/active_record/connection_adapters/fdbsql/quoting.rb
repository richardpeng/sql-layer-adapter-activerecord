module ActiveRecord

  module ConnectionAdapters

    module FDBSQL

      module Quoting

        def extract_pg_identifier_from_name(name)
          match_data = name.start_with?('"') ? name.match(/\"([^\"]+)\"/) : name.match(/([^\.]+)/)

          if match_data
            rest = name[match_data[0].length, name.length]
            rest = rest[1, rest.length] if rest.start_with? "."
            [match_data[1], (rest.length > 0 ? rest : nil)]
          end
        end

        # Escapes binary strings for bytea input to the database.
        def escape_bytea(value)
          PGconn.escape_bytea(value) if value
        end

        # Unescapes bytea output from a database to the binary string it represents.
        # NOTE: This is NOT an inverse of escape_bytea! This is only to be used
        # on escaped binary output from database driver.
        def unescape_bytea(value)
          PGconn.unescape_bytea(value) if value
        end

        # Quotes FoundationDB SQL-specific data types for SQL input.
        def quote(value, column = nil) #:nodoc:
          return super unless column

          case value
          when Float
            if value.infinite? && column.type == :datetime
              "'#{value.to_s.downcase}'"
            elsif value.infinite? || value.nan?
              "'#{value.to_s}'"
            else
              super
            end
          when Numeric
            return super
            # Not truly string input, so doesn't require (or allow) escape string syntax.
            "'#{value}'"
          when String
            case column.sql_type
            when 'blob' then "'#{escape_bytea(value)}'"
            else
              super
            end
          else
            super
          end
        end

        # Quotes strings for use in SQL input.
        def quote_string(s) #:nodoc:
          @connection.escape(s)
        end

        # Checks the following cases:
        #
        # - table_name
        # - "table.name"
        # - schema_name.table_name
        # - schema_name."table.name"
        # - "schema.name".table_name
        # - "schema.name"."table.name"
        def quote_table_name(name)
          schema, name_part = extract_pg_identifier_from_name(name.to_s)

          unless name_part
            quote_column_name(schema)
          else
            table_name, name_part = extract_pg_identifier_from_name(name_part)
            "#{quote_column_name(schema)}.#{quote_column_name(table_name)}"
          end
        end

        # Quotes column names for use in SQL queries.
        def quote_column_name(name) #:nodoc:
          PGconn.quote_ident(name.to_s)
        end

        # Quote date/time values for use in SQL input. Includes microseconds
        # if the value is a Time responding to usec.
        def quoted_date(value) #:nodoc:
          if value.acts_like?(:time) && value.respond_to?(:usec)
            # TODO: 1.9.2 doesn't support fractional TIME
            #"#{super}.#{sprintf("%06d", value.usec)}"
            "#{super}"
          else
            super
          end
        end

      end # Quoting

    end # FDBSQL

  end # ConnectionAdapters

end # ActiveRecord
