require 'rake'
require 'rake/testtask'
require 'rubygems/package_task'

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

spec = eval(File.read('activerecord-akiban-adapter.gemspec'))

Gem::PackageTask.new(spec) do |p| 
  p.gem_spec = spec
end

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

# Publishing ------------------------------------------------------

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end
