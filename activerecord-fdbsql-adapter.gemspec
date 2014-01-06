FDBSQL_GEMSPEC = Gem::Specification.new do |s|
  s.name         = 'activerecord-fdbsql-adapter'
  s.version      = '0.1.0'
  s.date         = Time.new.strftime '%Y-%m-%d'
  s.summary      = "ActiveRecord Adapter for the FoundationDB SQL Layer"
  s.description  = <<-EOF
ActiveRecord Adapter for the FoundationDB SQL Layer.

Complete documentation of the FoundationDB SQL Layer can be found at:
https://foundationdb.com/layers/sql/
EOF
  s.authors      = ["FoundationDB"]
  s.email        = 'distribution@foundationdb.com'
  s.files        = Dir['LICENSE', 'README.md', 'VERSION', 'lib/**/*']
  s.homepage     = 'https://github.com/FoundationDB/sql-layer-adapter-activerecord'
  s.license      = 'MIT'
  s.platform     = Gem::Platform::RUBY

  # Tested with 3.2 through 4.1
  s.add_dependency 'activerecord', '>= 3.2', '<= 4.1'
  s.add_dependency 'pg'
end
