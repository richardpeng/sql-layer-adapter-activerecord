FDBSQL_GEMSPEC = Gem::Specification.new do |s|
  s.platform     = Gem::Platform::RUBY
  s.name         = 'activerecord-fdbsql-adapter'
  s.version      = '0.1.0'
  s.summary      = "ActiveRecord FoundationDB SQL Layer Adapter."
  s.description  = "ActiveRecord FoundationDB SQL Layer Adapter."
  s.authors      = ["FoundationDB"]
  s.email        = 'distribution@foundationdb.com'
  s.homepage     = 'http://foundationdb.com'
  s.files        = Dir['LICENSE', 'README.md', 'VERSION', 'lib/**/*']
  s.require_path = 'lib'
  s.add_dependency('activerecord', '~> 3.2.0')
end
