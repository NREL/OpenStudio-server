# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'tmpdir'
require 'rbconfig'

# Package -> (external executor) -> ingest pipeline for external batch runs.
# The full-pipeline spec drives the real runner + local (mock) executor as
# subprocesses against a stub OpenStudio CLI, so the whole contract is covered
# without EnergyPlus.
RSpec.describe 'ExternalBatch', type: :model do
  include ExternalBatchHelpers

  around do |example|
    Dir.mktmpdir do |tmp|
      @batch_root = tmp
      # use native separators (backslashes on Windows) so the glob-safety
      # normalization in ExternalBatch.root_dir stays covered
      ENV['OS_SERVER_EXTERNAL_BATCH_ROOT'] = tmp.gsub('/', File::ALT_SEPARATOR || '/')
      begin
        example.run
      ensure
        ENV.delete('OS_SERVER_EXTERNAL_BATCH_ROOT')
      end
    end
  end

  before do
    begin
      Project.destroy_all
      Delayed::Job.destroy_all
    rescue Errno::EACCES
      puts 'Cannot unlink files, will try and continue'
    end
  end

  def bake_result(analysis, dp, completed_status: 'Success')
    dir = File.join(ExternalBatch.results_dir(analysis.id), dp.id.to_s)
    FileUtils.mkdir_p File.join(dir, 'reports')
    File.write(File.join(dir, 'run.log'), "line one\nline two\n")
    File.write(File.join(dir, 'measure_attributes.json'), JSON.pretty_generate(some_measure: { value: 42 }))
    File.write(File.join(dir, 'objectives.json'), '{}')
    File.write(File.join(dir, 'out.osw'), JSON.pretty_generate(completed_status: completed_status, steps: []))
    File.write(File.join(dir, 'reports', 'eplustbl.html'), '<html></html>')
    File.write(File.join(dir, 'data_point.zip'), 'PK stub')
    File.write(File.join(dir, 'status.json'), JSON.pretty_generate(
                                                schema_version: 1,
                                                analysis_id: analysis.id.to_s,
                                                data_point_id: dp.id.to_s,
                                                completed_status: completed_status,
                                                exit_status: completed_status == 'Success' ? 0 : 1,
                                                started_at: '2026-07-02T10:00:00Z',
                                                completed_at: '2026-07-02T10:05:00Z',
                                                hostname: 'spec-host'
                                              ))
    dir
  end

  describe ExternalBatch::Packager do
    it 'packages the analysis with a manifest, extracted zip, and pre-translated OSWs' do
      analysis, dps = create_fixture_analysis(num_dps: 3)
      packager = ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 2)
      pkg = packager.package!

      manifest = JSON.parse(File.read(ExternalBatch.manifest_path(analysis.id)))
      expect(manifest['schema_version']).to eq 1
      expect(manifest['analysis_id']).to eq analysis.id.to_s
      expect(manifest['data_point_count']).to eq 3
      expect(manifest['chunks'].size).to eq 2 # 2 + 1
      expect(manifest['chunks'].flatten).to match_array dps.map { |d| d.id.to_s }
      expect(manifest['run_workflow_timeout']).to eq analysis.run_workflow_timeout
      expect(manifest).to include('download_reports', 'download_osw', 'download_osm', 'download_zip')

      analysis_dir = File.join(pkg, "analysis_#{analysis.id}")
      expect(File).to exist(File.join(analysis_dir, 'analysis.json'))
      expect(Dir).to exist(File.join(analysis_dir, 'measures'))

      dps.each do |dp|
        dp_dir = File.join(analysis_dir, "data_point_#{dp.id}")
        expect(File).to exist(File.join(dp_dir, 'analysis.json'))

        dp_json = JSON.parse(File.read(File.join(dp_dir, 'data_point.json')))
        expect(dp_json['data_point']['_id']).to eq dp.id.to_s
        expect(dp_json['data_point']['set_variable_values_names']).not_to be_empty

        osw = JSON.parse(File.read(File.join(dp_dir, 'data_point.osw')))
        expect(osw['steps']).to be_a(Array)
        expect(osw['steps']).not_to be_empty
      end
    end

    it 'resolves variable names with one query for the whole package, not per datapoint entry' do
      analysis, dps = create_fixture_analysis(num_dps: 3)
      variables = Variable.where(analysis_id: analysis.id, perturbable: true).to_a

      expect(Variable).to receive(:where).once.and_call_original
      pkg = ExternalBatch::Packager.new(analysis, dps).package!

      dp = dps.first
      dp_json = JSON.parse(File.read(File.join(pkg, "analysis_#{analysis.id}", "data_point_#{dp.id}", 'data_point.json')))
      names = dp_json['data_point']['set_variable_values_names']
      expect(names.keys.sort).to eq variables.map(&:name).sort
      variables.each do |v|
        expect(names[v.name]).to eq(dp.set_variable_values[v.id.to_s]),
                                 "expected set_variable_values_names['#{v.name}'] to carry dp value"
      end
    end

    it 'refuses seed zip entries that escape the package directory (zip slip)' do
      analysis, dps = create_fixture_analysis(num_dps: 1)

      evil_zip = File.join(@batch_root, 'evil.zip')
      ::Zip::File.open(evil_zip, ::Zip::File::CREATE) do |zf|
        zf.get_output_stream('../../escaped.txt') { |f| f.write 'pwned' }
      end
      # close the handle explicitly or tmpdir cleanup fails on Windows (EACCES)
      File.open(evil_zip) do |zip_io|
        analysis.seed_zip = zip_io
        analysis.save!
      end

      expect { ExternalBatch::Packager.new(analysis, dps).package! }
        .to raise_error(/outside the package directory/)
      expect(File.exist?(File.join(ExternalBatch.batch_dir(analysis.id), 'escaped.txt'))).to be false
    end

    it 'refuses urbanopt and gemfile analyses and empty datapoint lists' do
      analysis, dps = create_fixture_analysis(num_dps: 1)

      analysis.urbanopt = true
      expect { ExternalBatch::Packager.new(analysis, dps).package! }.to raise_error(/UrbanOpt/)
      analysis.urbanopt = false

      analysis.gemfile = true
      expect { ExternalBatch::Packager.new(analysis, dps).package! }.to raise_error(/gemfile/)
      analysis.gemfile = false

      expect { ExternalBatch::Packager.new(analysis, []).package! }.to raise_error(/No datapoints/)
    end
  end

  describe ExternalBatch::Ingester do
    def barebones_analysis_with_dp
      project = Project.create(name: 'ingester spec')
      analysis = project.analyses.create(name: 'ingester spec analysis')
      dp = analysis.data_points.create!(name: 'ingest dp', status: 'queued')
      [analysis, dp]
    end

    it 'ingests a successful result into the datapoint' do
      analysis, dp = barebones_analysis_with_dp
      bake_result(analysis, dp)

      ingester = ExternalBatch::Ingester.new(analysis)
      expect(ingester.ingest_new_results).to eq 1

      dp.reload
      expect(dp.status).to eq 'completed'
      expect(dp.status_message).to eq 'completed normal'
      expect(dp.results['some_measure']['value']).to eq 42
      expect(dp.sdp_log_file.map(&:chomp)).to eq ['line one', 'line two']
      expect(dp.run_start_time).to eq Time.parse('2026-07-02T10:00:00Z')
      expect(dp.run_end_time).to eq Time.parse('2026-07-02T10:05:00Z')

      display_names = dp.result_files.map(&:display_name)
      expect(display_names).to include('Final OSW File', 'objectives', 'Zip File', 'eplustbl')
      zip = dp.result_files.detect { |rf| rf.display_name == 'Zip File' }
      expect(zip.type).to eq 'Data Point'
    end

    it 'ingests a failed result as a datapoint failure' do
      analysis, dp = barebones_analysis_with_dp
      bake_result(analysis, dp, completed_status: 'Fail')

      expect(ExternalBatch::Ingester.new(analysis).ingest_new_results).to eq 1
      dp.reload
      expect(dp.status).to eq 'completed'
      expect(dp.status_message).to eq 'datapoint failure'
    end

    it 'does not duplicate result files when re-ingesting after an interrupted pass' do
      analysis, dp = barebones_analysis_with_dp
      dir = bake_result(analysis, dp)

      # simulate a prior ingest killed mid-pass: one ResultFile was persisted
      # but the dp never reached status completed, so it gets ingested again
      File.open(File.join(dir, 'out.osw'), 'rb') do |f|
        rf = ResultFile.new(display_name: 'Final OSW File', type: 'Report')
        rf.attachment = f
        dp.result_files << rf
        dp.save!
      end

      expect(ExternalBatch::Ingester.new(analysis).ingest_new_results).to eq 1

      dp.reload
      expect(dp.status).to eq 'completed'
      names = dp.result_files.map(&:display_name)
      expect(names.count('Final OSW File')).to eq(1), "re-ingest must not duplicate attachments, got #{names.inspect}"
      expect(names).to include('objectives', 'Zip File', 'eplustbl')
    end

    it 'skips result dirs without status.json and is idempotent' do
      analysis, dp = barebones_analysis_with_dp
      partial = File.join(ExternalBatch.results_dir(analysis.id), dp.id.to_s)
      FileUtils.mkdir_p partial
      File.write(File.join(partial, 'run.log'), 'partial')

      ingester = ExternalBatch::Ingester.new(analysis)
      expect(ingester.ingest_new_results).to eq 0
      expect(dp.reload.status).to eq 'queued'

      File.write(File.join(partial, 'status.json'), JSON.generate(completed_status: 'Success'))
      expect(ingester.ingest_new_results).to eq 1
      expect(dp.reload.status).to eq 'completed'
      expect(ingester.ingest_new_results).to eq 0
    end

    it 'tracks executor completion through chunk done markers' do
      analysis, _dp = barebones_analysis_with_dp
      ingester = ExternalBatch::Ingester.new(analysis)
      FileUtils.mkdir_p ExternalBatch.results_dir(analysis.id)

      expect(ingester.executor_finished?(2)).to be false
      File.write(File.join(ExternalBatch.results_dir(analysis.id), 'chunk_0.done'), 't')
      expect(ingester.executor_finished?(2)).to be false
      File.write(File.join(ExternalBatch.results_dir(analysis.id), 'chunk_1.done'), 't')
      expect(ingester.executor_finished?(2)).to be true
    end
  end

  describe AnalysisLibrary::ExternalBatchRun do
    it 'packages, queues, ingests results, and completes the analysis job' do
      analysis, dps = create_fixture_analysis(num_dps: 2)
      # results are pre-baked so the wait loop completes on its first pass
      dps.each { |dp| bake_result(analysis, dp) }

      aj = analysis.jobs.new_job(analysis.id, 'external_batch_run', analysis.jobs.length, {})
      analysis.save!

      AnalysisLibrary::ExternalBatchRun.new(analysis.id, aj.id,
                                            analysis_type: 'external_batch_run',
                                            sleep_interval: 0, dps_per_chunk: 1).perform
      analysis.reload

      expect(analysis.status_message.to_s).to eq ''
      expect(File).to exist(ExternalBatch.manifest_path(analysis.id))
      dps.each do |dp|
        dp.reload
        expect(dp.status).to eq 'completed'
        expect(dp.status_message).to eq 'completed normal'
      end
      expect(analysis.jobs.last.status).to eq 'completed'
    end

    it 'marks datapoints errored when the executor finishes without returning results' do
      analysis, dps = create_fixture_analysis(num_dps: 2)
      # executor "finishes" both chunks but only returns results for the first dp
      bake_result(analysis, dps.first)
      FileUtils.mkdir_p ExternalBatch.results_dir(analysis.id)
      File.write(File.join(ExternalBatch.results_dir(analysis.id), 'chunk_0.done'), 't')
      File.write(File.join(ExternalBatch.results_dir(analysis.id), 'chunk_1.done'), 't')

      aj = analysis.jobs.new_job(analysis.id, 'external_batch_run', analysis.jobs.length, {})
      analysis.save!

      AnalysisLibrary::ExternalBatchRun.new(analysis.id, aj.id,
                                            analysis_type: 'external_batch_run',
                                            sleep_interval: 0, dps_per_chunk: 1).perform

      expect(dps[0].reload.status_message).to eq 'completed normal'
      expect(dps[1].reload.status).to eq 'completed'
      expect(dps[1].status_message).to eq 'datapoint failure'
    end
  end

  describe 'full pipeline: package -> local executor (stub CLI) -> ingest' do
    it 'completes every datapoint through the real runner and executor' do
      analysis, dps = create_fixture_analysis(num_dps: 2)
      ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 1).package!
      dps.each(&:set_queued_state)

      stub_cli = write_stub_openstudio(@batch_root)
      executor = File.expand_path('../external_batch/local_executor.rb', Rails.root)
      openstudio_cmd = "\"#{RbConfig.ruby}\" \"#{stub_cli}\""

      ok = system(RbConfig.ruby, executor,
                  ExternalBatch.batch_dir(analysis.id),
                  '--openstudio', openstudio_cmd,
                  '--parallel', '2')
      expect(ok).to be(true), 'local_executor.rb exited non-zero; see chunk logs in the batch results dir'

      ingester = ExternalBatch::Ingester.new(analysis)
      expect(ingester.executor_finished?(2)).to be true
      expect(ingester.ingest_new_results).to eq 2

      dps.each do |dp|
        dp.reload
        expect(dp.status).to eq 'completed'
        expect(dp.status_message).to eq 'completed normal'
        expect(dp.results['stub_measure']['ran']).to eq true
        expect(dp.result_files.map(&:display_name)).to include('Final OSW File', 'stub_report', 'model', 'Zip File')
      end
    end
  end
end
