version = File.read(File.expand_path('../VERSION', __FILE__)).strip

FDBSQL_GEMSPEC = Gem::Specification.new do |s|
  s.name         = 'activerecord-fdbsql-adapter'
  s.version      = version
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

  # Known to work on 3.2 (the last 3 series) and 4.0.x
  s.add_dependency 'activerecord', '>= 3.2', '< 4.1.a'
  s.add_dependency 'pg', '~> 0.11'
end
