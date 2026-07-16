# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

# Regression specs for ResqueJobs::RunSimulateDataPoint.perform's new run_flag guard.
#
# Incident: a job can sit on the Resque :simulations/:requeued list for a long time
# (worker backlog, HPA scale-down, etc). If ops explicitly stopped/quarantined the owning
# analysis in the meantime (Analysis#stop_analysis / #soft_stop_analysis, e.g. a
# permanently corrupt seed zip), the analysis' run_flag flips to false -- but the old
# completed+completed-normal-only skip check did not look at run_flag at all, so a stale
# queued/started datapoint for an already-stopped analysis would still get a fresh
# DjJobs::RunSimulateDataPoint worker dispatched against it, recreating the very
# failure/deadlock the stop was meant to end.
#
# This mirrors the light, non-Capybara/non-depends_resque style already used at the
# bottom of dj_run_simulation_data_point_spec.rb and in spec/models/analysis_init_spec.rb
# (the sibling hardening commit) -- ResqueJobs::RunSimulateDataPoint.perform is plain Ruby
# dispatch-guard logic, not something that needs a live Resque/Redis broker to exercise;
# DjJobs::RunSimulateDataPoint.new/#perform are mocked so the heavy simulation pipeline
# never actually runs. See resque_run_simulation_data_point_spec.rb for the full
# Capybara/depends_resque integration coverage of this class.
RSpec.describe ResqueJobs::RunSimulateDataPoint, type: :model do
  before { Project.destroy_all }

  after { Project.destroy_all }

  let(:project) { Project.new.tap(&:save!) }
  let(:analysis) { Analysis.new(project_id: project.id).tap(&:save!) }
  let(:data_point) { DataPoint.new(analysis_id: analysis.id).tap(&:save!) }

  def set_data_point_status(status:, status_message: '')
    data_point.update!(status: status, status_message: status_message)
  end

  describe '.perform' do
    context 'when the owning analysis was started and then stopped (run_flag == false with a start time)' do
      before do
        # A stopped analysis was necessarily started first: starting creates its Job
        # records (Analysis#start_time reads them), stop_analysis then flips run_flag.
        # run_flag alone is NOT a stop marker - it also defaults to false on analyses
        # nobody has started yet (see the regression context below).
        Job.new(analysis_id: analysis.id, index: 0, start_time: Time.now.utc, status: 'started').save!
        analysis.update!(run_flag: false)
      end

      %w[started queued na].each do |status|
        it "skips dispatching a fresh worker for a stale '#{status}' datapoint " \
           '(the core regression: this used to slip past the completed-only check)' do
          set_data_point_status(status: status)

          expect(DjJobs::RunSimulateDataPoint).not_to receive(:new)

          described_class.perform(data_point.id)
        end
      end

      it 'still skips even if the datapoint had already reached completed/completed normal' do
        set_data_point_status(status: 'completed', status_message: 'completed normal')

        expect(DjJobs::RunSimulateDataPoint).not_to receive(:new)

        described_class.perform(data_point.id)
      end

      it 'still skips a completed-but-failed datapoint (run_flag wins regardless of status)' do
        set_data_point_status(status: 'completed', status_message: 'datapoint failure')

        expect(DjJobs::RunSimulateDataPoint).not_to receive(:new)

        described_class.perform(data_point.id)
      end
    end

    context 'when the owning analysis was never started (run_flag still default false, no jobs)' do
      it 'still dispatches a worker: a datapoint submitted directly against a fresh analysis must run' do
        # Regression: run_flag defaults to false, so guarding on run_flag alone skipped
        # every datapoint submitted via batch upload + submit_simulation before the
        # analysis was started - caught by resque_run_simulation_data_point_spec.rb
        # ('runs a datapoint') in the docker CI job.
        set_data_point_status(status: 'na')

        expect(analysis.start_time).to be_nil
        worker = instance_double(DjJobs::RunSimulateDataPoint, perform: true)
        expect(DjJobs::RunSimulateDataPoint).to receive(:new).with(data_point.id, {}).and_return(worker)

        described_class.perform(data_point.id)
      end
    end

    context 'when the owning analysis has run_flag == true (normal in-flight processing; existing paths preserved)' do
      before { analysis.update!(run_flag: true) }

      it 'still dispatches a worker for a not-yet-completed datapoint (existing "run it" path)' do
        set_data_point_status(status: 'started')

        worker = instance_double(DjJobs::RunSimulateDataPoint, perform: true)
        expect(DjJobs::RunSimulateDataPoint).to receive(:new).with(data_point.id, {}).and_return(worker)

        described_class.perform(data_point.id)
      end

      it 'still skips a datapoint that already completed successfully ' \
         '(existing "skip, already succeeded" path -- e.g. requeued after a spot-instance kill)' do
        set_data_point_status(status: 'completed', status_message: 'completed normal')

        expect(DjJobs::RunSimulateDataPoint).not_to receive(:new)

        described_class.perform(data_point.id)
      end
    end
  end
end
