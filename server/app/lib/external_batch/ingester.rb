# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Server-side (direct Mongoid) ingest of external batch results. Consumes the
# per-datapoint results directories the runner writes and applies the same
# DataPoint mutations DjJobs::RunSimulateDataPoint performs after a simulation:
# results from measure_attributes.json, sdp_log_file from run.log (truncated),
# result files (out.osw, reports, in.osm, data_point.zip, logs), status flags
# from the completed status, and start/end times from status.json.
module ExternalBatch
  class Ingester
    # keep in sync with DjJobs::RunSimulateDataPoint
    MAX_INLINE_SDP_LOG_BYTES = 5_000_000
    MAX_INLINE_SDP_LOG_LINES = 5_000

    def initialize(analysis, options = {})
      @analysis = analysis
      @logger = options[:logger] || Rails.logger
    end

    def results_dir
      ExternalBatch.results_dir(@analysis.id)
    end

    # Ingests every result directory whose datapoint is not yet completed.
    # A result directory is only considered once status.json exists (the runner
    # writes it last), so partially-written results are never picked up.
    # Idempotent; returns the number of datapoints ingested in this pass.
    def ingest_new_results
      return 0 unless Dir.exist? results_dir

      count = 0
      Dir.children(results_dir).sort.each do |entry|
        dir = File.join(results_dir, entry)
        next unless File.directory?(dir)
        next unless File.exist?(File.join(dir, 'status.json'))

        dp = @analysis.data_points.where(_id: entry).first
        unless dp
          @logger.warn "External batch results dir #{entry} does not match a datapoint of analysis #{@analysis.id}; skipping"
          next
        end
        next if dp.status == 'completed'

        ingest_data_point(dp, dir)
        count += 1
      end
      count
    end

    # True once every chunk has written its done marker.
    def executor_finished?(total_chunks)
      return false unless Dir.exist? results_dir

      (0...total_chunks).all? { |i| File.exist?(File.join(results_dir, "chunk_#{i}.done")) }
    end

    def ingest_data_point(dp, dir)
      @logger.info "Ingesting external batch results for datapoint #{dp.id} from #{dir}"
      status = JSON.parse(File.read(File.join(dir, 'status.json')))

      run_log = File.join(dir, 'run.log')
      dp.sdp_log_file = inline_log_lines(run_log) if File.exist?(run_log)

      results_file = File.join(dir, 'measure_attributes.json')
      if File.exist? results_file
        results = JSON.parse(File.read(results_file), symbolize_names: true)
        dp.update(results: results)
      else
        @logger.warn "Could not find results #{results_file}"
      end

      attach_result_files(dp, dir)
      attach_worker_logs(dp, dir)

      case status['completed_status']
      when 'Success'
        dp.set_success_flag
      when 'Invalid'
        dp.set_invalid_flag
      when 'Cancel'
        dp.set_cancel_flag
      else
        dp.set_error_flag
      end

      dp.run_start_time = parse_time(status['started_at'])
      dp.run_end_time = parse_time(status['completed_at']) || Time.now
      dp.status = :completed
      dp.save!
    rescue StandardError => e
      @logger.error "Failed to ingest results for datapoint #{dp.id}: #{e.message}, #{e.backtrace.join("\n")}"
      dp.set_error_flag
      dp.run_start_time ||= Time.now
      dp.run_end_time = Time.now
      dp.status = :completed
      dp.save!
    end

    private

    def parse_time(value)
      value.present? ? Time.parse(value) : nil
    rescue ArgumentError, TypeError
      nil
    end

    # Same file set + display names/types the worker uploads via POST /data_points/:id/upload_file
    def attach_result_files(dp, dir)
      attach(dp, File.join(dir, 'objectives.json'), 'Report', 'objectives')
      attach(dp, File.join(dir, 'out.osw'), 'Report', 'Final OSW File')
      attach(dp, File.join(dir, 'in.osm'), 'OpenStudio Model', 'model')
      attach(dp, File.join(dir, 'data_point.zip'), 'Data Point', 'Zip File')
      attach(dp, File.join(dir, 'dp.log'), 'Report', 'Datapoint Simulation Log')
      attach(dp, File.join(dir, 'datapoint_final.log'), 'Report', 'Finalization Script Log')

      Dir[File.join(dir, 'reports', '*.{html,json,csv,xml,mat}')].sort.each do |rep|
        attach(dp, rep, 'Report')
      end
    end

    # Mirrors data_points_controller#upload_file
    def attach(dp, path, type, display_name = nil)
      return unless File.exist?(path)

      display_name ||= File.basename(path, '.*')
      file = File.open(path, 'rb')
      begin
        rf = ResultFile.new(display_name: display_name, type: type)
        rf.attachment = file
        dp.result_files << rf
        dp.save!
      ensure
        file.close
      end
    end

    def attach_worker_logs(dp, dir)
      %w(initialize finalize).each do |script_name|
        log_path = File.join(dir, "#{script_name}.log")
        dp.worker_logs[script_name] = File.read(log_path).lines if File.exist?(log_path)
      end
    end

    # keep in sync with DjJobs::RunSimulateDataPoint#inline_log_lines
    def inline_log_lines(log_path)
      return [] if log_path.nil? || !File.exist?(log_path)

      log_size = File.size(log_path)
      lines = []
      truncated_by_lines = false

      File.open(log_path, 'rb') do |file|
        if log_size > MAX_INLINE_SDP_LOG_BYTES
          file.seek(-MAX_INLINE_SDP_LOG_BYTES, IO::SEEK_END)
          file.gets
        end

        all_lines = file.readlines
        truncated_by_lines = all_lines.length > MAX_INLINE_SDP_LOG_LINES
        lines = all_lines.last(MAX_INLINE_SDP_LOG_LINES).map do |line|
          line.encode('UTF-8', invalid: :replace, undef: :replace, replace: "�")
        end
      end

      truncated_by_bytes = log_size > MAX_INLINE_SDP_LOG_BYTES
      if truncated_by_bytes || truncated_by_lines
        note = "[OpenStudio Server truncated the inline datapoint log"
        note += " to the last #{MAX_INLINE_SDP_LOG_BYTES} bytes" if truncated_by_bytes
        note += " and #{MAX_INLINE_SDP_LOG_LINES} lines" if truncated_by_lines
        note += ". Download the Datapoint Simulation Log result file for the full output.]\n"
        lines.unshift(note)
      end

      lines
    rescue StandardError => e
      @logger.warn "Could not read inline datapoint log #{log_path}: #{e.message}"
      []
    end
  end
end
