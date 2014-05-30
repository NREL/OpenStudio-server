class Analysis::Preflight
  include Analysis::Core # pivots and static vars

  def initialize(analysis_id, options = {})
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
                sample_method: 'individual_variables',
                run_max: true,
                run_min: true,
                run_mode: true,
                run_all_samples_for_pivots: true
            }
        }
    }.with_indifferent_access # make sure to set this because the params object from rails is indifferential
    @options = defaults.deep_merge(options)

    @analysis_id = analysis_id
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    require 'rserve/simpler'
    require 'uuid'
    require 'childprocess'

    # get the analysis and report that it is running
    @analysis = Analysis.find(@analysis_id)
    @analysis.status = 'started'
    @analysis.end_time = nil
    @analysis.run_flag = true

    # add in the default problem/algorithm options into the analysis object
    # anything at at the root level of the options are not designed to override the database object.
    @analysis.problem = @options[:problem].deep_merge(@analysis.problem)

    # save other run information in another object in the analysis
    @analysis.run_options['preflight'] = @options.reject { |k, _| [:problem, :data_points, :output_variables].include?(k.to_sym) }

    # save all the changes into the database and reload the object (which is required)
    @analysis.save!
    @analysis.reload

    # Create an instance for R
    @r = Rserve::Simpler.new

    Rails.logger.info "Initializing analysis for #{@analysis.name} with UUID of #{@analysis.uuid}"
    Rails.logger.info "Setting up R for #{self.class.name}"
    # todo: need to move this to the module class
    @r.converse('setwd("/mnt/openstudio")')

    # make this a core method
    Rails.logger.info "Setting R base random seed to #{@analysis.problem['random_seed']}"
    @r.converse("set.seed(#{@analysis.problem['random_seed']})")

    pivot_array = Variable.pivot_array(@analysis.id)

    selected_variables = Variable.variables(@analysis.id)
    Rails.logger.info "Found #{selected_variables.count} variables to perturb"

    # generate the probabilities for all variables as column vectors
    @r.converse("print('starting preflight')")
    samples = nil
    var_types = nil


    Rails.logger.info 'Starting sampling'

    # Iterate through each variable based on the method and add to the samples array in the form of
    # [{a: 1, b: true, c: 's'}, {a: 2, b: false, c: 'n'}]
    samples = []

    if @analysis.problem['algorithm']['sample_method'] == 'individual_variables'
      Rails.logger.info "Sampling each variable individually"
      selected_variables.each do |variable|
        if @analysis.problem['algorithm']['run_min']
          instance = {}
          if variable.relation_to_output == 'inverse'
            instance["#{variable.id}".to_sym] = variable.maximum
          else
            instance["#{variable.id}".to_sym] = variable.minimum
          end

          selected_variables.each do |variable2|
            if variable != variable2
              instance["#{variable2.id}".to_sym] = variable2.static_value
            end
          end

          Rails.logger.info "Instance is #{instance}"
          samples << instance
        end

        if @analysis.problem['algorithm']['run_max']
          instance = {}
          if variable.relation_to_output == 'inverse'
            instance["#{variable.id}".to_sym] = variable.minimum
          else
            instance["#{variable.id}".to_sym] = variable.maximum
          end

          selected_variables.each do |variable2|
            if variable != variable2
              instance["#{variable2.id}".to_sym] = variable2.static_value
            end
          end

          Rails.logger.info "Instance is #{instance}"
          samples << instance
        end

        if @analysis.problem['algorithm']['run_mode']
          instance = {}
          instance["#{variable.id}".to_sym] = variable.modes_value

          selected_variables.each do |variable2|
            if variable != variable2
              instance["#{variable2.id}".to_sym] = variable2.static_value
            end
          end

          Rails.logger.info "Instance is #{instance}"
          samples << instance
        end
      end
    elsif @analysis.problem['algorithm']['sample_method'] == 'all_variables'
      Rails.logger.info 'Sampling for all variables'
      min_sample = {} # {:name => 'Minimum'}
      max_sample = {} # {:name => 'Maximim'}
      mode_sample = {}
      selected_variables.each do |variable|
        if variable.relation_to_output == 'inverse'
          min_sample["#{variable.id}"] = variable.maximum
          max_sample["#{variable.id}"] = variable.minimum
        else
          min_sample["#{variable.id}"] = variable.minimum
          max_sample["#{variable.id}"] = variable.maximum
        end
        mode_sample["#{variable.id}"] = variable.modes_value
      end

      Rails.logger.info "Minimum sample is: #{min_sample}"
      Rails.logger.info "Maximum sample is: #{max_sample}"
      Rails.logger.info "Mode sample is: #{mode_sample}"

      samples << min_sample if @analysis.problem['algorithm']['run_min']
      samples << max_sample if @analysis.problem['algorithm']['run_max']
      samples << mode_sample if @analysis.problem['algorithm']['run_mode']

    elsif @analysis.problem['algorithm']['sample_method'] == 'individual_measures'
      fail "this has been removed for now until it is needed. it is best to use individual variables"
      # # Individual Measures analysis takes each variable and groups them together by the measure ID.  This is
      # # useful when you need each measure to be evaluated individually.  The variables are then linked.
      # grouped = {min: {}, max: {}, mode: {}}
      # Rails.logger.info 'Sampling individual measures'
      # min_sample = {} # {:name => 'Minimum'}
      # max_sample = {} # {:name => 'Maximim'}
      # mode_sample = {}
      # selected_variables.each do |variable|
      #   grouped[:min]["#{variable.measure.id}"] = {} unless grouped[:min].key?(variable.measure.id)
      #   grouped[:max]["#{variable.measure.id}"] = {} unless grouped[:max].key?(variable.measure.id)
      #   grouped[:mode]["#{variable.measure.id}"] = {} unless grouped[:mode].key?(variable.measure.id)
      #
      #   if variable.relation_to_output == 'inverse'
      #     grouped[:min]["#{variable.measure.id}"]["#{variable.id}"] = variable.maximum
      #     grouped[:max]["#{variable.measure.id}"]["#{variable.id}"] = variable.minimum
      #   else
      #     grouped[:min]["#{variable.measure.id}"]["#{variable.id}"] = variable.minimum
      #     grouped[:max]["#{variable.measure.id}"]["#{variable.id}"] = variable.maximum
      #   end
      #   grouped[:mode]["#{variable.measure.id}"]["#{variable.id}"] = variable.modes_value
      # end
      #
      #
      # # Hash will look like this now:
      # # {
      # # {:min=>{"m_a"=>{"v_1"=>0.2161572052401747}, "m_b"=>{"v_2"=>0.21428571428571425, "v_3"=>0.56}}}
      # # }
      # # So add the min,max,mode values
      # samples += grouped[:min].map { |_, v| v }.flatten if @analysis.problem['algorithm']['run_min']
      # samples += grouped[:max].map { |_, v| v }.flatten if @analysis.problem['algorithm']['run_max']
      # samples += grouped[:mode].map { |_, v| v }.flatten if @analysis.problem['algorithm']['run_mode']
      # Rails.logger.info "Final grouped hash is: #{samples}"
    else
      fail 'no sampling method defined (all_variables or individual_variables)'
    end

    if @analysis.problem['algorithm']['run_all_samples_for_pivots']
      # Always add in the pivot variables for now.  This allows the location to be set if it is a pivot
      Rails.logger.info "Fixing Pivot dimension #{pivot_array}"
      samples = add_pivots(samples, pivot_array)
      Rails.logger.info "Finished adding the pivots resulting in #{samples}"
    else
      # only grab one of the pivots for now
      # todo: run all baselines, but only sample for the "default pivot"
    end

    # Add the data points to the database
    isample = 0
    samples.each do |sample| # do this in parallel
      isample += 1
      dp_name = "Autogenerated #{isample}"
      dp = @analysis.data_points.new(name: dp_name)
      dp.set_variable_values = sample
      dp.save!

      Rails.logger.info("Generated data point #{dp.name} for analysis #{@analysis.name}")
    end

    # Do one last check if there are any data points that were not downloaded
    @analysis.end_time = Time.now
    @analysis.status = 'completed'
    @analysis.save!
    @r.converse("print('finished preflight')")
    Rails.logger.info("Finished running #{self.class.name}")
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end
end
