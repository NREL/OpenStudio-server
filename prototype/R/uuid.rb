require 'rubygems'  # not necessary for Ruby 1.9
require 'mongo'

include Mongo

x=ARGV[0] #x value
uuid=ARGV[1] #uuid

@client = MongoClient.new("localhost", 27017)
@db     = @client['R-db']
@coll   = @db['test']

@coll.insert({"x" => x, "uuid" => uuid})
