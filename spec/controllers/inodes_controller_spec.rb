require 'spec_helper'
require 'models/inode'

describe "/inodes/:inode" do
  let(:inode) { mock('inode',
    capabilities: [mock('capability', name: 'machines')],
    networks: [],
    machines: [],
    about: '',
    statistics_levels: [],
    virtual_machines: [],
    datastores: [])
  }
  before(:each) do
    INode.stub(:find_by_uuid).and_return(inode)
  end

  describe 'GET /inodes' do
    it "should be successful" do
      get "/inodes"
      last_response.should be_ok
    end
  end

  describe 'GET /inodes/:inode/diagnostics.zip' do
    it "should be successful" do
      get "/inodes"
      last_response.should be_ok
    end
  end


  describe 'GET /inodes/:inode/capabilities' do
    it "should be successful" do
      get "/inodes/inode_id"
      last_response.should be_ok
    end
  end

  describe 'GET /inodes/:inode/machines' do
    it "should be successful" do
      get "/inodes/inode_id"
      last_response.should be_ok
    end
  end
end
