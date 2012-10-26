require 'rake'
require 'rake/testtask'

def name
  Dir['*.gemspec'].first.split('.').first
end

def version
  File.read(File.expand_path("../VERSION",__FILE__)).strip
end

def test_files()
  files = Dir.glob("test/test*.rb")
  ar_path = Gem.loaded_specs['activerecord'].full_gem_path
  ar_cases = Dir.glob("#{ar_path}/test/cases/**/*_test.rb")
  adapter_cases = Dir.glob("#{ar_path}/test/cases/adapters/**/*_test.rb")
  files += (ar_cases-adapter_cases).sort
  files
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "#{name} #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

Rake::TestTask.new do |t|
  t.libs << ['lib', 'test', "#{File.join(Gem.loaded_specs['activerecord'].full_gem_path,'test')}"]
  #t.test_files = FileList['test/test*.rb']
  t.test_files = test_files
  t.verbose = true
end

task :default => :test
