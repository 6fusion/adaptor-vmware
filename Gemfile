source 'https://rubygems.org'

gem 'padrino', git: 'https://github.com/padrino/padrino-framework.git', branch: 'master'

# Component requirements
gem 'activemodel', require: 'active_model'
gem 'activesupport', require: 'active_support/time'
gem 'haml'
gem 'rabl'
gem 'yajl-ruby'
gem 'rake'
gem 'rubyzip', git: 'https://github.com/aussiegeek/rubyzip.git', require: "zip/zip"
gem 'uuid'
gem 'json-jruby', require: 'json'
gem 'jruby-rack'
gem 'rack'
gem 'rack-post-body-to-params'

torquebox_version = "2.3.0"
gem 'torquebox-cache', torquebox_version
gem 'torquebox-messaging', torquebox_version
gem 'torquebox-rake-support', torquebox_version
gem 'torquebox', torquebox_version

group :deploy do
  gem 'colorize'
  gem 'capistrano'
  gem 'capistrano-ext'
  gem 'capistrano_colors'
  gem 'capistrano-helpers'
  gem 'rest-client'
end

group :development, :test do
  gem 'trinidad'
  gem 'pry-rails'
end

group :test do
  gem 'cucumber'
  gem 'mocha', require: 'mocha/setup'
  #gem 'rspec'
  gem 'rspec-padrino'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'rack-test', require: 'rack/test'
end
