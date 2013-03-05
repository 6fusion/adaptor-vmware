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
require 'models/machine'

describe 'connect' do
  context 'connection refused' do
    it 'reports host unreachable' do
      inode = INode.new(:host_ip_address=>"127.0.0.1", :user=>"test", :password=>"pass")
      vmware_api_adaptor = VmwareApiAdaptor.new(inode)
      vmware_api_adaptor.stub(:connect).once.with(any_args()) {raise java::rmi::ConnectException.new("Connection refused")}
      inode.vmware_api_adaptor = vmware_api_adaptor
      expect { Machine.all(inode)}.to raise_error(Exceptions::Unrecoverable)
    end
  end
  context 'given invalid host' do
    it 'reports host unreachable' do
      inode = INode.new(:host_ip_address=>"127.0.0.1", :user=>"test", :password=>"pass")
      vmware_api_adaptor = VmwareApiAdaptor.new(inode)
      vmware_api_adaptor.stub(:connect).once.with(any_args()) {raise java::net::UnknownHostException.new("vcenter.mycorp.mydomain")}
      inode.vmware_api_adaptor = vmware_api_adaptor
      expect { Machine.all(inode)}.to raise_error(Exceptions::Unrecoverable)
    end
  end
  context 'given invalid credentials' do
    it 'reports invalid login' do
      inode = INode.new(:host_ip_address=>"127.0.0.1", :user=>"test", :password=>"pass")
      vmware_api_adaptor = VmwareApiAdaptor.new(inode)
      vmware_api_adaptor.stub(:connect).once.with(any_args()) {raise Vim::InvalidLogin.new}
      inode.vmware_api_adaptor = vmware_api_adaptor
      expect { Machine.all(inode)}.to raise_error(Exceptions::Forbidden)
    end
  end
end
