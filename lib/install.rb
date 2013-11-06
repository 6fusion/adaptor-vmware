#!/usr/local/bin/ruby

# only process this file if it is invoked directly and not required
if __FILE__ == $0
  require 'benchmark'
  require 'logger'


  class ProductInstaller
    attr_accessor :logger
    attr_accessor :logfile

    def initialize
      self.logfile = '/var/6fusion/adaptor-vmware/shared/log/upgrade.log'
      self.logger  = Logger.new(logfile)
    end

    def log(message, level)
      puts message
      logger.log(level, message)
    end

    def info(message)
      log(message, Logger::INFO)
    end

    def error(message)
      log(message, Logger::ERROR)
    end

    def version
      @version ||= File.read(File.dirname(__FILE__) + "/../VERSION").chomp
    end

    def environment
      @environment ||= File.exists?('/var/6fusion/release-scripts/ENVIRONMENT') ? File.read('/var/6fusion/release-scripts/ENVIRONMENT') : 'development'
    end

    def run
      info "=== Upgrading to Adaptor VMware #{version} ==="
      duration = install_gems()
      info "  #{'%0.2f' % duration} seconds"
      duration = deploy_upgrade()
      info "  #{'%0.2f' % duration} seconds"
    end

    # Use capistrano to install the upgrade code.  On failure to install capistrano will rollback the deploy and report the EXIT_STATUS_ON_ROLLBACK code
    # indicating a failure to upgrade.
    # TODO: set this up to stream output
    def deploy_upgrade
      info "--- Deploying upgrade ---"
      duration = Benchmark.realtime do
        output = %x'jruby -S bundle exec cap upgrade deploy RAILS_ENV=#{environment} EXIT_STATUS_ON_ROLLBACK=1 2>&1'
        if $?.success?
          info(output)
        else
          error(output)
          error("Upgrade failed.  Please contact support@6fusion.com.  Details located at #{logfile}")
          exit(1)
        end
      end
      duration
    end

    # TODO: set this up to stream output
    def install_gems
      info "--- Installing Gems ---"
      duration = Benchmark.realtime do
        output = %x'JRUBY_OPTS=-Xcext.enabled=true jruby -S bundle install --deployment --local --without test 2>&1'
        if $?.success?
          info(output)
        else
          error(output)
          error("Gem installation failed.  Please contact support@6fusion.com.  Details located at #{logfile}")
          exit(1)
        end
      end
      duration
    end
  end

  ProductInstaller.new.run
end
