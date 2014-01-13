module ActiveRecord

  module ConnectionAdapters

    class FdbSqlAdapter < AbstractAdapter

      module Types

        UNKNOWN_OID = -1
        BLOB_OID    = 17
        DECIMAL_OID = 1700
        INTEGER_OID = 23

        NAME_TO_OID = {}
        OID_TO_TYPE = {}


        def fetch_type(field_name, field_oid, field_mod)
          # As in Column.simplified_type(), this needs to map zero-scale
          # decimal columns to integers
          if (field_oid == DECIMAL_OID) && ((field_mod - 4) & 0xffff).zero?
            field_oid = INTEGER_OID
          end
          OID_TO_TYPE.fetch(field_oid) { |oid|
            warn "Unknown field type: #{field_name} => #{oid}"
            OID_TO_TYPE[Types::UNKNOWN_OID]
          }
        end


        private

          # Note: These use the SQL Layer type names as opposed to the
          # ActiveRecord ones (e.g. BLOB instead of BINARY).

          class Type
            def type()
            end

            def type_cast(value)
              value
            end

            def type_cast_for_write(value)
              value
            end
          end

          class Boolean < Type
            def type_cast(value)
              return if value.nil?
              ConnectionAdapters::Column.value_to_boolean value
            end
          end

          class Blob < Type
            # NB: No [un]escape needed in this path
          end

          class Date < Type
            # TODO: Needed?
            #def type
            #  :datetime
            #end

            def type_cast(value)
              return if value.nil?
              ConnectionAdapters::Column.value_to_date value
            end
          end

          class DateTime < Type
            def type_cast(value)
              return if value.nil?
              ConnectionAdapters::Column.string_to_time value
            end
          end

          class Decimal < Type
            def type_cast(value)
              return if value.nil?
              ConnectionAdapters::Column.value_to_decimal value
            end
          end

          class Double < Type
            def type_cast(value)
              return if value.nil?
              value.to_f
            end
          end

          class Integer < Type
            def type_cast(value)
              return if value.nil?
              ConnectionAdapters::Column.value_to_integer value
            end
          end

          class String < Type
          end

          class Time < Type
          end


          def self.add_type(name, oid, type)
            raise 'nil name' if name.nil?
            raise 'nil oid' if oid.nil?
            raise 'nil type' if type.nil?
            raise "Duplicate type name: #{name}" if NAME_TO_OID.has_key? name
            raise "Duplicate oid: #{oid}" if OID_TO_TYPE.has_key? oid
            NAME_TO_OID[name] = oid
            OID_TO_TYPE[oid] = type
          end

          def self.add_alias(name, alias_for, oid=nil)
            alias_oid = NAME_TO_OID[alias_for]
            alias_type = OID_TO_TYPE[alias_oid]
            if oid
              add_type(name, oid, alias_type)
            else
              raise "Duplicate type name: #{name}" if NAME_TO_OID.has_key? name
              NAME_TO_OID[name] = alias_type
            end
          end


          # Primary AR types, see schema_statements.NATIVE_DATABASE_TYPES
          add_type 'blob',      BLOB_OID,     Blob.new
          add_type 'boolean',   16,           Boolean.new
          add_type 'date',      1082,         Date.new
          add_type 'datetime',  1114,         DateTime.new
          add_type 'decimal',   DECIMAL_OID,  Decimal.new
          add_type 'double',    701,          Double.new
          add_type 'integer',   INTEGER_OID,  Integer.new
          add_type 'varchar',   1043,         String.new
          add_type 'time',      1083,         Time.new

          # SERIAL maps to BIGINT. Not an alias but reusable Type.
          add_alias 'bigint', 'integer', 20
          # CLOB maps to LONGTEXT. Not an alias but reusable Type.
          add_alias 'clob', 'varchar', 25
          # FLOAT is a direct alias
          add_alias 'flaot', 'double'
          # TIMESTAMP is a direct alias
          add_alias 'timestamp', 'datetime'


          OID_TO_TYPE[UNKNOWN_OID] = Type.new

      end

    end

  end

end

