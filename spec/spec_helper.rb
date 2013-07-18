PADRINO_ENV = 'test' unless defined?(PADRINO_ENV)

require 'simplecov'
require 'simplecov-rcov'

class SimpleCov::Formatter::MergedFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    SimpleCov::Formatter::RcovFormatter.new.format(result)
    #SimpleCov::Formatter::SublimeRubyCoverageFormatter.new.format(result)
  end
end
SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter

# SimpleCov.command_name 'specs'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_group "Models", "models"
  add_group "Modules", "app/modules"
  add_group "Views", "app/views"
end if ENV["COVERAGE"]

require "test/unit"
require File.expand_path(File.dirname(__FILE__) + "/../config/boot")

RSpec.configure do |conf|
  # Run only focused specs
  conf.alias_example_to :fit, :focused => true
  conf.filter_run :focused => true
  conf.run_all_when_everything_filtered = true

  conf.include Rack::Test::Methods
  conf.include RSpec::Padrino  
end

# specific helpers for specs
require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  logger.info("#{jar}")
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "java.net.URL"
# java_import "java.util.ArrayList"
# java_import "com.vmware.vim25.InvalidLogin"
java_import "java.rmi.RemoteException"
module VIJavaUtil
  include_package "com.vmware.vim25.mo.util"
end
module VIJava
  include_package "com.vmware.vim25.mo"
end
module Vim
  include_package "com.vmware.vim25"
end 

def app
  ##
  # You can handle all padrino applications using instead:
  #   Padrino.application
  AdaptorVMware.tap { |app|  }
end
