# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'rbconfig'
require 'timeout'

# REAL-AWS smoke test for external batch execution. Runs the algo-spec SEB
# discrete LHS calibration project (real EnergyPlus + calibration objective
# functions) on YOUR AWS Batch infrastructure and verifies the results against
# the same golden values docker_stack_algo_spec.rb (:lhs_discrete) asserts.
#
# SKIPPED unless configured — it spends real (small) money: a few minutes of
# one on-demand instance plus S3 pennies. Setup: external_batch/aws/WALKTHROUGH.md.
#
#   export AWS_BATCH_SMOKE_BUCKET=osaf-batch-<account>
#   export AWS_BATCH_SMOKE_JOB_QUEUE=osaf-batch-queue
#   export AWS_BATCH_SMOKE_JOB_DEFINITION=osaf-batch-runner
#   export AWS_BATCH_SMOKE_REGION=us-east-1        # optional (CLI default chain)
#   export AWS_BATCH_SMOKE_AWS_CMD='aws'           # optional (path to AWS CLI)
#   RAILS_ENV=local-test bundle exec rspec spec/features/aws_batch_smoke_spec.rb
#
# Credentials come from the standard AWS CLI chain on this machine; the Batch
# containers use their IAM task role (no keys leave your machine).
RSpec.describe 'AwsBatchSmoke', type: :feature do
  REQUIRED_ENV = %w(AWS_BATCH_SMOKE_BUCKET AWS_BATCH_SMOKE_JOB_QUEUE AWS_BATCH_SMOKE_JOB_DEFINITION).freeze
  SYNC_TIMEOUT_SECONDS = 30 * 60 # fleet scale-from-zero + image pull + sims

  # golden values from spec/features/docker_stack_algo_spec.rb (:lhs_discrete),
  # truncated to 2 decimals the same way that spec compares them
  GOLDEN_RESULTS = [
    { electricity_consumption_cvrmse: 38.01508752, electricity_consumption_nmbe: -38.93208252,
      natural_gas_consumption_cvrmse: 206.5584047, natural_gas_consumption_nmbe: -166.2205646 },
    { electricity_consumption_cvrmse: 37.63173269, electricity_consumption_nmbe: -38.54754034,
      natural_gas_consumption_cvrmse: 206.578935, natural_gas_consumption_nmbe: -166.233957 },
    { electricity_consumption_cvrmse: 37.63173269, electricity_consumption_nmbe: -38.54754034,
      natural_gas_consumption_cvrmse: 150.9769767, natural_gas_consumption_nmbe: -122.6180691 },
    { electricity_consumption_cvrmse: 37.7988, electricity_consumption_nmbe: -38.6516,
      natural_gas_consumption_cvrmse: 206.5584, natural_gas_consumption_nmbe: -166.2207 },
    { electricity_consumption_cvrmse: 37.4133, electricity_consumption_nmbe: -38.2671,
      natural_gas_consumption_cvrmse: 206.5789, natural_gas_consumption_nmbe: -166.2341 },
    { electricity_consumption_cvrmse: 37.4133, electricity_consumption_nmbe: -38.2671,
      natural_gas_consumption_cvrmse: 150.977, natural_gas_consumption_nmbe: -122.6182 }
  ].map { |h| h.transform_values { |v| v.truncate(2) } }.freeze

  ZERO_RESULTS = { electricity_consumption_cvrmse: 0, electricity_consumption_nmbe: 0,
                   natural_gas_consumption_cvrmse: 0, natural_gas_consumption_nmbe: 0 }.freeze

  before do
    missing = REQUIRED_ENV.reject { |v| ENV[v].to_s != '' }
    skip "AWS Batch smoke test skipped; set #{missing.join(', ')} to run it (see external_batch/aws/WALKTHROUGH.md)" if missing.any?

    begin
      Project.where(name: /aws batch smoke spec/).each(&:destroy)
      Variable.where(uuid: '').delete_all
      Delayed::Job.destroy_all
    rescue Errno::EACCES
      puts 'Cannot unlink files, will try and continue'
    end
  end

  def aws_cmd
    ENV['AWS_BATCH_SMOKE_AWS_CMD'].to_s == '' ? 'aws' : ENV['AWS_BATCH_SMOKE_AWS_CMD']
  end

  def region_args
    ENV['AWS_BATCH_SMOKE_REGION'].to_s == '' ? [] : ['--region', ENV['AWS_BATCH_SMOKE_REGION']]
  end

  def create_seb_discrete_analysis
    hash = JSON.parse(File.read(Rails.root.join('spec', 'files', 'SEB_LHS_2013_discrete.json')))
    # the OSA gem uploads with reset_uuids: true; replicate for direct seeding
    # (fixture workflow variables carry uuid: "", which collides on _id)
    hash['analysis']['problem']['workflow'].each do |wf|
      (wf['variables'] || []).each { |v| v['uuid'] = SecureRandom.uuid if v['uuid'].to_s.empty? }
    end

    project = Project.create(name: 'aws batch smoke spec')
    analysis = project.analyses.new(hash['analysis'])
    analysis.save!
    analysis.pull_out_os_variables
    analysis.seed_zip = File.new(Rails.root.join('spec', 'files', 'SEB_LHS_2013_discrete.zip'))
    analysis.problem['algorithm']['sampling_backend'] = 'ruby' # no Rserve needed
    analysis.save!
    analysis
  end

  it 'runs the SEB discrete LHS calibration analysis on AWS Batch and matches the golden results' do
    analysis = create_seb_discrete_analysis

    # sample with the Ruby LHS backend (inline)
    analysis.run_analysis(true, 'lhs', 'analysis_type' => 'lhs')
    analysis.reload
    expect(analysis.status_message.to_s).to eq ''
    data_points = analysis.data_points.where(status: 'na').to_a
    expect(data_points.size).to eq 3

    # package one chunk per datapoint -> a real array job
    ExternalBatch::Packager.new(analysis, data_points, dps_per_chunk: 1).package!
    data_points.each(&:set_queued_state)
    batch_dir = ExternalBatch.batch_dir(analysis.id)
    s3_uri = "s3://#{ENV['AWS_BATCH_SMOKE_BUCKET']}/runs/analysis_#{analysis.id}"
    repo_root = File.expand_path('..', Rails.root)

    # push the package + submit the array job
    submitted = system(RbConfig.ruby, File.join(repo_root, 'external_batch', 'aws', 'submit_batch.rb'),
                       batch_dir,
                       '--s3-uri', s3_uri,
                       '--job-queue', ENV['AWS_BATCH_SMOKE_JOB_QUEUE'],
                       '--job-definition', ENV['AWS_BATCH_SMOKE_JOB_DEFINITION'],
                       '--aws-cmd', aws_cmd,
                       *region_args)
    expect(submitted).to be(true), 'submit_batch.rb failed'

    # mirror results down until all chunks report done (bounded wait)
    sync_pid = Process.spawn(RbConfig.ruby, File.join(repo_root, 'external_batch', 'aws', 'sync_results.rb'),
                             batch_dir, '--s3-uri', s3_uri, '--interval', '30',
                             '--aws-cmd', aws_cmd, *region_args)
    begin
      Timeout.timeout(SYNC_TIMEOUT_SECONDS) { Process.wait(sync_pid) }
    rescue Timeout::Error
      Process.kill('KILL', sync_pid)
      raise "AWS Batch run did not complete within #{SYNC_TIMEOUT_SECONDS / 60} minutes; " \
            'check the job in the AWS console (Batch -> Jobs)'
    end
    expect($?.exitstatus).to eq 0

    # ingest and verify like the classic docker_stack lhs_discrete test
    ingester = ExternalBatch::Ingester.new(analysis)
    expect(ingester.executor_finished?(3)).to be true
    expect(ingester.ingest_new_results).to eq 3

    data_points.each do |dp|
      dp.reload
      expect(dp.status).to eq 'completed'
      expect(dp.status_message).to eq 'completed normal'
      expect(dp.result_files.map(&:display_name)).to include('objectives')

      results = dp.results.deep_symbolize_keys[:calibration_reports_enhanced_20]
      expect(results).not_to be_nil
      sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe,
                          :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
      # BSON::Document keeps string keys; normalize before comparing
      sim = sim.to_h.transform_keys(&:to_sym).transform_values { |x| x.truncate(2) }
      expect(sim.size).to eq 4
      puts "aws batch smoke dp #{dp.id}: #{sim}"
      expect(GOLDEN_RESULTS).to include(sim)
      expect(sim).not_to eq ZERO_RESULTS
    end
  end
end
