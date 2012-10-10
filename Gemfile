source :rubygems
gem 'padrino', '0.10.7'

gem 'rabl'
gem 'yajl-ruby', require: 'yajl'
gem 'haml'
gem 'activemodel', require: 'active_model'
gem 'activesupport', require: 'active_support/time'
gem 'rbvmomi'
gem 'rake'

platform :jruby do
  gem 'jruby-openssl'
  torquebox_version = "2.0.3"
  gem "torquebox-rake-support", torquebox_version
  gem "torquebox", torquebox_version
end

group :development do
  gem 'thin'
  gem 'vagrant'
  gem 'capistrano'
  gem 'capistrano-ext'
  gem 'capistrano_colors'
end

group :test do
  gem 'mocha'
  gem 'rspec'
  gem 'rack-test', require: 'rack/test'
end
