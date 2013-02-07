set :password, ENV['PASSWORD'] if ENV['PASSWORD']
set :deploy_env, "production"
set :context_path, "/vmware"

server "192.168.125.50", :app, :web, primary: true