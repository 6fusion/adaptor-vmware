require 'capistrano_colors'
set :stages, Dir['config/deploy/*.rb'].map {|f| File.basename(f,'.rb')}

set :default_stage, "development"
require 'capistrano/ext/multistage'
set :bundle_cmd, "jruby -S bundle"
require 'bundler/capistrano'
default_run_options[:pty] = true
set :application, "adaptor-vmware"

set :ssh_options, { :forward_agent => true }
set :scm, :git
set :use_sudo, true
#set :repository, "git@github.com:6fusion/#{application}.git"
set :repository, "file://."
set :deploy_to, "/var/6fusion/#{application}"
set :deploy_via, :copy
set :deploy_env, 'development'
set :keep_releases, 2
set :context, "/"
set :user, "deploy"
set :group, "deploy"

set :branch, ENV['TAG'] || ENV['BRANCH'] || `git branch --no-color 2> /dev/null`.chomp.split("\n").grep(/^[*]/).first[/(\S+)$/, 1]

set :copy_exclude do
  %w{Capfile Vagrantfile Rakefile README.* spec config/deploy.rb
     config/deploy .rvmrc .rspec data .git .gitignore **/test.* .yardopts} +
    (stages - [deploy_env]).map { |e| "**/#{e}.*" }
end

namespace :deploy do
  desc "restart"
  task :restart, :roles => :app do
    torquebox.deploy
  end
end


after("deploy") do
  run "#{sudo} touch #{shared_path}/log/#{deploy_env}.log"
  run "#{sudo} mkdir -p #{shared_path}/data"
  run "#{sudo} ln -sfn #{shared_path}/data #{current_path}/data"
  run "#{sudo} chown -R torquebox:torquebox #{current_path}"
  run "#{sudo} chown -R torquebox:torquebox #{shared_path}"
  run "#{sudo} chmod 0666 #{shared_path}/log/#{deploy_env}.log"
  torquebox.deploy
  deploy.cleanup
end

after("deploy:rollback") do
  run "#{sudo} torquebox undeploy #{current_path} --name #{application}"
end

task :chef_run do
  run "#{sudo} chef-client"
end

namespace :logs do
  desc "tail production log files"
  task :rails, :roles => :app do
    run "tail -f #{shared_path}/log/#{deploy_env}.log" do |channel, stream, data|
      puts data
      break if stream == :err
    end
  end

  desc "tail production log files"
  task :torquebox, :roles => :app do
    run "tail -f /var/log/torquebox/torquebox.log" do |channel, stream, data|
      puts data
      break if stream == :err
    end
  end

  desc 'truncate logs'
  task :truncate, :roles => :app do
    run "#{sudo} truncate -s 0 /var/log/torquebox/torquebox.log"
    run "#{sudo} truncate -s 0 #{shared_path}/log/#{deploy_env}.log"
    run "#{sudo} rm -f /opt/torquebox/jboss/standalone/log/**/*.log"
    run "#{sudo} rm -f /opt/torquebox/jboss/standalone/log/*.{log,log.*}"
  end
end

namespace :torquebox do
  desc 'restart'
  task :restart, :roles => :app do
    run "#{sudo} restart torquebox"
  end

  desc 'deploy'
  task :deploy, :roles => :app do
    run "#{sudo} torquebox deploy #{current_path} --name #{application} --env #{deploy_env} --context-path=#{context}"
  end

  desc 'undeploy'
  task :undeploy, :roles => :app do
    run "#{sudo} torquebox undeploy #{current_path} --name #{application}"
  end

  desc 'redeploy'
  task :redeploy, :roles => :app do
    torquebox.undeploy
    torquebox.deploy
  end
end

