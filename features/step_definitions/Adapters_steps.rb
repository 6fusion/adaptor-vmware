
## Get a list of machines in the existing xen adapter.
Given(/^I get a list of machines from the existing xen adapter\.$/) do
    response                = JSON.parse(RestClient.get ":8080/inodes/", :content_type => :json, :accept => :json)
end

Then(/^the list of machines is received$/) do
    pending # express the regexp above with the code you wish you had
end
