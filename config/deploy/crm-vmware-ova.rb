set :context_path, "/vmware"
set :rails_env, "production"
server "192.168.121.50", :app, :web, primary: true
