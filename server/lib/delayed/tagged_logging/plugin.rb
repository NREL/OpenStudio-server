module Delayed
  module TaggedLogging
    class Plugin < Delayed::Plugin
      # Delayed::Worker.logger = Rails.logger
      #
      # callbacks do |lifecycle|
      #   lifecycle.around(:execute) do |worker, *args, &block|
      #     Rails.logger.tagged "Worker:#{worker.name_prefix.strip}", "Queues:#{worker.queues.join(',')}" do
      #       block.call(worker, *args)
      #     end
      #   end
      #
      #   lifecycle.around(:invoke_job) do |job, *args, &block|
      #     Rails.logger.tagged "Job:#{job.id}" do
      #       block.call(job, *args)
      #     end
      #   end
      # end
    end
  end
end
