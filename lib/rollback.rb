#!/usr/local/bin/ruby

# only process this file if it is invoked directly and not required
if __FILE__ == $0

  require 'benchmark'
  require 'logger'


  class ProductUnInstaller
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
      info "=== Rolling Back Adaptor VMware #{version} ==="
      duration = deploy_rollback()
      info "  #{'%0.2f' % duration} seconds"
    end

    # Attempt to rollback an install using capistrano.  A failed exit status code indicates a failure to rollback
    # TODO: set this up to stream output
    def deploy_rollback
      info "--- Rolling Back upgrade ---"
      duration = Benchmark.realtime do
        output = %x'jruby -S bundle exec cap upgrade deploy:rollback RAILS_ENV=#{environment} 2>&1'
        if $?.success?
          info(output)
        else
          error(output)
          error("Rollback failed.  Please contact support@6fusion.com.  Details located at #{logfile}")
          exit(1)
        end
      end
      duration
    end

  end

  ProductUnInstaller.new.run
end
