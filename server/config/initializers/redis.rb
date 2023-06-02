# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Skip this if in a local deployment, otherwise configure the Redis connection
if Rails.env =~ /local/
  # don't do anything, local uses delayed_jobs
elsif Rails.env.production?
  require 'resque'
  uri = URI.parse(ENV['REDIS_URL'])
  Resque.redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
elsif ['development', 'test'].include? Rails.env
  require 'resque'
  Resque.redis = 'localhost:6379'
else
  require 'resque'
  uri =  ENV.has_key?('REDIS_URL') ? ENV['REDIS_URL'] : 'queue:6379'
  uri = URI.parse(uri)
  #Resque.redis = 'queue:6379'
  Resque.redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
end
