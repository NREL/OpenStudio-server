# MIT Licensed Code from https://github.com/salsify/delayed_job_heartbeat_plugin
# Modified by Nicholas Long to support mongoid and add more queue information

module Delayed
  module Heartbeat
    class WorkerHeartbeat
      def initialize(worker)
        @worker_model = create_worker_model(worker)

        # Use a self-pipe to safely shutdown the heartbeat thread
        @stop_reader, @stop_writer = IO.pipe

        @heartbeat_thread = Thread.new { run_heartbeat_loop }
        # We don't want the worker to continue running if the
        # heartbeat can't be written
        @heartbeat_thread.abort_on_exception = true
      end

      def alive?
        @heartbeat_thread.alive?
      end

      def stop
        # Use the self-pipe to tell the heartbeat thread to cleanly
        # shutdown
        if @stop_writer
          @stop_writer.write_nonblock('stop')
          @stop_writer.close
          @stop_writer = nil
        end
      end

      private

      def create_worker_model(worker)
        # Just recreate the worker model to avoid the race condition where
        # it gets deleted before we can update its last heartbeat

        # delayed_job.worker_1 host:nlong-23980s.nrel.gov pid:89396
        name, hostname, pid = worker.name.split(' ')
        begin
          hostname.gsub!('host:', '')
        rescue
          nil
        end
        begin
          pid.gsub!('pid:', '').to_i
        rescue
          0
        end

        ComputeNode.where(name: name, hostname: hostname).destroy_all
        cn = ComputeNode.create!(name: name, hostname: hostname)
        cn.queues = worker.queues
        cn.pid = pid
        cn.node_type = 'unknown'
        cn.cores = 1
        cn.save!
      end

      def run_heartbeat_loop
        # while true
        #   break if sleep_interruptibly(heartbeat_interval)
        #   @worker_model.update_heartbeat
        # end
        rescue Exception => e
            Rails.logger.error("Worker heartbeat error: #{e.message}: #{e.backtrace.join('\n')}")
            raise e
        ensure
            Rails.logger.info('Shutting down worker heartbeat thread')
        # @stop_reader.close
        # @worker_model.delete
        # Delayed::Backend::ActiveRecord::Job.clear_active_connections!
      end

      def heartbeat_interval
        # Rails.configuration.jobs.heartbeat_interval_seconds
      end

      # Returns a truthy if the sleep was interrupted
      def sleep_interruptibly(secs)
        IO.select([@stop_reader], nil, nil, secs)
      end
    end
  end
end
