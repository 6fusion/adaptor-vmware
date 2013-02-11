require 'capistrano/ext/multistage'
require 'capistrano_colors'
require 'capistrano-helpers/specs'
require 'capistrano-helpers/version'
require 'bundler/capistrano'
require 'open-uri'
require 'rest_client'
require 'new_relic/recipes'

default_run_options[:pty] = true

set :stages, Dir['config/deploy/*.rb'].map { |f| File.basename(f, '.rb') }
set :default_stage, "development"
set :bundle_without, [:development, :test, :automation, :assets]
# set :bundle_cmd, "jruby -S bundle"
# set :bundle_dir, fetch(:shared_path)+"/bundle"
# set :bundle_flags, "--deployment --quiet"

set :application, "adaptor-vmware"
set :user, "deploy"
set :group, "deploy"

set :ssh_options, { forward_agent: true }
set :scm, "git"
set :use_sudo, true
set :repository, "git@github.com:6fusion/#{application}.git"
set :branch, ENV['TAG'] || ENV['BRANCH'] || `git branch --no-color 2> /dev/null`.chomp.split("\n").grep(/^[*]/).first[/(\S+)$/, 1]
set :deploy_to, "/var/6fusion/#{application}"
set :deploy_via, :remote_cache
set :deploy_env, lambda { fetch(:stage) }
set :rails_env, lambda { fetch(:stage) }
set :keep_releases, 2
set :tail_logs_location, "#{shared_path}/log/#{application}.log"
set :context_path, ""
set :hipchat_alert, true
set :use_default_branch, ENV['USE_DEFAULT_BRANCH'] || false
set :password, ENV['PASSWORD'] if ENV['PASSWORD']

# Adaptor-VMware Specifics
set :ssh_port, 22
set :copy_exclude do
  %w{Capfile Vagrantfile README.* spec config/deploy.rb
     config/deploy .rvmrc .rspec data .git .gitignore **/test.* .yardopts} +
    (stages - [deploy_env]).map { |e| "**/#{e}.*" }
end

# Additional Deployment Actions
before "verify:rules", "build:get_tag"
before "deploy", "verify:rules"

after "deploy:cleanup", "alert:hipchat"
after "deploy:cleanup", "newrelic:notice_deployment"

after("deploy") do
  # Setup data directory
  run "#{sudo} mkdir -p #{shared_path}/data"
  run "#{sudo} chmod 0755 #{shared_path}/data"
  run "#{sudo} chown -R torquebox:torquebox #{shared_path}/data"

  # Symlink data directory to the current path
  run "#{sudo} ln -sfn #{shared_path}/data #{current_path}/data"
  run "#{sudo} chmod 0755 #{current_path}/data"
  run "#{sudo} chown -R torquebox:torquebox #{current_path}/data"

  # Setup logs
  run "#{sudo} touch #{tail_logs_location}"
  run "#{sudo} chmod 0666 #{tail_logs_location}"
  run "#{sudo} chown -R torquebox:torquebox #{tail_logs_location}"

  # Setup dead letters directory
  run "#{sudo} mkdir -p #{shared_path}/dead_letters"
  run "#{sudo} chmod 0755 #{shared_path}/dead_letters"
  run "#{sudo} chown -R torquebox:torquebox #{shared_path}/dead_letters"

  # Set torquebox as the owner of the shared and current paths
  run "#{sudo} chown -R torquebox:torquebox #{shared_path}/*"
  run "#{sudo} chown -R torquebox:torquebox #{current_path}/*"
  
  # compile any java resources
  run "cd #{current_path} && #{sudo} rake"

  # Deploy the application
  run "#{sudo} torquebox deploy #{current_path} --name #{application} --env #{deploy_env} --context-path=#{context_path}"

  # Setup New Relic
  run "if [ -f #{shared_path}/newrelic.yml ]; then #{sudo} ln -sfn #{shared_path}/newrelic.yml #{current_path}/config; fi"

  deploy.cleanup
end

before("deploy:restart") do
  run "#{sudo} touch #{shared_path}/inodes.yml"
  run "#{sudo} chown torquebox:torquebox -R #{shared_path}/inodes.yml"
end

after("deploy:rollback") do
  run "#{sudo} torquebox undeploy #{current_path} --name #{application}"
end

namespace :verify do
  task :rules, roles: :app do
    next if stage == :development

    if tag == "master"
      puts "Skipping verification since you are deploying master."
      next
    end

    deployed_branch = capture("#{sudo} cat #{deploy_to}/current/VERSION || true").split("\r\n").last

    next if deployed_branch.nil? || deployed_branch.empty? || deployed_branch.include?('No such file or directory')

    puts "'#{deployed_branch}' branch is currently deployed to #{rails_env}."

    if deployed_branch == tag
      puts "Skipping verification since you are deploying the same branch."
      next
    end

    if deployed_branch == "master"
      puts "Skipping verification since master is currently deployed."
      next
    end

    puts "Updating local commit logs to check the status of the found commit."
    `git fetch origin`

    puts "Looking at master branch to determine if commit exists."
    branches = `git branch -r --contains #{deployed_branch}`.split(/\r\n|\n/).map { |branch| branch.strip! }

    unless branches.include?('origin/master') || branches.include?("origin/#{tag}")
      action_requested = Capistrano::CLI.ui.ask "If you continue deploying this branch you will be overwriting someone else's work.  Would you like to [c]ontinue, [s]top, or [r]eset the environment back to master? [stop]: "

      case action_requested.to_s
      when "c"
        puts "Overriding default rules and deploying your branch, you evil evil coder.  You were warned!"
        next
      when "r"
        puts "Reseting the environment to master."
        set :tag, "master"
      else
        puts "Aborting deploy..."
        abort = true
      end
    end

    abort "Since #{deployed_branch} is currently deployed to #{rails_env}.  Please either merge #{deployed_branch} to master OR re-deploy either #{deployed_branch} or master branch to this environment." unless branches.include?('origin/master') || branches.include?("origin/#{tag}") if abort
    puts "All rules have passed, continuing with deployment."
  end
end

namespace :build do
  task :get_tag, roles: :builder do
    default_tag = `git branch --no-color 2> /dev/null`.chomp.split("\n").grep(/^[*]/).first[/(\S+)$/, 1]

    unless use_default_branch
      branch_tag = Capistrano::CLI.ui.ask "Branch/Tag to deploy (make sure to push the branch/tag to origin first) [#{default_tag}]: "
    end

    branch_tag = default_tag if branch_tag.to_s == ''

    set :tag, branch_tag
  end
end

namespace :logs do
  desc "tail log files"
  task :tail, roles: :app do
    run "tail -f #{tail_logs_location}" do |channel, stream, data|
      data.split("\n").each do |line|
        puts "[#{channel[:host]}] #{line}"
      end
      break if stream == :err
    end
    puts
  end

  desc 'truncate logs'
  task :truncate, roles: :app do
    run "#{sudo} truncate -s 0 /var/log/torquebox/torquebox.log"
    run "#{sudo} truncate -s 0 #{tail_logs_location}"
    run "#{sudo} rm -f /opt/torquebox/jboss/standalone/log/**/*.log"
    run "#{sudo} rm -f /opt/torquebox/jboss/standalone/log/*.{log,log.*}"
  end

  alias_task :default, :tail
end

desc "run chef-client"
task :chef_run, roles: :app do
  run "#{sudo} chef-client"
end

namespace :torquebox do
  desc 'start'
  task :start, roles: :app do
    run "#{sudo} start torquebox"
  end

  desc 'stop'
  task :stop, roles: :app do
    run "#{sudo} stop torquebox"
  end

  desc 'restart'
  task :restart, roles: :app do
    run "#{sudo} restart torquebox"
  end

  desc 'deploy application'
  task :deploy, roles: :app do
    run "#{sudo} torquebox deploy #{current_path} --name #{application} --env #{deploy_env}"
    sleep 2
    run "#{sudo} test ! -f /opt/torquebox/jboss/standalone/deployments/#{application}-knob.yml.failed"
  end

  desc 'undeploy application'
  task :undeploy, roles: :app do
    run "#{sudo} torquebox undeploy #{current_path} --name #{application}"
  end

  desc 'undeploy then deploy application'
  task :redeploy, roles: :app do
    torquebox.undeploy
    torquebox.deploy
  end
end

namespace :alert do
  desc 'Alert Hipchat development room of successful deploy'
  task :hipchat, roles: :app do
    if hipchat_alert
      hipchat_token = "06e70aeee31facbcbedafa466f5a90"
      hipchat_url   = URI.escape("https://api.hipchat.com/v1/rooms/message?format=json&auth_token=#{hipchat_token}")
      message       = "@#{ENV['USER']} deployed #{branch} of #{application} to #{stage}"
      RestClient.post(hipchat_url, { room_id: "59147", from: "DeployBot", color: "green", message_format: "text", message: message })
    end
  end
end

namespace :iptables do
  desc 'start'
  task :start do
    run "#{sudo} /etc/init.d/iptables start"
  end
  desc 'stop'
  task :stop do
    run "#{sudo} /etc/init.d/iptables stop"
  end

  desc 'restart'
  task :restart do
    run "#{sudo} /etc/init.d/iptables restart"
  end
end

# SSH configuration
task :configure, roles: :app do
  system "ssh configure@#{find_servers_for_task(self).first} -p #{ssh_port}"
end

