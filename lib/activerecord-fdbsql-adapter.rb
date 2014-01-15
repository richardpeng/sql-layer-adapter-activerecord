require 'active_record/connection_adapters/fdbsql_adapter'

if ActiveRecord::VERSION::MAJOR >= 4
  require 'active_record/tasks/fdbsql_database_tasks'
  ActiveRecord::Tasks::DatabaseTasks.register_task(/fdbsql/, ActiveRecord::Tasks::FdbSqlDatabaseTasks)
end

