# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************
require 'resque'
require 'resque/tasks'
require 'resque-retry'
require 'resque/failure/base'
require 'resque/failure/redis'

task 'resque:setup' => :environment

#Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
#Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

namespace :resque do
  task :setup do
    require 'resque'
    ENV['QUEUE'] = ''
    Resque.redis = Rails.env.development? ? 'localhost:6379' : 'queue:6379'
  end
end

# this is necessary for production environments, otherwise your background jobs will start to fail when hit
# from many different connections.
# Resque.after_fork = Proc.new { ActiveRecord::Base.establish_connection }
