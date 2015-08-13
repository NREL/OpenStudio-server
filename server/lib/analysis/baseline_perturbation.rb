class Analysis::BaselinePerturbation
  include Analysis::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    # Setup the defaults for the Analysis.  Items in the root are typically used to control the running of
    #   the script below and are not necessarily persisted to the database.
    #   Options under problem will be merged together and persisted into the database.  The order of
    #   preference is objects in the database, objects passed via options, then the defaults below.
    #   Parameters posted in the API become the options hash that is passed into this initializer.
    defaults = {
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      problem: {
        random_seed: 1298,
        algorithm: {
          in_measure_combinations: 'false',
          include_baseline_in_combinations: 'false'
        }
      }
    }.with_indifferent_access # make sure to set this because the params object from rails is indifferential
    @options = defaults.deep_merge(options)

    @analysis_id = analysis_id
    @analysis_job_id = analysis_job_id
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = Analysis::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    # Create an instance for R
    @r = Rserve::Simpler.new
    begin
      Rails.logger.info "Initializing analysis for #{@analysis.name} with UUID of #{@analysis.uuid}"
      Rails.logger.info "Setting up R for #{self.class.name}"
      # TODO: need to move this to the module class
      @r.converse('setwd("/mnt/openstudio")')

      # pivot_array = Variable.pivot_array(@analysis.id)

      Rails.logger.info "#{Variable.variables(@analysis.id)}"

      selected_variables = Variable.variables(@analysis.id)
      Rails.logger.info "Found #{selected_variables.count} variables to perturb"

      # generate the probabilities for all variables as column vectors
      @r.converse("print('starting single perturbation')")
      samples = nil

      Rails.logger.info 'Starting sampling'

      # Iterate through each variable based on the method and add to the samples array in the form of
      # [{a: 1, b: true, c: 's'}, {a: 2, b: false, c: 'n'}]
      samples = []

      selected_variables.each do |var|
        Rails.logger.info "name: #{var.measure.name}; id: #{var.measure.id}"
      end

      # Make baseline case
      instance = {}
      selected_variables.each do |variable|
        instance["#{variable.id}".to_sym] = variable.static_value
      end
      samples << instance

      # Make perturbed cases
      if @analysis.problem['algorithm']['in_measure_combinations'].downcase == 'false'
        Rails.logger.info 'In False'
        selected_variables.each do |variable|
          if variable.map_discrete_hash_to_array.nil? || variable.discrete_values_and_weights.empty?
            fail 'no hash values and weight passed'
          end
          values, weights = variable.map_discrete_hash_to_array
          values.each do |val|
            instance = {}
            instance["#{variable.id}".to_sym] = val
            selected_variables.each do |variable2|
              if variable != variable2
                instance["#{variable2.id}".to_sym] = variable2.static_value
              end
            end
            samples << instance
          end
        end
      elsif @analysis.problem['algorithm']['in_measure_combinations'].downcase == 'true'
        Rails.logger.info 'In True'
        measure_list = []
        selected_variables.each do |var|
          measure_list << var.measure.id unless measure_list.include? var.measure.id
        end
        measure_list.each do |meas|
          meas_var_val = {}
          meas_var = []
          meas_var_num = []
          selected_variables.each do |var|
            if var.measure.id == meas
              values, weights = var.map_discrete_hash_to_array
              if @analysis.problem['algorithm']['include_baseline_in_combinations'].downcase == 'true'
                values << var.static_value
              end
              meas_var_val["#{var.id}"] = values
              meas_var << var.id
              meas_var_num << [0..(values.length - 1)][0].to_a
            end
          end
          # Rails.logger.info "meas_var_num: #{meas_var_num}; meas_var_val: #{meas_var_val}; meas_var: #{meas_var}"
          combinations = meas_var_num.first.product(*meas_var_num[1..-1])
          combinations.each do |combination|
            instance = {}
            combination.each_with_index do |value_ind, var_ind|
              instance["#{meas_var[var_ind]}".to_sym] = meas_var_val[meas_var[var_ind]][value_ind]
            end
            selected_variables.each do |var|
              instance["#{var.id}".to_sym] = var.static_value unless meas_var.include? var.id
            end
            # Rails.logger.info "instance: #{instance}"
            sleep 1
            samples << instance
          end
        end
      else
        fail "Algorithm variable 'in_measure_combinations' was not set to valid values 'true' or 'false', instead '#{@analysis.problem['algorithm']['in_measure_combinations'].downcase}'"
      end
      # Add the data points to the database
      isample = 0
      samples.uniq.each do |sample| # do this in parallel
        isample += 1
        dp_name = "Autogenerated #{isample}"
        dp = @analysis.data_points.new(name: dp_name)
        dp.set_variable_values = sample
        dp.save!

        Rails.logger.info("Generated data point #{dp.name} for analysis #{@analysis.name}")
      end

    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      Rails.logger.info log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        @analysis_job.end_time = Time.now
        @analysis_job.status = 'completed'
        @analysis_job.save!
        @analysis.reload
      end
      @analysis.save!
      Rails.logger.info "Finished running analysis '#{self.class.name}'"
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end
end
