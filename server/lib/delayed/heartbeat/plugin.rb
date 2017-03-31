# MIT Licensed Code from https://github.com/salsify/delayed_job_heartbeat_plugin
# Modified by Nicholas Long to support mongoid and add more queue information

module Delayed
  module Heartbeat
    class Plugin < Delayed::Plugin
      callbacks do |lifecycle|
        lifecycle.before(:execute) do |worker|
          @heartbeat = WorkerHeartbeat.new(worker) # if Rails.configuration.jobs.heartbeat_enabled
        end

        lifecycle.after(:execute) do |_worker|
          @heartbeat.stop if @heartbeat
        end
      end
    end
  end
end
