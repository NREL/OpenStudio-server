require 'resque/tasks'
task 'resque:setup' => :environment

namespace :resque do
  task :setup do
    require 'resque'
    ENV['QUEUE'] = ''
    Resque.redis = Rails.env == 'development' ? 'localhost:6379' : 'queue:6379'
  end
end

# this is necessary for production environments, otherwise your background jobs will start to fail when hit
# from many different connections.
# Resque.after_fork = Proc.new { ActiveRecord::Base.establish_connection }