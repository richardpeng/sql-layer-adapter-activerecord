module ActiveRecord

  module ConnectionAdapters

    class FdbSqlAdapter < AbstractAdapter

      module DatabaseLimits

        def table_alias_length
          64
        end

        def index_name_length
          # ruby-pg has a hard limit of NAMEDATALEN-1
          63
        end
      end

    end

  end

end

