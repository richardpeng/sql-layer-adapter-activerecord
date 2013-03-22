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
            @connection.async_exec(sql)
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

        def exec_delete(sql, name = 'SQL', binds = [])
          log(sql, name, binds) do
            result = binds.empty? ? exec_no_cache(sql, binds) :
                                    exec_cache(sql, binds)
            affected = result.cmd_tuples
            result.clear
            affected
          end
        end
        alias :exec_update :exec_delete

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

        def insert_fixture(fixture, table_name)
          columns = Hash[columns(table_name).map { |c| [c.name, c] }]

          # TODO: how does postgresql handle this?
          # get the sequence name for the PK of this table
          seq_name = get_seq_name(table_name, current_schema, 'id')
          execute "SELECT NEXTVAL('#{current_schema}', '#{seq_name}')" if seq_name

          key_list   = []
          value_list = fixture.map do |name, value|
            key_list << quote_column_name(name)
            quote(value, columns[name])
          end 

          execute "INSERT INTO #{quote_table_name(table_name)} (#{key_list.join(', ')}) VALUES (#{value_list.join(', ')})", 'Fixture Insert'
        end

      def begin_db_transaction
        execute "BEGIN"
      end

      def commit_db_transaction
        execute "COMMIT"
      end

      def rollback_db_transaction
        execute "ROLLBACK"
      end

      def outside_transaction?
        @connection.transaction_status == PGconn::PQTRANS_IDLE
      end

      end # DatabaseStatements

    end # Akiban

  end # ConectionAdapters

end # ActiveRecord
