require 'rubygems'  # not necessary for Ruby 1.9
require 'openstudio'

#x=ARGV[0] #x value
#uuid=ARGV[1] #uuid

uuid = OpenStudio::createUUID.to_s.gsub('{','').gsub('}','')

puts uuid

