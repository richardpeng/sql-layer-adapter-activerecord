module ActiveRecord

  module ConnectionAdapters

    module Akiban

      module DatabaseStatements

        def explain(arel, binds = [])
          sql = "EXPLAIN #{to_sql(arel, binds)}"
          exec_query(sql, 'EXPLAIN', binds)
        end

        def select(sql, name = nil, binds = [])
          exec_query(sql, name, binds).to_a
        end

        def select_rows(sql, name = nil)
          select_raw(sql, name).last
        end

        def select_raw(sql, name = nil)
          res = execute(sql, name)
          results = result_as_array(res)
          fields = res.fields
          res.clear
          return fields, results
        end

        def query(sql, name = nil)
          log(sql, name) do
            result_as_array @connection.async_exec(sql)
          end
        end

        # create a 2D array representing the result set
        def result_as_array(res) #:nodoc:
          ftypes = Array.new(res.nfields) do |i|
            [i, res.ftype(i)]
          end
          res.values
        end

        def execute(sql, name = 'SQL')
          log(sql, name) do
            @connection.query(sql)
          end
        end

        def exec_query(sql, name = 'SQL', binds = [])
          log(sql, name, binds) do
            result = binds.empty? ? exec_no_cache(sql, binds) :
                                    exec_cache(sql, binds)
            ret = ActiveRecord::Result.new(result.fields, result.values)
            result.clear
            return ret
          end
        end

        def exec_no_cache(sql, binds)
          @connection.async_exec(sql)
        end

        def exec_cache(sql, binds)
          # TODO: caching & proper stmt key generation
          stmt_key = (0...8).map{65.+(rand(26)).chr}.join
          @connection.prepare(stmt_key, sql)
          # clear the queue
          @connection.get_last_result
          @connection.send_query_prepared(stmt_key, binds.map { |col, val|
            type_cast(val, col)
          })
          @connection.block
          @connection.get_last_result
        end

        def type_cast(value, col)
          return if value.nil?
          return super
        end

        def sql_for_insert(sql, pk, id_value, sequence_name, binds)
          unless pk
            # TODO: find primary key for this table
          end
          if pk # TODO: make use of RETURNING configurable
            sql = "#{sql} RETURNING #{quote_column_name(pk)}"
          end
          [sql, binds]
        end

      end # DatabaseStatements

    end # Akiban

  end # ConectionAdapters

end # ActiveRecord
