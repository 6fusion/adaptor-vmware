# Defines our constants
PADRINO_ENV  = ENV['PADRINO_ENV'] ||= ENV['RACK_ENV'] ||= 'development'  unless defined?(PADRINO_ENV)
PADRINO_ROOT = File.expand_path('../..', __FILE__) unless defined?(PADRINO_ROOT)


# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
Bundler.require(:default, PADRINO_ENV)

##
# ## Enable devel logging
#
# Padrino::Logger::Config[:development][:log_static] = true
# Padrino::Logger::Config[PADRINO_ENV.to_sym][:stream] = File.new(Padrino.root('log', "adaptor-vmware.log"), 'a+')
Padrino::Logger::Config.default = { :log_level => :debug, :stream => :to_file }
# Padrino::Logger::Config[:test][:log_level]  = :info
# Padrino::Logger::Config[:test][:stream]  = :to_file
#
## Configure your I18n
#
# I18n.default_locale = :en
#
# ## Configure your HTML5 data helpers
#
# Padrino::Helpers::TagHelpers::DATA_ATTRIBUTES.push(:dialog)
# text_field :foo, :dialog => true
# Generates: <input type="text" data-dialog="true" name="foo" />
#
# ## Add helpers to mailer
#
# Mail::Message.class_eval do
#   include Padrino::Helpers::NumberHelpers
#   include Padrino::Helpers::TranslationHelpers
# end

##
# Add your before (RE)load hooks here
#
Padrino.before_load do
  # Padrino.set_load_paths("#{PADRINO_ROOT}/config/initializers/")
end

##
# Add your after (RE)load hooks here
#
Padrino.after_load do
  load("#{PADRINO_ROOT}/config/initializers/rabl_init.rb")
end

Padrino.load!
