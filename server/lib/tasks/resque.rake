require 'resque/tasks'
task 'resque:setup' => :environment

namespace :resque do
  task :setup do
    require 'resque'
    ENV['QUEUE'] = ''

    # TODO: setup the redis URL based on the different environments
    Resque.redis = 'localhost:6379' unless Rails.env == 'production'
  end
end

# this is necessary for production environments, otherwise your background jobs will start to fail when hit
# from many different connections.
# Resque.after_fork = Proc.new { ActiveRecord::Base.establish_connection }