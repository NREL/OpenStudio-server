# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Resque forks a child per job, and the child must open a new Redis connection
# before performing (Resque::Worker#reconnect). Stock resque (2.6) only retries
# Redis::BaseConnectionError there. But a saturated Redis accepts the socket and
# replies "-ERR max number of clients reached" (similarly "-LOADING ..." while
# replaying the AOF after a restart), which redis-rb raises as
# Redis::CommandError - not a BaseConnectionError - so the child dies on its
# first job instantly, with no retry. Worse, reporting that failure needs Redis
# too, so the job vanishes without a trace and, for InitializeAnalysis, the
# analysis is stranded in 'queued' forever (2026-08-18 k8s outage: large spot
# worker fleets pushed connected_clients past maxclients).
#
# This override also retries Redis::CommandError with a longer backoff. During
# reconnect the only commands on the wire are connection setup (AUTH/SELECT), so
# a CommandError here is effectively connection-level and safe to retry. If the
# retries are exhausted the error is re-raised and handled exactly as before.
#
# This file must load after config/initializers/redis.rb (alphabetical order
# guarantees it), and is a no-op in delayed_job deployments where resque is
# never required.
if defined?(Resque::Worker)
  module ResqueReconnectRetry
    MAX_TRIES = Integer(ENV.fetch('RESQUE_RECONNECT_RETRIES', 5))

    def reconnect
      tries = 0
      begin
        data_store.reconnect
      rescue Redis::BaseConnectionError, Redis::CommandError => e
        if (tries += 1) <= MAX_TRIES
          log_with_severity :error, "Error reconnecting to Redis (#{e.class}: #{e.message}); retry #{tries}/#{MAX_TRIES}"
          sleep(tries * 2)
          retry
        else
          log_with_severity :error, "Error reconnecting to Redis (#{e.class}: #{e.message}); giving up after #{MAX_TRIES} retries"
          raise
        end
      end
    end
  end

  Resque::Worker.prepend(ResqueReconnectRetry)
end
