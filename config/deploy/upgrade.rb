set :context_path, ENV['CONTEXT_PATH'] || '/vmware'
set :hipchat_alert, false
set :repository, '.'
set :deploy_via, :copy
set :copy_dir, '/tmp/upgrade/capistrano/adaptor-vmware-copy'
set :scm, :none
set :rails_env, ENV['RAILS_ENV'] || 'production'
set :bundle_flags, '--local --deployment --quiet'
set :bundle_without, [:development, 'test']
set :use_sudo, true

# this is a copy of the method shipped with capistrano that has been monkey patched to show
# useful error messages on failure
def run_locally(cmd)
  if dry_run
    return logger.debug "executing locally: #{cmd.inspect}"
  end
  logger.trace "executing locally: #{cmd.inspect}" if logger
  output_on_stdout = nil
  elapsed = Benchmark.realtime do
    output_on_stdout = `#{cmd} 2>&1`
  end
  puts output_on_stdout
  if $?.to_i > 0 # $? is command exit code (posix style)
    raise Capistrano::LocalArgumentError, "Command #{cmd} returned status code #{$?}"
  end
  logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger
  output_on_stdout
end

def local_run(command, options = {})
  puts "Ignoring local_run option: #{options.inspect}" unless options.empty?
  run_locally(command)
end

alias :run :local_run

def local_capture(command, options = {})
  puts "Ignoring local_capture option: #{options.inspect}" unless options.empty?
  run_locally(command)
end

alias :capture :local_capture

server '127.0.0.1', :app, :web, primary: true

before 'deploy' do
  run "#{sudo} mkdir -p #{copy_dir}"
end

namespace :verify do
  task :rules do
  end
end

namespace :hipchat do
  task :start do
  end
  task :finish do
  end
end

namespace :deploy do
  task :check_specs do
    # do nothing, don't check the specs when upgrading
  end

  task :write_version_file do
  end

  task :update_version do
  end

  task :update_code, :except => { :no_release => true } do
    on_rollback { run "rm -rf #{release_path}; true" }
    run "cp -R . #{release_path}"
    finalize_update
  end

  task :restart do
    # don't do anything here, usually a deploy will result in a torquebox restart but that gets handled by the master install script when upgrading.
  end
end

namespace :newrelic do
  task :notice_deployment do
    # don't try to talk to newrelic
  end
end

namespace :bundle do
  task :install do
    run "cd #{release_path} && unset RUBYOPT && unset BUNDLE_GEMFILE && unset GEM_HOME && jruby -S bundle install #{bundle_flags} --gemfile #{release_path}/Gemfile --without #{bundle_without.join(' ')}"
  end
end
