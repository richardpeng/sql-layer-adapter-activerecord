AKIBAN_GEMSPEC = Gem::Specification.new do |s|
  s.platform     = Gem::Platform::RUBY
  s.name         = 'activerecord-akiban-adapter'
  s.version      = File.read(File.expand_path("../VERSION",__FILE__)).strip
  s.summary      = "ActiveRecord Akiban adapter."
  s.description  = "ActiveRecord Akiban adapter."
  s.author       = "Padraig O'Sullivan"
  s.email        = 'padraig@akiban.com'
  s.homepage     = 'http://www.akiban.com'
  s.files        = Dir['CHANGELOG', 'MIT-LICENSE', 'README.md', 'VERSION', 'lib/**/*' ]
  s.require_path = 'lib'
  s.add_dependency('activerecord', '~> 3.2.0')
end
