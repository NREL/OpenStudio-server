# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

# Regression specs for the 2026-08-18 redis-maxclients outage: resque's post-fork
# reconnect only retried Redis::BaseConnectionError, so a saturated server's
# "-ERR max number of clients reached" reply (Redis::CommandError) killed the
# child on its first Redis use, the failure could not be reported (reporting
# needs Redis too), and the job vanished - stranding analyses in 'queued'.
# config/initializers/resque_reconnect_retry.rb makes reconnect retry
# CommandError as well, with backoff. Resque only loads in resque deployments,
# so these run in the docker CI job (see docker/server/run-server-tests.sh).
RSpec.describe 'ResqueReconnectRetry', depends_resque: true do
  let(:worker) { Resque::Worker.new(:spec_queue) }
  let(:data_store) { double('data_store') }
  let(:max_tries) { ResqueReconnectRetry::MAX_TRIES }

  before do
    allow(worker).to receive(:data_store).and_return(data_store)
    allow(worker).to receive(:log_with_severity)
    allow(worker).to receive(:sleep) # no real waiting in specs
  end

  it 'overrides Resque::Worker#reconnect' do
    expect(worker.method(:reconnect).owner).to eq ResqueReconnectRetry
  end

  it 'reconnects once and does not sleep when the connection succeeds' do
    expect(data_store).to receive(:reconnect).once
    worker.reconnect
    expect(worker).not_to have_received(:sleep)
  end

  it 'retries Redis::CommandError (e.g. maxclients saturation) with backoff until it succeeds' do
    calls = 0
    allow(data_store).to receive(:reconnect) do
      calls += 1
      raise Redis::CommandError, 'ERR max number of clients reached' if calls < 3
    end

    expect { worker.reconnect }.not_to raise_error
    expect(calls).to eq 3
    expect(worker).to have_received(:sleep).with(2).ordered
    expect(worker).to have_received(:sleep).with(4).ordered
  end

  it 'still retries Redis::BaseConnectionError (stock resque behavior preserved)' do
    calls = 0
    allow(data_store).to receive(:reconnect) do
      calls += 1
      raise Redis::CannotConnectError, 'Error connecting to Redis' if calls < 2
    end

    expect { worker.reconnect }.not_to raise_error
    expect(calls).to eq 2
  end

  it 're-raises after exhausting the retries' do
    allow(data_store).to receive(:reconnect)
      .and_raise(Redis::CommandError, 'ERR max number of clients reached')

    expect { worker.reconnect }.to raise_error(Redis::CommandError, /max number of clients/)
    # initial attempt + MAX_TRIES retries
    expect(data_store).to have_received(:reconnect).exactly(max_tries + 1).times
    expect(worker).to have_received(:sleep).exactly(max_tries).times
  end

  it 'does not swallow or retry unrelated errors' do
    allow(data_store).to receive(:reconnect).and_raise(RuntimeError, 'boom')

    expect { worker.reconnect }.to raise_error(RuntimeError, 'boom')
    expect(data_store).to have_received(:reconnect).once
    expect(worker).not_to have_received(:sleep)
  end
end
