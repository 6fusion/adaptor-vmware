set :deploy_env, "whiskey"
set :context_path, "/vmware"

server "crm-vmware-3-0-001.6fusion.#{deploy_env}", :app, :crm