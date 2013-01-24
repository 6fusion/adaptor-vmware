set :hipchat_alert, false
set :repository, "file://."
set :deploy_via, :copy
set :ssh_port, 2225
set :context_path, "/vmware"

server 'adaptor-vmware.2223', :app

before "deploy", "iptables:stop"

namespace :inodes do
  desc "Register an inode"
  task :register do
    Dir['data/*.json'].each do |file|
      upload(file, "#{current_path}/data", via: :scp)
    end
  end
end

namespace :machine do
  desc 'Create from OVF'
  task :create do
    ovf     = File.read(ENV['OVF'])
    inode   = ENV['INODE'] || '1'
    options = ENV['OPTIONS'] || { }
    payload = { ovf: ovf, options: options }
    uri     = "#{url}/inodes/#{inode}/machines"
    headers = { accept: :json, content_type: :json }
    response = ""
    puts Benchmark.measure {
      begin
        response = RestClient::Request.execute(method: :post, url: uri, payload: payload, headers: headers, timeout: -1)
      rescue RestClient::Exception => exception
        puts exception.response.inspect
        fail
      end
    }
    puts response
  end
end
