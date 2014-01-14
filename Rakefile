require 'rake'
require 'rake/clean'
require 'rake/testtask'

CLEAN.include ["activereocrd-*.gem", '**/*.rbc']
AR_PATH = Gem.loaded_specs['activerecord'].full_gem_path


def test_libs()
  [ 'lib', 'test', "/#{File.join(AR_PATH, "test")}" ]
end

def test_files(with_unit, with_ar)
  if ENV['TESTFILES'] then
    return ENV['TESTFILES'].split(',').sort 
  end
  files = []
  if with_unit then
    files += Dir.glob("test/*_test.rb").sort
  end
  if with_ar then
    ar_cases = Dir.glob("#{AR_PATH}/test/cases/**/*_test.rb")
    adapter_cases = Dir.glob("#{AR_PATH}/test/cases/adapters/**/*_test.rb")
    files += (ar_cases - adapter_cases).sort
  end
  match_str = ENV['TESTMATCH']
  if match_str
    files.keep_if { |f| f.match(match_str) }
  end
  files
end

def psql_db_helper(drop)
  require File.join(AR_PATH, "test", "config")
  require File.join(AR_PATH, "test", "support", "config")
  config = ARTest.config['connections']['fdbsqltest']
  prefix = drop ? "DROP SCHEMA IF EXISTS" : "CREATE SCHEMA"
  suffix = drop ? "CASCADE" : ""
  %x( psql -h #{config['arunit']['host']} -p #{config['arunit']['port']} -c "#{prefix} #{config['arunit']['database']} #{suffix}" )
  %x( psql -h #{config['arunit2']['host']} -p #{config['arunit2']['port']} -c "#{prefix} #{config['arunit2']['database']} #{suffix}" )
end


### TESTS

namespace :test do
  def test_task(name, files)
    Rake::TestTask.new(name) do |t|
      t.libs = test_libs() 
      t.test_files = files
      t.verbose = t.option_list.include? '-v'
    end
  end

  test_task('unit', test_files(true, false))
  test_task('active_record', test_files(false, true))
  test_task('all', test_files(true, true))

  desc "Print all files that would be run with the given arguments"
  task :print_files do
    for f in test_files(false, true) do
      puts f
    end
  end

  desc "Echo the command for patching the ActiveRecord tests"
  task :patch_cmd do
    require 'active_record'
    puts "git apply --directory=#{AR_PATH}/.. test/active_record_#{ActiveRecord::VERSION::MAJOR}_tests.diff"
  end
end

task :build_databases do
  psql_db_helper(false)
end

task :drop_databases do
  psql_db_helper(true)
end

task :rebuild_databases => [:drop_databases, :build_databases]

task :default => 'test:unit'

