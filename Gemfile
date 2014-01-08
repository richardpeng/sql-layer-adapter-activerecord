source 'https://rubygems.org'

if ENV['RAILS_SOURCE']
  gemspec :path => ENV['RAILS_SOURCE']
else
  # If not present, lookup newest supported x.y
  version = ENV['RAILS_VERSION'] || begin
    require 'net/http'
    require 'yaml'
    spec = eval(File.read('activerecord-fdbsql-adapter.gemspec'))
    version = spec.dependencies.detect{ |d|d.name == 'activerecord' }.requirement.requirements.last.last.version
    major, minor, tiny = version.split('.')
    uri = URI.parse "http://rubygems.org/api/v1/versions/activerecord.yaml"
    YAML.load(Net::HTTP.get(uri)).select do |data|
      a, b, c = data['number'].split('.')
      !data['prerelease'] && major == a && minor == b
    end.first['number']
  end
  gem 'rails', :git => "git://github.com/rails/rails.git", :tag => "v#{version}"
end

group :pg do
  gem 'pg'
end

group :development do
  gem 'bcrypt-ruby', '~> 3.0.0'
  gem 'bench_press'
  gem 'm'
  gem 'mocha'
  gem 'nokogiri'
  gem 'rake', '~> 10.1.0'
  gem 'shoulda', '2.10.3'
end

