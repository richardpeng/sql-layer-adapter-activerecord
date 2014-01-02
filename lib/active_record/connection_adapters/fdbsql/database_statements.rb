module ActiveRecord

  module ConnectionAdapters

    module FdbSql

      module DatabaseStatements

        # Returns an array of arrays containing the field values
        # Order is the same as that returned by +columns+
        def select_rows(sql, name = nil)
          select_raw(sql, name).last
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = 'SQL')
          log(sql, name) do
            @connection.async_exec(sql)
          end
        end

        # Executes +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is logged along with
        # the executed +sql+ statement.
        def exec_query(sql, name = 'SQL', binds = [])
          log(sql, name, binds) do
            result = binds.empty? ? exec_no_cache(sql, binds) :
                                    exec_cache(sql, binds)
            ret = ActiveRecord::Result.new(result.fields, result_as_array(result))
            result.clear
            ret
          end
        end

        # Executes delete +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is the logged along with
        # the executed +sql+ statement.
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

        # Checks whether there is currently no transaction active. This is done
        # by querying the database driver, and does not use the transaction
        # house-keeping information recorded by #increment_open_transactions and
        # friends.
        #
        # Returns true if there is no transaction active, false if there is a
        # transaction active, and nil if this information is unknown.
        def outside_transaction?
          @connection.transaction_status == PGconn::PQTRANS_IDLE
        end

        # Returns +true+ when the connection adapter supports prepared statement
        # caching, otherwise returns +false+
        def supports_statement_cache?
          # TODO
          false
        end

        # Begins the transaction (and turns off auto-committing).
        def begin_db_transaction
          execute "BEGIN"
        end

        # Commits the transaction (and turns on auto-committing).
        def commit_db_transaction
          execute "COMMIT"
        end

        # Rolls back the transaction (and turns on auto-committing). Must be
        # done if the transaction block raises an exception or returns false.
        def rollback_db_transaction
          execute "ROLLBACK"
        end

        # Implemented in schema_statements
        #def default_sequence_name(table, column)
        #end

        # Set the sequence to the max value of the table's column.
        def reset_sequence!(table, column, sequence = nil)
          # Nobody else implements this and it isn't called from anywhere
        end


        # OTHER METHODS ============================================

        # Won't be called unless adapter claims supports_explain?
        def explain(arel, binds = [])
          sql = "EXPLAIN #{to_sql(arel, binds)}"
          exec_query(sql, 'EXPLAIN', binds)
        end


        protected

          # Returns an array of record hashes with the column names as keys and
          # column values as values.
          def select(sql, name = nil, binds = [])
            exec_query(sql, name, binds).to_a
          end

          # (Executes an INSERT and)
          # Returns the last auto-generated ID from the affected table.
          def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
            unless pk
              # TODO: find primary key for this table
              # Extract the table from the insert sql. Yuck.
            end
            if pk
              select_value("#{sql} RETURNING #{quote_column_name(pk)}")
            else
              super
            end
          end
          alias :create :insert_sql

          # Executes an UPDATE query and returns the number of affected tuples.
          def delete_sql(sql, name = nil)
            result = execute(sql, name)
            result.cmd_tuples
          end
          alias :update_sql :delete_sql

          def sql_for_insert(sql, pk, id_value, sequence_name, binds)
            unless pk
              # TODO: find primary key for this table
              # Extract the table from the insert sql. Yuck.
            end
            sql = "#{sql} RETURNING #{quote_column_name(pk)}" if pk
            [sql, binds]
          end


        private

          BINARY_COLUMN_TYPE = 17


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

          def result_as_array(res)
            # Any binary columns need un-escaped
            binaries = []
            res.nfields.times { |i| binaries << i if res.ftype(i) == BINARY_COLUMN_TYPE }
            rows = res.values
            return rows unless binaries.any?
            rows.each { |row|
              binaries.each { |i|
                row[i] = unescape_binary(row[i])
              }
            }
          end

          def select_raw(sql, name = nil)
            res = execute(sql, name)
            results = result_as_array(res)
            fields = res.fields
            res.clear
            return fields, results
          end

      end

    end

  end

end

