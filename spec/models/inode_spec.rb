require 'spec_helper'
require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  logger.info("#{jar}")
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "java.net.URL"
# java_import "java.util.ArrayList"
# java_import "com.vmware.vim25.InvalidLogin"
java_import "java.rmi.RemoteException"
module VIJavaUtil
  include_package "com.vmware.vim25.mo.util"
end
module VIJava
  include_package "com.vmware.vim25.mo"
end
module Vim
  include_package "com.vmware.vim25"
end
require 'models/inode'

describe 'serialization' do
  context 'to json' do
    it 'only has attributes needed' do
      inode = INode.new(:uuid=>"myuuid", :host_ip_address=>"127.0.0.1", :user=>"test", :password=>"pass")
      vmware_api_adaptor = VmwareApiAdaptor.new(inode)
      inode.to_json.should eql('{"uuid":"myuuid","host_ip_address":"127.0.0.1","user":"test","password":"pass"}')
    end
  end
end