module ActiveRecord

  module ConnectionAdapters
    
    class FdbSqlColumn < Column
      private

        def extract_limit(sql_type)
          # NB: Needs to match schema_statements:type_to_sql()
          case sql_type
          when /^bigint/i;    8
          else
            super
          end
        end

    end

  end

end

