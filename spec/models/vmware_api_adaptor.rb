require 'spec_helper'

describe VmwareApiAdaptor do
  let(:inode) { INode.new(:host_ip_address=>"127.0.0.1", :user=>"test", :password=>"pass") }
  let(:vmware_api_adaptor) { VmwareApiAdaptor.new(inode) }

  describe "#new" do
    it "should set the inode attr" do
      vmware_api_adaptor.inode.should == inode
    end
  end

  describe "#connect" do
    context "when credentials are valid" do
      it "should return a connection" do
        service_instance = double("Java::ServiceInstance")
        VIJava::ServiceInstance.stub(:new).and_return(service_instance)
        vmware_api_adaptor.connection
        # Not sure this tests what we actually want
        vmware_api_adaptor.instance_variable_get(:@connection).should be_present
      end
    end
    
    context "when host cannot be reached" do
      it "logs a RemoteException error" do
        VIJava::ServiceInstance.stub(:new).and_raise(Java::JavaRmi::RemoteException.new)
        logger.should_receive(:error) 
        vmware_api_adaptor.connection
      end
    end

    context "when url is malformed" do
      it "logs a MalformedURLException error" do
        VIJava::ServiceInstance.stub(:new).and_raise(Java::JavaNet::MalformedURLException.new)
        logger.should_receive(:error) 
        vmware_api_adaptor.connection
      end
    end
  end

  describe "#disconnect" do

    context "when connected" do
      it "terminates the connection" do
        # Need to find out what this really returns
        server_connection = double("VIJava::ServiceInstance", :logout => true)
        service_instance = double("VIJava::ServiceInstance", :get_server_connection => server_connection)
        
        vmware_api_adaptor.stub(:connected?).and_return(true)
        vmware_api_adaptor.instance_variable_set(:@connection, service_instance)
        vmware_api_adaptor.disconnect.should be_nil                  
      end
    end

    context "when not connected" do
      it "returns nil" do
        vmware_api_adaptor.stub(:connected?).and_return(false)
        vmware_api_adaptor.disconnect.should be_nil                  
      end
    end
  end

  describe "#root_folder" do
    let(:service_instance) { double("VIJava::ServiceInstance", :get_root_folder => '/root_path') }

    before(:each) do
      vmware_api_adaptor.instance_variable_set(:@connection, service_instance)
    end

    it "returns the path" do
      vmware_api_adaptor.root_folder.should == '/root_path' 
    end
    it "logs an InvalidProperty error" do
      service_instance.stub(:get_root_folder).and_raise(Java::ComVmwareVim25::InvalidProperty.new)
      logger.should_receive(:error) 
      vmware_api_adaptor.root_folder 
    end

    it "logs a RuntimeFault error" do
      service_instance.stub(:get_root_folder).and_raise(Java::ComVmwareVim25::RuntimeFault.new)
      logger.should_receive(:error) 
      vmware_api_adaptor.root_folder
    end

    it "logs an RemoteException error" do
      service_instance.stub(:get_root_folder).and_raise(Java::JavaRmi::RemoteException.new)
      logger.should_receive(:error) 
      vmware_api_adaptor.root_folder
    end
  end

  describe "#get_about_info" do
    context "when connection is good" do
      it "returns info about the system"
    end

    context "when connection is bad" do
      it "raise an error"
    end
  end

  describe "#get_statistics_level" do
    context "when connection is good" do
      context "and the performance internals are nil" do
        it "returns an empty array"
      end
      context "and the performance internals exist" do
        it "returns info about the system"
      end
    end

    context "when connection is bad" do
      it "raise an error"
    end
  end

end
