#!/usr/bin/env rackup
# encoding: utf-8

# This file can be used to start Padrino,
# just execute it from the command line.

require File.expand_path("../config/boot.rb", __FILE__)

if ENV['RACK_ENV'] != 'production'
  require 'new_relic/rack/developer_mode'
  use NewRelic::Rack::DeveloperMode
end

run Padrino.application
