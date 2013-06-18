$xenTestVariables = {:inode_uuid => "", :machine_uuid => "", :readings => ""}
$vmwareTestVariables = {:inode_uuid => "", :machine_uuid => "", :readings => ""}

## Get a list of inodes in the existing xen adapter.
Given(/^I get a list of inodes from an existing xen adapter$/) do
    response                = JSON.parse(RestClient.get "http://adaptor-xen-1-0-001.6fusion.vodka:8080/inodes/", :content_type => :json, :accept => :json)
    $xenTestVariables[:inode_uuid] = response[0]["uuid"]
    #print("#{$xenTestVariables[:inode_uuid]}\n\n\n")
end

## Get a list of machines in the existing xen adapter.
Given(/^I get a list of machines from an existing xen adapter$/) do
    response                = JSON.parse(RestClient.get "http://adaptor-xen-1-0-001.6fusion.vodka:8080/inodes/#{$xenTestVariables[:inode_uuid]}/machines/", :content_type => :json, :accept => :json)
    $xenTestVariables[:machine_uuid] = response[0]["uuid"]
    #print("#{$xenTestVariables[:machine_uuid]}\n\n\n")
end

## Get a list of machines in the existing xen adapter.
Given(/^I get readings of an existing machine from an existing xen adapter$/) do
    response                = JSON.parse(RestClient.get "http://adaptor-xen-1-0-001.6fusion.vodka:8080/inodes/#{$xenTestVariables[:inode_uuid]}/machines/#{$xenTestVariables[:machine_uuid]}/readings", :content_type => :json, :accept => :json)
end

## Get a list of inodes in the existing vmware adapter.
Given(/^I get a list of inodes from an existing vmware adapter$/) do
    response                = JSON.parse(RestClient.get "http://adaptor-vmware-1-0-001.6fusion.vodka:8080/inodes/", :content_type => :json, :accept => :json)
    $vmwareTestVariables[:inode_uuid] = response[0]["uuid"]
    #print("#{$vmwareTestVariables[:inode_uuid]}\n\n\n")
end

## Get a list of machines in the existing vmware adapter.
Given(/^I get a list of machines from an existing vmware adapter$/) do
    response                = JSON.parse(RestClient.get "http://adaptor-vmware-1-0-001.6fusion.vodka:8080/inodes/#{$vmwareTestVariables[:inode_uuid]}/machines/", :content_type => :json, :accept => :json)
    $vmwareTestVariables[:machine_uuid] = response[0]["uuid"]
    #print("#{$vmwareTestVariables[:machine_uuid]}\n\n\n")
end

## Get a list of machines in the existing vmware adapter.
Given(/^I get readings of an existing machine from an existing vmware adapter$/) do
    response                = JSON.parse(RestClient.get "http://adaptor-vmware-1-0-001.6fusion.vodka:8080/inodes/#{$vmwareTestVariables[:inode_uuid]}/machines/#{$vmwareTestVariables[:machine_uuid]}/readings", :content_type => :json, :accept => :json)
end