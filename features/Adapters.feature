@adapters
Feature: Adapters

  As a user of adapters
  I want to verify that I can send and receive information on a particular adapter

  Background: #tbd

  @smoke_adapters @get_list_of_machines

  Scenario: I want to verify that I can get a list of machines from the xen adapter.
    Given I get a list of machines from the existing xen adapter.
    Then the list of machines is received