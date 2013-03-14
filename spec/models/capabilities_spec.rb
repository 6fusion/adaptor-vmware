require 'spec_helper'
require 'models/capability'

describe Capability.all("dummy") do 
  it {should include(Capability.new(:name => "diagnostics"))}
  it {should include(Capability.new(:name => "historical_readings"))}
  it {should include(Capability.new(:name => "inode"))}
  it {should include(Capability.new(:name => "machines"))}
  it {should include(Capability.new(:name => "machine"))}
  it {should include(Capability.new(:name => "machine_readings"))}
end
