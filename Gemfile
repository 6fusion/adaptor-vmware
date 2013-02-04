source 'http://rubygems.org'

gem 'padrino', github: "padrino/padrino-framework", branch: 'master'

# Component requirements
gem 'activemodel', require: 'active_model'
gem 'activesupport', require: 'active_support/time'
gem 'haml'
gem 'rabl'
gem 'yajl-ruby'
gem 'rake'
gem 'kaminari', require: 'kaminari/sinatra'
gem 'rubyzip', github: 'aussiegeek/rubyzip', require: "zip/zip"
gem 'uuid'
gem 'json-jruby', require: 'json'
gem 'jruby-rack'
gem 'rack'

torquebox_version = "2.2.0"
gem 'torquebox-cache', torquebox_version
gem 'torquebox-messaging', torquebox_version
gem 'torquebox-rake-support', torquebox_version
gem 'torquebox', torquebox_version
gem 'padrino-rpm', github: '6fusion/padrino-rpm'
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