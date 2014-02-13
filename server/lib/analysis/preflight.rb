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
        run_data_point_filename: "run_openstudio_workflow.rb",
        problem: {
            random_seed: 1298,
            algorithm: {
                sample_method: 'individual_measures',
                run_max: true,
                run_min: true,
                run_mode: true,
                run_starting_point: true
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

    # save all the changes into the database and reload the object (which is required)
    @analysis.save!
    @analysis.reload

    # Create an instance for R
    @r = Rserve::Simpler.new

    Rails.logger.info "Initializing analysis for #{@analysis.name} with UUID of #{@analysis.uuid}"
    Rails.logger.info "Setting up R for #{self.class.name}"
    #todo: need to move this to the module class
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
    static_array = nil

    Rails.logger.info "Starting sampling"

    # Iterate through each variable based on the method and add to the samples array in the form of
    # [{a: 1, b: true, c: 's'}, {a: 2, b: false, c: 'n'}]
    samples = []

    if @analysis.problem['algorithm']['sample_method'] == "individual_variables"
      selected_variables.each do |variable|
        if variable.relation_to_output == "inverse"
          samples << {"#{variable.id}" => variable.maximum} if @analysis.problem['algorithm']['run_min']
          samples << {"#{variable.id}" => variable.minimum} if @analysis.problem['algorithm']['run_max']
        else # including the empty string case
          samples << {"#{variable.id}" => variable.minimum} if @analysis.problem['algorithm']['run_min']
          samples << {"#{variable.id}" => variable.maximum} if @analysis.problem['algorithm']['run_max']
        end
        samples << {"#{variable.id}" => variable.modes_value} if @analysis.problem['algorithm']['run_mode']
      end

      # Add in the static array (which are set in each sample)
      static_array = Variable.static_array(@analysis.id)
      samples = add_static_variables(samples, static_array)
    elsif @analysis.problem['algorithm']['sample_method'] == "all_variables"
      Rails.logger.info "Sampling for all variables"
      min_sample = {} #{:name => 'Minimum'}
      max_sample = {} #{:name => 'Maximim'}
      mode_sample = {}
      selected_variables.each do |variable|
        if variable.relation_to_output == "inverse"
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

      # Add in the static array (which are set in each sample)
      static_array = Variable.static_array(@analysis.id)
      samples = add_static_variables(samples, static_array)
    elsif @analysis.problem['algorithm']['sample_method'] == "individual_measures"
      # Individual Measures analysis takes each variable and groups them together by the measure ID.  This is 
      # useful when you need each measure to be evaluated individually.  The variables are then linked.
     
      
      #  static_array_grouped = Variable.static_array(@analysis.id, true)
      #  samples_grouped, var_types = lhs.sample_all_variables(selected_variables, @analysis.problem['algorithm']['number_of_samples'], true)
      #  samples = grouped_hash_of_array_to_array_of_hash(samples_grouped, static_array_grouped)
      #  Rails.logger.info "Grouped samples are #{samples}"
      #  else

      #end 
    else
      raise "no sampling method defined (all_variables or individual_variables)"
    end
    
    # add in the starting point if requested.  Note that the static variables are not added to the 
    # starting point.
    samples << {} if @analysis.problem['algorithm']['run_starting_point']

    # Always add in the pivot variables for now.  This allows the location to be set if it is a 
    # pivot
    Rails.logger.info "Fixing Pivot dimension"
    samples = add_pivots(samples, pivot_array)
    Rails.logger.info "Finished adding the pivots resulting in #{samples}"


    # Add the data points to the database
    isample = 0
    samples.each do |sample| # do this in parallel
      isample += 1
      dp_name = "LHS Autogenerated #{isample}"
      dp = @analysis.data_points.new(name: dp_name)
      dp.set_variable_values = sample
      dp.save!

      Rails.logger.info("Generated data point #{dp.name} for analysis #{@analysis.name}")
    end

    # Do one last check if there are any data points that were not downloaded
    @analysis.end_time = Time.now
    @analysis.status = 'completed'
    @analysis.save!

    Rails.logger.info("Finished running #{self.class.name}")
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    return 1
  end
end

