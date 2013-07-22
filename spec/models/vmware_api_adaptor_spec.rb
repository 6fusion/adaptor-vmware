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
        lambda { vmware_api_adaptor.connection }.should raise_error(Exceptions::RemoteConnectionException)
      end
    end

    context "when url is malformed" do
      it "logs a MalformedURLException error" do
        VIJava::ServiceInstance.stub(:new).and_raise(Java::JavaNet::MalformedURLException.new)
        logger.should_receive(:error) 
        lambda { vmware_api_adaptor.connection }.should raise_error(Exceptions::RemoteConnectionException)
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
      lambda do 
        vmware_api_adaptor.root_folder
      end.should raise_error(Exceptions::Unrecoverable)
    end

    it "logs a RuntimeFault error" do
      service_instance.stub(:get_root_folder).and_raise(Java::ComVmwareVim25::RuntimeFault.new)
      logger.should_receive(:error) 
      lambda do 
        vmware_api_adaptor.root_folder
      end.should raise_error(Exceptions::Unrecoverable)
    end

  end

  describe "#get_about_info" do
    context "when no exceptions" do 
      it "returns info about the system" do
        dynamic_property = double("Vim::DynamicProperty", :get_name => 'DynamicPropertyKey', :get_value => 'DynamicPropertyValue')
        about_methods_mocks = {
          :get_full_name                => "fullName", 
          :get_vendor                   => "vendor",
          :get_version                  => "version",
          :get_build                    => "build",
          :get_locale_version           => "localeVersion",
          :get_locale_build             => "localeBuild",
          :get_os_type                  => "osType",
          :get_product_line_id          => "productLineId",
          :get_api_type                 => "apiType",
          :get_api_version              => "apiVersion",
          :get_instance_uuid            => "instanceUuid",
          :get_license_product_name     => "licenseProductVersion",
          :get_name                     => "name",
          :get_dynamic_property         => [dynamic_property]
        }
        about_info_object = double("Vim::AboutInfo", about_methods_mocks)
        service_instance =  double("VIJava::ServiceInstance", :get_about_info => about_info_object)

        vmware_api_adaptor.instance_variable_set(:@connection, service_instance)
        expected_about_hash = {
          "fullName"              => "fullName", 
          "vendor"                => "vendor",
          "version"               => "version",
          "build"                 => "build",
          "localeVersion"         => "localeVersion",
          "localeBuild"           => "localeBuild",
          "osType"                => "osType",
          "productLineId"         => "productLineId",
          "apiType"               => "apiType",
          "apiVersion"            => "apiVersion",
          "instanceUuid"          => "instanceUuid",
          "licenseProductVersion" => "licenseProductVersion",
          "name"                  => "name",
          "DynamicPropertyKey"    => "DynamicPropertyValue"
        }
        vmware_api_adaptor.get_about_info == expected_about_hash
      end
    end

    context "when exceptions" do
      it "raise an error" do
        service_instance = double("VIJava::ServiceInstance", :get_about_info => {})
        vmware_api_adaptor.instance_variable_set(:@connection, service_instance)
        service_instance.stub(:get_about_info).and_raise(Java::ComVmwareVim25::RuntimeFault.new)
        logger.should_receive(:error) 

        lambda do 
          vmware_api_adaptor.get_about_info
        end.should raise_error(Exceptions::UnprocessableEntity)
      end
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
