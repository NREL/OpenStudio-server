#!/usr/bin/env ruby
require 'openstudio'

uuid = OpenStudio::UUID::create()
puts "Able to load OpenStudio.rb.  uuid #{uuid} generated."