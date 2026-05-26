# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module DjJobs
  ProcessBulkUpload = Struct.new(:zip_path, :project_id) do
    def perform
      require 'tmpdir'
      require 'zip'

      @project = Project.find(project_id)
      if @project.nil?
        Rails.logger.error "Project not found for bulk upload processing: #{project_id}"
        return
      end

      Dir.mktmpdir do |temp_dir|
        begin
          Zip::File.open(zip_path) do |zip_file|
            zip_file.each do |entry|
              next if entry.directory?
              next unless entry.name.end_with?('.zip')

              inner_zip_path = File.join(temp_dir, entry.name)
              entry.extract(inner_zip_path)

              inner_temp_dir = File.join(temp_dir, "inner_#{File.basename(entry.name, '.zip')}")
              Dir.mkdir(inner_temp_dir)
              
              analysis_json_path = File.join(inner_temp_dir, 'analysis.json')
              Zip::File.open(inner_zip_path) do |inner_zip|
                json_entry = inner_zip.find_entry('analysis.json')
                if json_entry
                  json_entry.extract(analysis_json_path)
                else
                  raise "analysis.json not found in #{entry.name}"
                end
              end

              formulation_json = JSON.parse(File.read(analysis_json_path))
              analysis_attrs = formulation_json['analysis']
              raise "Invalid formulation in #{entry.name}" if analysis_attrs.nil?

              analysis_attrs['project_id'] = @project.id
              analysis_attrs['uuid'] = SecureRandom.uuid unless analysis_attrs['uuid']

              analysis = Analysis.new(analysis_attrs)
              file_to_upload = File.open(inner_zip_path)
              analysis.seed_zip = file_to_upload

              if analysis.save!
                analysis.pull_out_os_variables
                analysis.pull_out_urbanopt_variables if analysis.urbanopt
                analysis.save!

                analysis_type = analysis_attrs['problem'] && analysis_attrs['problem']['analysis_type']
                analysis_type ||= 'batch_run'

                options = {
                  'simulate_data_point_filename' => 'simulate_data_point.rb',
                  'run_data_point_filename' => 'run_openstudio_workflow_monthly.rb',
                  'analysis_type' => analysis_type
                }
                analysis.run_analysis(false, analysis_type, options)

                batch_run_methods = ['lhs', 'preflight', 'single_run', 'repeat_run', 'doe', 'diag', 'baseline_perturbation', 'batch_datapoints']
                if batch_run_methods.include?(analysis_type)
                  options['analysis_type'] = 'batch_run'
                  analysis.run_analysis(false, 'batch_run', options)
                end
              end
            end
          end
        rescue => e
          Rails.logger.error "Error processing bulk zip in background: #{e.message}\n#{e.backtrace.join("\n")}"
        ensure
          FileUtils.rm_f(zip_path) rescue nil
        end
      end
    end

    def queue_name
      'analyses'
    end
  end
end
