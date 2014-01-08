module ActiveRecord

  module ConnectionAdapters

    class FdbSqlAdapter < AbstractAdapter

      class FdbSqlStatementPool < StatementPool

        def initialize(connection, max)
          super
          @count = 0
          @cache = Hash.new { |h,pid| h[pid] = {} }
        end

        def each(&block)
          cache.each(&block)
        end

        def key?(key)
          cache.key?(key)
        end

        def [](key)
          cache[key]
        end

        def length
          cache.length
        end

        def []=(sql, key)
          while @max <= cache.size
            dealloc(cache.shift.last)
          end
          @count += 1
          cache[sql] = key
        end

        def clear
          cache.each_value do |k|
            dealloc k
          end
          cache.clear
        end

        def delete(sql_key)
          dealloc cache[sql_key]
          cache.delete sql_key
        end


        # FdbSql =================================================

        def next_key
          "ar_#{@count + 1}"
        end

        def cache
          @cache[$$]
        end

        def dealloc(key)
          @connection.query "DEALLOCATE #{key}" if connection_active?
        end

        def connection_active?
          @connection.status == PGconn::CONNECTION_OK
        rescue PGError
          false
        end

      end

    end

  end

end

