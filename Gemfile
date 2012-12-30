source :rubygems
#gem 'padrino', '~> 0.10.0'
gem 'padrino', :git => "git://github.com/padrino/padrino-framework.git", :branch => 'master'
gem 'rabl'
gem 'yajl-ruby', :require => 'yajl', :platform => :mri_19
gem 'haml'
gem 'activemodel', :require => 'active_model'
gem 'activesupport', :require => 'active_support/time'
#gem 'rbvmomi'
#gem 'rake', :require => false
gem 'kaminari', :require => 'kaminari/sinatra'
gem 'rubyzip', :git => 'git://github.com/aussiegeek/rubyzip.git', :require => "zip/zip"
gem 'uuid'
# -- newrelic should be last
gem 'padrino-rpm', :git => 'https://github.com/6fusion/padrino-rpm.git'
gem 'newrelic_rpm'

platform :jruby do
  gem 'jruby-openssl'
  gem 'json-jruby', :require => 'json'
  gem 'jruby-rack', '1.0.10'
  torquebox_version = "2.2.0"
  gem "torquebox-rake-support", torquebox_version
  gem 'torquebox-cache', torquebox_version
  gem "torquebox", torquebox_version
end

group :development do
  #gem 'thin'
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
