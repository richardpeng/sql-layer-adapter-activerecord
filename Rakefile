require 'rake'
require 'rake/testtask'
require 'rubygems/package_task'

SUDO = ENV['SUDO'] || 'sudo'
NAME = 'activerecord-akiban-adapter'
VERSION = File.read(File.expand_path("../VERSION",__FILE__)).strip
ar_path = Gem.loaded_specs['activerecord'].full_gem_path
require File.expand_path(File.dirname(ar_path)) + "/activerecord/test/config"
require File.expand_path(File.dirname(ar_path)) + "/activerecord/test/support/config"

def test_files()
  files = Dir.glob("test/test*.rb")
  ar_path = Gem.loaded_specs['activerecord'].full_gem_path
  ar_cases = Dir.glob("#{ar_path}/test/cases/**/*_test.rb")
  adapter_cases = Dir.glob("#{ar_path}/test/cases/adapters/**/*_test.rb")
  files += (ar_cases-adapter_cases).sort
  files
end

### RDOC

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "#{NAME} #{VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

### UNIT TESTS

Rake::TestTask.new do |t|
  t.libs << ['lib', 'test', "#{File.join(Gem.loaded_specs['activerecord'].full_gem_path,'test')}"]
  t.test_files = test_files
  #t.verbose = true
end

task :build_databases do
  config = ARTest.config['connections']['akibantest']
  %x( psql -h #{config['arunit']['host']} -p #{config['arunit']['port']} -c "CREATE SCHEMA #{config['arunit']['database']}")
  %x( psql -h #{config['arunit2']['host']} -p #{config['arunit2']['port']} -c "CREATE SCHEMA #{config['arunit2']['database']}")
end

task :drop_databases do
  config = ARTest.config['connections']['akibantest']
  %x( psql -h #{config['arunit']['host']} -p #{config['arunit']['port']} -c "DROP SCHEMA #{config['arunit']['database']} CASCADE" )
  %x( psql -h #{config['arunit2']['host']} -p #{config['arunit2']['port']} -c "DROP SCHEMA #{config['arunit2']['database']} CASCADE" )
end

task :rebuild_databases => [:drop_databases, :build_databases]

task :default => :test

### MISC

task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  FileList["lib/active_record/**/*.rb"].each do |file_name|
    next if file_name =~ /vendor/
    File.open(file_name, 'r') do |f| 
      while line = f.gets
        lines += 1
        next if line =~ /^\s*$/
        next if line =~ /^\s*#/
        codelines += 1
      end 
    end 
    puts "L: #{sprintf("%4d", lines)}, LOC #{sprintf("%4d", codelines)} | #{file_name}"

    total_lines     += lines
    total_codelines += codelines

    lines, codelines = 0, 0
  end 

  puts "Total: Lines #{total_lines}, LOC #{total_codelines}"
end

desc "Print activerecord-akiban-adapter version"
task :version do
    puts VERSION
end

### GEM PACKAGING AND RELEASE

desc "Packages activerecord-akiban-adapter"
task :package=>[:clean] do |p| 
    load './activerecord-akiban-adapter.gemspec'
      Gem::Builder.new(AKIBAN_GEMSPEC).build
end

desc "Install activerecord-akiban-adapter gem"
task :install=>[:package] do
    sh %{#{SUDO} gem install ./#{NAME}-#{VERSION} --local}
end

desc "Uninstall activerecord-akiban-adapter gem"
task :uninstall=>[:clean] do
    sh %{#{SUDO} gem uninstall #{NAME}}
end

desc "Upload activerecord-akiban-adapter gem to gemcutter"
task :release=>[:package] do
    sh %{gem push ./#{NAME}-#{VERSION}.gem}
end
