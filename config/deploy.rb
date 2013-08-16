require 'colorize'
require 'capistrano/ext/multistage'
require 'capistrano_colors'
require 'capistrano-helpers/specs'
require 'capistrano-helpers/version'
require 'bundler/capistrano'
require 'open-uri'
require 'rest_client'

default_run_options[:pty] = true

set :stages, Dir['config/deploy/*.rb'].map { |f| File.basename(f, '.rb') }
set :default_stage, "development"
set :bundle_without, [:development, :test, :automation, :assets, :deploy]
# set :bundle_cmd, "jruby -S bundle"
# set :bundle_dir, fetch(:shared_path)+"/bundle"
# set :bundle_flags, "--deployment --quiet"

set :application, 'adaptor-vmware'
set :user, 'deploy'
set :group, 'deploy'

set :ssh_options, { forward_agent: true }
set :scm, "git"
set :use_sudo, true
set :repository, "git@github.com:6fusion/#{application}.git"
set :branch, ENV['TAG'] || ENV['BRANCH'] || (`git branch --no-color 2> /dev/null`.chomp.split("\n").grep(/^[*]/).first[/(\S+)$/, 1] rescue "")
set :deploy_to, "/var/6fusion/#{application}"
set :deploy_via, :remote_cache
set :rails_env, lambda { fetch(:stage) }
set :keep_releases, 2
set :tail_logs_location, "/var/log/torquebox/torquebox.log"
set :context_path, ""
set :hipchat_alert, ENV['HIPCHAT_ALERT'] || true
set :password, ENV['PASSWORD'] if ENV['PASSWORD']
set :tag, (`git branch --no-color 2> /dev/null`.chomp.split("\n").grep(/^[*]/).first[/(\S+)$/, 1] rescue "")
set :current_branch, nil
set :current_version, nil
set :exit_status_on_rollback, ENV['EXIT_STATUS_ON_ROLLBACK'].to_i || 0

# Adaptor-VMware Specifics
set :ssh_port, 22
set :copy_exclude do
  %w{Capfile Vagrantfile README.* spec config/deploy.rb
     config/deploy .rvmrc .rspec data .git .gitignore **/test.* .yardopts} +
    (stages - [rails_env]).map { |e| "**/#{e}.*" }
end

# Additional Deployment Actions
before "deploy", "verify:rules"

after("deploy:create_symlink") do
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

  # Setup the tmp directory
  run "#{sudo} mkdir -p #{current_path}/tmp"
  run "#{sudo} chmod 0755 #{current_path}/tmp"
  run "#{sudo} chown -R torquebox:torquebox #{current_path}/tmp"

  # Add the commit SHA to the VERSION file
  deploy.update_version

  # Deploy the application
  torquebox.deploy
end

after('deploy') do
  deploy.cleanup
end

namespace :deploy do
  task :update_version do
    puts "*** executing \"git log origin/#{tag} | head -1\"".yellow
    latest_commit_sha = `git log origin/#{tag} | head -1`.gsub("commit ", "")

    run "#{sudo} sed -i -e '$a\\' #{release_path}/VERSION && #{sudo} echo -n \"#{latest_commit_sha}\" >> #{release_path}/VERSION"
  end

  desc 'restart torquebox'
  task :restart do
    torquebox.restart
  end

  desc 'start torquebox'
  task :start do
    torquebox.start
  end

  desc 'stop torquebox'
  task :stop do
    torquebox.stop
  end

end

namespace :verify do
  task :branch, roles: :app do
    current_branch = capture("#{sudo} cat #{deploy_to}/current/VERSION || true").split("\r\n").reject(&:empty?).first
    puts "*** '#{current_branch}' branch is currently deployed to #{rails_env}.".light_blue

    current_branch
  end

  task :version, roles: :app do
    current_version = capture("#{sudo} cat #{deploy_to}/current/VERSION || true").split("\r\n").reject(&:empty?).last
    puts "*** '#{current_version}' commit is currently deployed to #{rails_env}.".light_blue

    current_version
  end

  task :rules, roles: :app do
    puts "*** Verifying you are allowed to deploy this branch to this environment.".light_blue

    next if stage == :development

    if tag == "master"
      puts "*** Skipping verification since you are deploying master.".light_blue
      next
    end

    deployed_branch = verify.branch
    deployed_version = verify.version

    next if deployed_branch.nil? || deployed_branch.empty? || deployed_branch.include?('No such file or directory')

    if deployed_branch == tag
      puts "*** Skipping verification since you are deploying the same branch.".light_blue
      next
    end

    if deployed_branch == "master"
      puts "*** Skipping verification since master is currently deployed.".light_blue
      next
    end

    puts "*** Updating local commit logs to check the status of the found commit.".light_blue
    `git fetch origin`

    puts "*** Looking at master branch to determine if commit exists.".light_blue
    branches = `git branch -r --contains #{deployed_version}`.split(/\r\n|\n/).map { |branch| branch.strip! }

    unless branches.include?('origin/master') || branches.include?("origin/#{tag}")
      action_requested = Capistrano::CLI.ui.ask "*** If you continue deploying this branch you will be overwriting someone else's work.  Would you like to [c]ontinue, [s]top, or [r]eset the environment back to master? [stop]: ".red

      case action_requested.to_s
      when "c"
        puts "*** Overriding default rules and deploying your branch, you evil evil coder.  You were warned!".red
        next
      when "r"
        puts "*** Reseting the environment to master.".light_blue
        set :tag, "master"
      else
        puts "*** Aborting deploy...".red
        abort = true
      end
    end

    abort "*** Since #{deployed_branch} is currently deployed to #{rails_env}.  Please either merge #{deployed_branch} to master OR re-deploy either #{deployed_branch} or master branch to this environment.".red unless branches.include?('origin/master') || branches.include?("origin/#{tag}") if abort
    puts "*** All rules have passed, continuing with deployment.".light_blue
  end
end

namespace :logs do
  desc "tail log files"
  task :tail, roles: :app do
    run "tail -f #{tail_logs_location}" do |channel, stream, data|
      data.split("\n").each do |line|
        puts "*** [#{channel[:host]}] #{line}".light_blue
      end
      break if stream == :err
    end
    puts.light_blue
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
    run "#{sudo} restart_torquebox"
  end

  desc 'deploy application'
  task :deploy, roles: :app do
    run "#{sudo} torquebox deploy #{current_path} --name #{application} --env #{rails_env} --context-path=#{context_path}", :shell => "su - deploy -s bash"
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

def change_password(user = "root")
  run "passwd #{user}", :pty => true do |ch, stream, data|
    if data =~ /New password:/
      ch.send_data(Capistrano::CLI.password_prompt("New password for #{user}: ") + "\n")
    elsif data =~ /Retype new password:/
      ch.send_data(Capistrano::CLI.password_prompt("Retype new password for #{user}: ") + "\n")
    else
      Capistrano::Configuration.default_io_proc.call(ch, stream, data)
    end
  end
end

after 'deploy:rollback' do
  puts "#{application} Rolled back".red
  exit(exit_status_on_rollback)
end
