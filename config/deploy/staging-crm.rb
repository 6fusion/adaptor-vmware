server '192.168.113.8', :app
set :deploy_env, 'staging -crm'
set :context_path, "/vmware"