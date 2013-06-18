@adapters
Feature: Adapters

  As a user of adapters
  I want to verify that I can send and receive information on a particular adapter

  @smoke_adapters @get_list_of_machines

  Scenario: I want to verify that I can get a list of machines from the xen adapter.
    When I get a list of inodes from an existing xen adapter
    When I get a list of machines from an existing xen adapter
    When I get readings of an existing machine from an existing xen adapter
    When I get a list of inodes from an existing vmware adapter
    When I get a list of machines from an existing vmware adapter
    When I get readings of an existing machine from an existing vmware adapter