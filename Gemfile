source 'https://rubygems.org'

gem 'padrino', git: 'https://github.com/padrino/padrino-framework.git', branch: 'master'

# Component requirements
gem 'activemodel', require: 'active_model'
gem 'activesupport', require: 'active_support/time'
gem 'haml'
gem 'rabl'
gem 'yajl-ruby'
gem 'rake'
gem 'kaminari', require: 'kaminari/sinatra'
gem 'rubyzip', git: 'https://github.com/aussiegeek/rubyzip.git', require: "zip/zip"
gem 'uuid'
gem 'json-jruby', require: 'json'
gem 'jruby-rack'
gem 'rack'

torquebox_version = "2.3.0"
gem 'torquebox-cache', torquebox_version
gem 'torquebox-messaging', torquebox_version
gem 'torquebox-rake-support', torquebox_version
gem 'torquebox', torquebox_version
gem 'padrino-rpm', git: 'https://github.com/6fusion/padrino-rpm.git'
gem 'newrelic_rpm'

group :development do
  gem 'trinidad'
  gem 'capistrano'
  gem 'capistrano-ext'
  gem 'capistrano_colors'
  gem 'capistrano-helpers'
  gem 'rest-client'
end

group :test do
  gem 'mocha'
  gem 'rspec'
  gem 'rack-test', require: 'rack/test'
end