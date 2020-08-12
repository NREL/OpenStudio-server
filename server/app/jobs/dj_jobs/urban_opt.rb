module DjJobs
  module UrbanOpt
    require 'zip'
    def run_urbanopt(uo_simulation_log, uo_process_log)
      #copy over files
      FileUtils.mkdir_p "#{simulation_dir}/urbanopt"
      FileUtils.cp_r "#{analysis_dir}/lib/urbanopt/.", "#{simulation_dir}/urbanopt"
      #FileUtils.mkdir_p "#{simulation_dir}/urbanopt/.bundle/install/ruby"
      #FileUtils.cp_r "#{simulation_dir}/urbanopt/ruby/.", "#{simulation_dir}/urbanopt/.bundle/install/ruby"
      ##FileUtils.rm_rf "#{simulation_dir}/urbanopt/ruby/"
      #first = "BUNDLE_PATH: \"#{analysis_dir}/lib/urbanopt/\""
      #second = "BUNDLE_PATH: \"#{simulation_dir}/urbanopt/.bundle/install/\""
      #config_file = "#{simulation_dir}/urbanopt/.bundle/config"
      #@sim_logger.info ".bundle/config: #{File.read(config_file)}"
      #File.write("#{simulation_dir}/urbanopt/.bundle/config",File.open("#{simulation_dir}/urbanopt/.bundle/config",&:read).gsub(first,second))
      #@sim_logger.info ".bundle/config: #{File.read(config_file)}"
      #moved to initialize_worker
      #bundle install
      bundle_count = 0
      bundle_max_count = 10
      begin
        #bundle install 
        cmd = "cd #{simulation_dir}/urbanopt; bundle install --path=#{simulation_dir}/urbanopt/.bundle/install --gemfile=#{simulation_dir}/urbanopt/Gemfile --retry 10"
        uo_bundle_log = File.join(simulation_dir, 'urbanopt_bundle.log')
        @sim_logger.info "Installing UrbanOpt bundle using cmd #{cmd} and writing log to #{uo_bundle_log}"
        pid = Process.spawn(cmd, [:err, :out] => [uo_bundle_log, 'w'])
        Timeout.timeout(600) do
          bundle_count += 1              
          Process.wait(pid)
        end              
      rescue StandardError => e
        sleep Random.new.rand(1.0..10.0)
      retry if bundle_count < bundle_max_count
        raise "Could not bundle UrbanOpt after #{bundle_max_count} attempts. Failed with message #{e.message}."
      ensure
        uo_log("urbanopt_bundle") if @data_point.analysis.urbanopt
      end

      variables = {}
      @data_point['set_variable_values'].each_with_index do |(k, v), i|  #loop over all variables
        var = Variable.find(k)
        if var
          @sim_logger.info "var: #{var.to_json}"
          variables.merge!(var[:uo_measure] => { :name=>var[:name], :value=>v, :mapper=>var[:mapper] })  #dont actuall use variable just yet
          @sim_logger.info "variables: #{variables.to_json}"
                 
          #check if mapper file exist
          mapper_file = "#{simulation_dir}/urbanopt/mappers/#{var[:mapper]}.rb"
          if !File.exist?(mapper_file)
            raise "mapper_file does not exist: #{mapper_file}"
          end
          mapper = File.open("#{mapper_file}",&:read) #loop over each line in the mapper and look for the variable and replace value
          mapper.each_line { |line|
            #variable_names.each do |variable_name|
              variable_name = var[:name]
              #@sim_logger.info "variable_name: #{variable_name}"
              if line.include? variable_name
                variable_value = v
                @sim_logger.info "found variable name: #{variable_name} with variable value: #{variable_value}"
                #This does a gsub regex on "'uo_measure', 'variable_name', xx.xx)" and replaces with "'uo_measure', 'variable_name', variable_value)" and then writes file
                keyword = ["'#{var[:uo_measure]}', '#{variable_name}'"]
                File.write("#{mapper_file}",File.open("#{mapper_file}",&:read).gsub(/(?:#{ Regexp.union(keyword).source }),\s\d+(?:\.\d*)?/, "'#{var[:uo_measure]}', '#{variable_name}', #{variable_value}"))
              end
            #end #variable_names.each
          }
          
        end #if var
      end #@data_point do

      #check if feature_file and scenario_file exist
      feature_file = "#{simulation_dir}/urbanopt/#{@data_point.analysis.feature_file}.json"
      if !File.exist?(feature_file)
        raise "feature_file does not exist: #{feature_file}"
      end
      scenario_file = "#{simulation_dir}/urbanopt/#{@data_point.analysis.scenario_file}.csv"
      if !File.exist?(scenario_file)
        raise "scenario_file does not exist: #{scenario_file}"
      end
      #run uo-cli            
      cmd = "uo run --feature #{feature_file} --scenario #{scenario_file}"
      #uo_simulation_log = File.join(simulation_dir, 'urbanopt_simulation.log')
      @sim_logger.info "Running UrbanOpt workflow using cmd #{cmd} and writing log to #{uo_simulation_log}"
      pid = Process.spawn(cmd, [:err, :out] => [uo_simulation_log, 'w'])
      Timeout.timeout(28800) do 
        Process.wait(pid)
      end

      if $?.exitstatus != 0
        raise "UrbanOpt run returned error code #{$?.exitstatus}"
      end

      #run uo-cli process           
      cmd = "uo process --default --feature #{feature_file} --scenario #{scenario_file}"
      #uo_process_log = File.join(simulation_dir, 'urbanopt_process.log')
      @sim_logger.info "Running UrbanOpt workflow using cmd #{cmd} and writing log to #{uo_process_log}"
      pid = Process.spawn(cmd, [:err, :out] => [uo_process_log, 'w'])
      Timeout.timeout(28800) do 
        Process.wait(pid)
      end

      if $?.exitstatus != 0
        raise "UrbanOpt process returned error code #{$?.exitstatus}"
      end
      #Run OSSCLI --postprocess_only to run reporting measures in UrbanOpt workflow if ReportingMeasure's are present in workflow
      @sim_logger.info "@data_point.analysis.problem['workflow'].empty?: #{@data_point.analysis.problem['workflow'].empty?}"
      @sim_logger.info "@data_point.analysis.problem['workflow']: #{@data_point.analysis.problem['workflow']}"
      @sim_logger.info "@data_point.analysis.problem['workflow'].all?{|h| h['measure_type'] == 'ReportingMeasure'}: #{@data_point.analysis.problem['workflow'].all?{|h| h['measure_type'] == 'ReportingMeasure'}}"
      if !@data_point.analysis.problem['workflow'].empty? && @data_point.analysis.problem['workflow'].all?{|h| h['measure_type'] == 'ReportingMeasure'}            
        cmd = "#{Utility::Oss.oscli_cmd(@sim_logger)} #{@data_point.analysis.cli_verbose} run --postprocess_only --workflow '#{osw_path}' #{@data_point.analysis.cli_debug}"
        process_log = File.join(simulation_dir, 'oscli_postprocess_only.log')
        @sim_logger.info "Running postprocess_only workflow using cmd #{cmd} and writing log to #{process_log}"
        oscli_env_unset = Hash[Utility::Oss::ENV_VARS_TO_UNSET_FOR_OSCLI.collect{|x| [x,nil]}]
        pid = Process.spawn(oscli_env_unset, cmd, [:err, :out] => [process_log, 'w'])
        # add check for a valid timeout value
        unless @data_point.analysis.run_workflow_timeout.positive?
          @sim_logger.warn "run_workflow_timeout option: #{@data_point.analysis.run_workflow_timeout} is not valid.  Using 28800s instead."
          @@data_point.analysis.run_workflow_timeout = 28800
        end
        Timeout.timeout(@data_point.analysis.run_workflow_timeout) do
          Process.wait(pid)
        end

        if $?.exitstatus != 0
          raise "Oscli postprocess_only returned error code #{$?.exitstatus}"
        end
      else  #no reporting measures so hand make outputs

        results = {}
        objective_functions = {}
        @sim_logger.info 'Iterating over Output Variables for UrbanOpt'
          # UO output looks like:
          #feature_reports: [
          #    {
          #    id: "1",
          #        reporting_periods: [
          #          natural_gas: 74195446.43594739,
          #          end_uses: {}
          #        ]
          #    },
          #]
          #uo_results[:feature_reports][0][:reporting_periods][0][:natural_gas]
          #
          # Save the objective functions
        if @data_point.analysis.output_variables
          @data_point.analysis.output_variables.each do |variable|
            uo_result = {}
            report_index = nil
            if variable[:objective_function]
              @sim_logger.info "found variable[:objective_function]: #{variable[:objective_function]}"
              if variable[:report] == 'feature_reports'
                @sim_logger.info "found variable[:report]: #{variable[:report]}"
                if variable[:report_id] && variable[:reporting_periods] && variable[:var_name]
                  @sim_logger.info "found variable[:report_id]:#{variable[:report_id]}, variable[:reporting_periods]:#{variable[:reporting_periods]}, variable[:var_name]: #{variable[:var_name]}."
                  #get feature_reports results
                  uo_results_file = "#{simulation_dir}/urbanopt/run/#{@data_point.analysis.scenario_file}/default_scenario_report.json"
                  if File.exist? uo_results_file
                    uo_result = JSON.parse(File.read(uo_results_file), symbolize_names: true)
                    report_index = uo_result[variable[:report].to_sym].index {|h| h[:id] == variable[:report_id].to_s } if uo_result[variable[:report].to_sym]
                    if report_index && !uo_result[variable[:report].to_sym][report_index][:reporting_periods][variable[:reporting_periods]].nil? #feature_reports index and reporting_periods exist
                      if  uo_result[variable[:report].to_sym][report_index][:reporting_periods][variable[:reporting_periods]].has_key?(variable[:var_name].to_sym) #reporting_periods has var_name?
                      #check for end_uses
                        if variable[:var_name] == "end_uses" #check end_uses and category exist
                          if variable[:end_use] && variable[:end_use_category] && uo_result[variable[:report].to_sym][report_index][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym].has_key?(variable[:end_use].to_sym)
                            if variable[:end_use] && variable[:end_use_category] && uo_result[variable[:report].to_sym][report_index][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym][variable[:end_use].to_sym].has_key?(variable[:end_use_category].to_sym)
                              results[variable[:name].split(".")[0]] = { "#{variable[:end_use]}_#{variable[:end_use_category]}".to_sym => uo_result[variable[:report].to_sym][report_index][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym][variable[:end_use].to_sym][variable[:end_use_category].to_sym], "applicable" => true }
                            else
                              raise "MISSING output variable[:end_use_category]:#{variable[:end_use_category]}, when output variable[:var_name]:#{variable[:var_name]}, output variable[:end_use]:#{variable[:end_use]}"
                            end
                          else
                            raise "MISSING output variable[:end_use]:#{variable[:end_use]}, when output variable[:var_name]:#{variable[:var_name]}"
                          end
                        else  #not end_uses
                          results[variable[:name].split(".")[0]] = { variable[:var_name].to_sym => uo_result[variable[:report].to_sym][report_index][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym], "applicable" => true }
                        end
                      else
                        raise "Could not find output variable[:var_name]: #{variable[:var_name]} in reporting period: #{variable[:reporting_periods]}."
                      end
                    else
                      raise "Could not find output reporting period: #{variable[:reporting_periods]}."
                    end
                  else
                    raise "Could not find results #{uo_results_file}"
                  end
                else
                  raise "MISSING output variable[:report_id]:#{variable[:report_id]}, variable[:reporting_periods]:#{variable[:reporting_periods]}, variable[:var_name]: #{variable[:var_name]}."
                end
              elsif variable[:report] == 'scenario_report'
                @sim_logger.info "found variable[:report]: #{variable[:report]}"
                if variable[:reporting_periods] && variable[:var_name]
                  @sim_logger.info "found variable[:reporting_periods]:#{variable[:reporting_periods]}, variable[:var_name]: #{variable[:var_name]}."
                  #get feature_reports results
                  uo_results_file = "#{simulation_dir}/urbanopt/run/#{@data_point.analysis.scenario_file}/default_scenario_report.json"
                  if File.exist? uo_results_file
                    uo_result = JSON.parse(File.read(uo_results_file), symbolize_names: true)
                    if !uo_result[variable[:report].to_sym][:reporting_periods][variable[:reporting_periods]].nil? #reporting_periods exist
                      if uo_result[variable[:report].to_sym][:reporting_periods][variable[:reporting_periods]].has_key?(variable[:var_name].to_sym) #reporting_periods has var_name?
                      #check for end_uses
                        if variable[:var_name] == "end_uses"
                          if variable[:end_use] && variable[:end_use_category] && uo_result[variable[:report].to_sym][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym].has_key?(variable[:end_use].to_sym)
                            if variable[:end_use] && variable[:end_use_category] && uo_result[variable[:report].to_sym][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym][variable[:end_use].to_sym].has_key?(variable[:end_use_category].to_sym)
                              results[variable[:name].split(".")[0]] = { "#{variable[:end_use]}_#{variable[:end_use_category]}".to_sym => uo_result[variable[:report].to_sym][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym][variable[:end_use].to_sym][variable[:end_use_category].to_sym], "applicable" => true }
                            else
                              raise "MISSING output variable[:end_use_category]:#{variable[:end_use_category]}, when output variable[:var_name]:#{variable[:var_name]}, output variable[:end_use]:#{variable[:end_use]}"
                            end
                          else
                            raise "MISSING output variable[:end_use]:#{variable[:end_use]}, when output variable[:var_name]:#{variable[:var_name]}"
                          end
                        else #not end_uses
                          results[variable[:name].split(".")[0]] = { variable[:var_name].to_sym => uo_result[variable[:report].to_sym][:reporting_periods][variable[:reporting_periods]][variable[:var_name].to_sym], "applicable" => true }
                        end
                      else
                        raise "Could not find output variable[:var_name]: #{variable[:var_name]} in reporting period: #{variable[:reporting_periods]}."  
                      end
                    else
                      raise "Could not find output reporting period: #{variable[:reporting_periods]}."
                    end
                  else
                    raise "Could not find results #{uo_results_file}"
                  end
                else
                  raise "MISSING output variable[:reporting_periods]:#{variable[:reporting_periods]}, variable[:var_name]: #{variable[:var_name]}."
                end
              else
                raise "output variable '#{variable[:name]}' :report is not scenario_report or feature_reports.  :report = '#{variable[:report]}'."
              end


              @sim_logger.info "Looking in output variable #{variable[:name]} for objective function [#{variable[:report]}][#{variable[:report_id]}]{#{variable[:reporting_periods]}}[#{variable[:var_name]}]"

              # look for the objective function key and make sure that it is not nil. False is an okay obj function.
              # check if "#{variable[:end_use]}_#{variable[:end_use_category]}" == variable[:name] somewhere??  -BLB
              # results = {:"ffce3f6b-023a-46ab-89f2-4f8c692719dd"=>{:electricity=>39869197.34679705, :applicable=>true},:'uuid'...}
              if !results[variable[:name].split(".")[0]].nil? && !results[variable[:name].split(".")[0]][variable[:name].split(".")[1].to_sym].nil?
                #objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = results[variable[:name].split(".")[0]][variable[:var_name].to_sym]  #no end_uses
                objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = results[variable[:name].split(".")[0]][variable[:name].split(".")[1].to_sym]  #end_uses_end_use_category
                if variable[:objective_function_target]
                  @sim_logger.info "Found objective function target for #{variable[:name]}"
                  objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_target].to_f
                end
                if variable[:scaling_factor]
                  @sim_logger.info "Found scaling factor for #{variable[:name]}"
                  objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = variable[:scaling_factor].to_f
                end
                if variable[:objective_function_group]
                  @sim_logger.info "Found objective function group for #{variable[:name]}"
                  objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_group].to_f
                end
              else
                #make raise an option to continue with failures??
                raise "No results for objective function #{variable[:name]}"
                @sim_logger.error "No results for objective function #{variable[:name]} in #{__FILE__} at #{__LINE__}"
                objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = Float::MAX
                objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = nil
                objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = nil
                objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = nil
              end
            end
          end
        end

        @sim_logger.info 'Saving the objectives to file'
        File.open("#{run_dir}/objectives.json", 'w') do |f|
          f << JSON.pretty_generate(objective_functions)
          # make sure data is written to the disk one way or the other
          begin
            f.fsync
          rescue StandardError
            f.flush
          end
        end
        @sim_logger.info 'Saving the result hash to file'
        File.open("#{run_dir}/results.json", 'w') do |f|
          f << JSON.pretty_generate(results)
          # make sure data is written to the disk one way or the other
          begin
            f.fsync
          rescue StandardError
            f.flush
          end
        end
        @sim_logger.info 'Saving the result hash to measure_attributes.json file'
        File.open("#{run_dir}/measure_attributes.json", 'w') do |f|
          f << JSON.pretty_generate(results)
          # make sure data is written to the disk one way or the other
          begin
            f.fsync
          rescue StandardError
            f.flush
          end
        end

        #copy results to "#{simulation_dir}/urbanopt/run/reports/*"

        reports_dir = "#{simulation_dir}/urbanopt/run/reports/"
        @sim_logger.info "Moving #{simulation_dir}/urbanopt/run/#{@data_point.analysis.scenario_file}/*.{html,json,csv} to #{reports_dir}"
        FileUtils.mkdir_p reports_dir unless Dir.exist? reports_dir
        Dir["#{simulation_dir}/urbanopt/run/#{@data_point.analysis.scenario_file}/*.{html,json,csv}"].each { |file| FileUtils.cp(file, reports_dir) }
        
        #zip reports
        @sim_logger.info "zipping up: #{simulation_dir}/urbanopt/run"
        zf = ZipFileGenerator.new("#{simulation_dir}/urbanopt/run", "#{simulation_dir}/urbanopt/run/data_point.zip")
        zf.write
        zf = ZipFileGenerator.new("#{simulation_dir}/urbanopt/run/reports", "#{simulation_dir}/urbanopt/run/data_point_reports.zip")
        zf.write
        @sim_logger.info "moving zips to #{run_dir}"
        FileUtils.mv Dir.glob("#{simulation_dir}/urbanopt/run/*.zip"), "#{run_dir}", force: true 
        
        #TODO make out.osw with UO run status (for UO only workflow)
        out_osw = { completed_status: 'Success',
                    current_step: 0,
                    osa_id: @data_point.analysis.id,
                    osd_id: @data_point.id,
                    name: @data_point.name,
                    started_at: ::DateTime.now.iso8601,
                    steps: [],
                    completed_at: ::DateTime.now.iso8601,                            
                    updated_at: ::DateTime.now.iso8601
                  }
        report_file = "#{simulation_dir}/out.osw"
        if !File.exist? report_file
          File.open(report_file, 'w') { |f| f << JSON.pretty_generate(JSON.parse(out_osw.to_json)) }
        end

      end #end UO cli --postprocess_only  
    end

  class ZipFileGenerator
  # Initialize with the directory to zip and the location of the output archive.
  def initialize(input_dir, output_file)
    @input_dir = input_dir
    @output_file = output_file
  end

  # Zip the input directory.
  def write
    entries = Dir.entries(@input_dir) - %w[. ..]

    ::Zip::File.open(@output_file, ::Zip::File::CREATE) do |zipfile|
      write_entries entries, '', zipfile
    end
  end

  private

  # A helper method to make the recursion work.
  def write_entries(entries, path, zipfile)
    entries.each do |e|
      zipfile_path = path == '' ? e : File.join(path, e)
      disk_file_path = File.join(@input_dir, zipfile_path)

      if File.directory? disk_file_path
        recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
      else
        put_into_archive(disk_file_path, zipfile, zipfile_path)
      end
    end
  end

  def recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
    zipfile.mkdir zipfile_path
    subdir = Dir.entries(disk_file_path) - %w[. ..]
    write_entries subdir, zipfile_path, zipfile
  end

  def put_into_archive(disk_file_path, zipfile, zipfile_path)
    zipfile.add(zipfile_path, disk_file_path)
  end
end
end

end