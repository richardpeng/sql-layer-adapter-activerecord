module ActiveRecord

  module ConnectionAdapters

    class FdbSqlAdapter < AbstractAdapter

      module TypeID

        UNKNOWN = -1
        BLOB    = 17
        DECIMAL = 1700
        INTEGER = 23

      end

    end

  end

end

