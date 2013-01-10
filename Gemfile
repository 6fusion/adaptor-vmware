source :rubygems

gem 'padrino', :git => "git://github.com/padrino/padrino-framework.git", :branch => 'master'

# Component requirements
gem 'activemodel', :require => 'active_model'
gem 'activesupport', :require => 'active_support/time'
gem 'haml'
gem 'rabl'
gem 'yajl-ruby'
gem 'rake'
gem 'kaminari', :require => 'kaminari/sinatra'
gem 'rubyzip', :git => 'git://github.com/aussiegeek/rubyzip.git', :require => "zip/zip"
gem 'uuid'
gem 'json-jruby', :require => 'json'
gem 'jruby-rack'
gem "torquebox-rake-support"
gem 'torquebox-cache'
gem "torquebox"
gem 'padrino-rpm', :git => 'https://github.com/6fusion/padrino-rpm.git'
gem 'newrelic_rpm'

group :development do
  gem 'trinidad'
  gem 'vagrant'
  gem 'capistrano'
  gem 'capistrano-ext'
  gem 'capistrano_colors'
end

group :test do
  gem 'mocha'
  gem 'rspec'
  gem 'rack-test', :require => 'rack/test'
end
