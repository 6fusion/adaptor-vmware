# This is setup for the staging (AWS) environment using a meter that Lackey setup.
# Eventually this should be fixed to use the test environment's url (it should work locally and in Magnum CI)
URL = "http://172.20.5.103:8080/vmware"
vars = {}

## Get a list of inodes in the existing vmware adapter.
Given(/^I get a list of inodes from an existing vmware adapter$/) do
  response = JSON.parse(RestClient.get "#{URL}/inodes", :content_type => :json, :accept => :json)
  vars[:inode_uuid] = response[0]["uuid"]
end

## Get a list of machines in the existing vmware adapter.
Given(/^I get a list of machines from an existing vmware adapter$/) do
  response = JSON.parse(RestClient.get "#{URL}/inodes/#{vars[:inode_uuid]}/machines/", :content_type => :json, :accept => :json)
  vars[:machine_uuid] = response[0]["uuid"]
end

## Get a list of machines in the existing vmware adapter.
Given(/^I get readings of an existing machine from an existing vmware adapter$/) do
  response = JSON.parse(RestClient.get "#{URL}/inodes/#{vars[:inode_uuid]}/machines/#{vars[:machine_uuid]}/readings", :content_type => :json, :accept => :json)
end
