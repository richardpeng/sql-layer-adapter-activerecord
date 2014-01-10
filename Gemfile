source 'https://rubygems.org'

if ENV['RAILS_SOURCE']
  gemspec :path => ENV['RAILS_SOURCE']
else
  # If not present, find newest version of latest supported series
  version = ENV['RAILS_VERSION'] || begin
    require 'net/http'
    require 'yaml'
    spec = eval(File.read('activerecord-fdbsql-adapter.gemspec'))
    r = spec.dependencies.detect{ |d|d.name == 'activerecord' }.requirement
    uri = URI.parse "http://rubygems.org/api/v1/versions/activerecord.yaml"
    latest = YAML.load(Net::HTTP.get(uri)).find { |d| r.satisfied_by? Gem::Version.create d['number'] }
    latest['number']
  end
  gem 'rails', :git => "git://github.com/rails/rails.git", :tag => "v#{version}"
end

group :pg do
  gem 'pg', '~> 0.11'
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

