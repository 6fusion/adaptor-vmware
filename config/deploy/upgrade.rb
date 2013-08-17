set :context_path, ENV['CONTEXT_PATH'] || '/vmware'
set :hipchat_alert, false
set :repository, '.'
set :deploy_via, :copy
set :copy_dir, '/tmp/upgrade/capistrano/adaptor-vmware-copy'
set :scm, :none
set :rails_env, ENV['RAILS_ENV'] || 'production'
set :bundle_flags, '--local --deployment --quiet'
set :bundle_cmd, 'jruby -S bundle'
set :use_sudo, false

def local_run(cmd, options = {})
  puts "Ignoring local_run option: #{options.inspect}" unless options.empty?
  run_locally(cmd)
end

alias :run :local_run

def local_capture(command, options = {})
  puts "Ignoring local_capture option: #{options.inspect}" unless options.empty?
  `#{command}`
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
