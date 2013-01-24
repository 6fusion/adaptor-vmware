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

gem 'torquebox-cache'
gem 'torquebox-messaging'
gem 'torquebox-rake-support'
gem 'torquebox'
gem 'padrino-rpm', github: '6fusion/padrino-rpm'
gem 'newrelic_rpm'

group :development do
  gem 'trinidad'

  gem 'capistrano'
  gem 'capistrano-ext'
  gem 'capistrano_colors'
  gem 'capistrano-helpers'
end

group :test do
  gem 'mocha'
  gem 'rspec'
  gem 'rack-test', require: 'rack/test'
end