# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Builds the self-contained package an external executor needs to run an
# analysis's datapoints without any server/DB access. The layout inside the
# package mirrors the worker layout in DjJobs::RunSimulateDataPoint so the
# pre-translated OSWs (with their ../measures, ../weather, ../seeds relative
# paths) resolve unchanged:
#
#   package/
#     manifest.json
#     analysis_<id>/
#       analysis.json
#       measures/ seeds/ weather/ lib/ scripts/   (extracted analysis zip)
#       data_point_<dp_id>/
#         analysis.json
#         data_point.json
#         data_point.osw
module ExternalBatch
  class Packager
    DEFAULT_DPS_PER_CHUNK = 50

    def initialize(analysis, data_points, options = {})
      @analysis = analysis
      @data_points = Array(data_points)
      @dps_per_chunk = (options[:dps_per_chunk] || ENV['OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK'] || DEFAULT_DPS_PER_CHUNK).to_i
      @dps_per_chunk = DEFAULT_DPS_PER_CHUNK if @dps_per_chunk <= 0
      @logger = options[:logger] || Rails.logger
    end

    def package_dir
      ExternalBatch.package_dir(@analysis.id)
    end

    def analysis_pkg_dir
      File.join(package_dir, "analysis_#{@analysis.id}")
    end

    # Builds the package from scratch (idempotent: an existing package is replaced,
    # the results directory is left alone). Returns the package directory.
    def package!
      raise 'UrbanOpt analyses are not supported by external batch execution' if @analysis.urbanopt
      raise 'Analyses with a custom gemfile are not supported by external batch execution' if @analysis.gemfile
      raise 'No datapoints to package' if @data_points.empty?

      FileUtils.rm_rf package_dir
      FileUtils.mkdir_p analysis_pkg_dir
      FileUtils.mkdir_p ExternalBatch.results_dir(@analysis.id)

      extract_seed_zip
      write_analysis_json
      @data_points.each { |dp| package_data_point(dp) }
      write_manifest

      @logger.info "External batch package for analysis #{@analysis.id} written to #{package_dir}"
      package_dir
    end

    def chunks
      @data_points.map { |dp| dp.id.to_s }.each_slice(@dps_per_chunk).to_a
    end

    private

    # Same source as GET /analyses/:id/download_analysis_zip; extraction mirrors
    # the worker's extract_archive (skip existing entries).
    def extract_seed_zip
      zip_path = @analysis.seed_zip&.path
      raise "Analysis #{@analysis.id} has no seed zip attached" if zip_path.nil? || !File.exist?(zip_path)

      ::Zip.sort_entries = true
      ::Zip::File.open(zip_path) do |zf|
        zf.each do |f|
          f_path = File.join(analysis_pkg_dir, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zf.extract(f, f_path) unless File.exist?(f_path)
        end
      end
    end

    # Same document the worker downloads from GET /analyses/:id.json
    # (analyses_controller#show renders { analysis: @analysis }, and
    # Translator::Workflow reads the :analysis key)
    def write_analysis_json
      File.open(File.join(analysis_pkg_dir, 'analysis.json'), 'w') do |f|
        f << JSON.pretty_generate(JSON.parse({ analysis: @analysis }.to_json))
      end
    end

    # Same document the worker downloads from GET /data_points/:id.json
    # (see data_points_controller#show json format)
    def data_point_json(dp)
      h = dp.as_json
      h['set_variable_values_names'] = {}
      h['set_variable_values_display_names'] = {}
      (h['set_variable_values'] || {}).each do |k, v|
        var = Variable.where(_id: k).first
        next unless var

        h['set_variable_values_names'][var.name] = v
        h['set_variable_values_display_names'][var.display_name] = v
      end
      { data_point: h }
    end

    # Pre-translates the OSW server-side; this is the Translator::Workflow call from
    # DjJobs::RunSimulateDataPoint#perform moved to package time, with identical options.
    def package_data_point(dp)
      dp_dir = File.join(analysis_pkg_dir, "data_point_#{dp.id}")
      FileUtils.mkdir_p dp_dir

      File.open("#{dp_dir}/data_point.json", 'w') { |f| f << JSON.pretty_generate(JSON.parse(data_point_json(dp).to_json)) }
      FileUtils.cp File.join(analysis_pkg_dir, 'analysis.json'), "#{dp_dir}/analysis.json"

      # PAT puts seeds in "seeds" folder (not "seed")
      osw_options = {
        file_paths: ['../weather', '../seeds', '../seed'],
        measure_paths: ['../measures']
      }
      if dp.seed
        osw_options[:seed] = dp.seed unless dp.seed == ''
      end
      if dp.da_descriptions
        osw_options[:da_descriptions] = dp.da_descriptions unless dp.da_descriptions == []
      end
      if dp.weather_file
        osw_options[:weather_file] = dp.weather_file unless dp.weather_file == ''
      end

      t = OpenStudio::Analysis::Translator::Workflow.new("#{dp_dir}/analysis.json", osw_options)
      t_result = t.process_datapoint("#{dp_dir}/data_point.json")
      raise "Could not translate OSA, OSD into OSW for datapoint #{dp.id}" unless t_result

      File.open("#{dp_dir}/data_point.osw", 'w') { |f| f << JSON.pretty_generate(t_result) }
      @logger.info "Packaged datapoint #{dp.id}"
    end

    def write_manifest
      manifest = {
        schema_version: ExternalBatch::SCHEMA_VERSION,
        analysis_id: @analysis.id.to_s,
        analysis_name: @analysis.name,
        created_at: Time.now.iso8601,
        data_point_count: @data_points.size,
        chunks: chunks,
        run_workflow_timeout: @analysis.run_workflow_timeout,
        cli_verbose: @analysis.cli_verbose,
        cli_debug: @analysis.cli_debug,
        download_reports: @analysis.download_reports,
        download_osw: @analysis.download_osw,
        download_osm: @analysis.download_osm,
        download_zip: @analysis.download_zip
      }
      File.open(ExternalBatch.manifest_path(@analysis.id), 'w') { |f| f << JSON.pretty_generate(manifest) }
    end
  end
end
