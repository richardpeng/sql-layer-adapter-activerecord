module ActiveRecord

  module ConnectionAdapters

    class FdbSqlAdapter < AbstractAdapter

      module Quoting

        # Returns a bind substitution value given a +column+ and list of current +binds+.
        def substitute_at(column, index)
          Arel::Nodes::BindParam.new "$#{index + 1}"
        end

        # Quotes data types for SQL input.
        def quote(value, column = nil)
          return super unless column
          case value
          when String
            if column.type == :binary
              hex_str = value ? value.unpack('H*')[0] : nil
              "x'#{hex_str}'"
            else
              super
            end
          else
            super
          end
        end

        # Cast a +value+ to a type that the database understands.
        # Used in the prepared statement path.
        def type_cast(value, column)
          return super unless column
          case value
          when String
            if :binary == column.type
              # Send binary data as binary format
              { :value => value, :format => 1 }
            else
              super
            end
          else
            super
          end
        end

        # Quotes strings for use in SQL input.
        def quote_string(s)
          # cannot use ruby-pg escape_string() as our backslash doesn't need escaped
          s.gsub("'", "''")
        end

        # Quotes column names for use in SQL queries.
        def quote_column_name(name)
          quote_ident(name.to_s)
        end

        # Quotes the table name.
        def quote_table_name(name)
          schema, table = split_table_name(name.to_s)
          if schema
            "#{quote_ident(schema)}.#{quote_ident(table)}"
          else
            quote_ident(table)
          end
        end

        # Quote date/time values for use in SQL input. Includes microseconds
        # if the value is a Time responding to usec.
        def quoted_date(value) #:nodoc:
          # TODO: 1.9.2 doesn't support fractional TIME
          #if value.acts_like?(:time) && value.respond_to?(:usec)
          #  "#{super}.#{sprintf("%06d", value.usec)}"
          super
        end


        private

          # Splits an optionally qualified name into schema and table.
          # For example,
          #   't' => [nil, 't']
          #   'test.t' => ['test', 't']
          #
          # All adapters appear to implement different policies with
          # what input name can be to various methods. Stay simple
          # until otherwise needed.
          def split_table_name(table_name)
            schema, table = table_name.to_s.split('.', 2)
            if !table
              table = schema
              schema = nil
            end
            [ schema, table ]
          end

          def quote_ident(ident)
            PGconn.quote_ident(ident)
          end

          def escape_binary(value)
            @connection.escape_bytea(value) if value
          end

          def unescape_binary(value)
            @connection.unescape_bytea(value) if value
          end

      end

    end

  end

end

