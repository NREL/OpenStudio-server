class Analysis::SingleRun
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
        random_seed: 1979,
        algorithm: {
          number_of_samples: 1,
          sample_method: 'all_variables'
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
    @analysis.run_options['singlerun'] = @options.reject { |k, _| [:problem, :data_points, :output_variables].include?(k.to_sym) }

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
    @r.converse("print('starting singlerun')")
    samples = nil
    var_types = nil
    Rails.logger.info 'Starting sampling'
    #lhs = Analysis::R::Lhs.new(@r)

      #samples, var_types = lhs.sample_all_variables(selected_variables, @analysis.problem['algorithm']['number_of_samples'])

	  
      grouped = {}
      samples = {}
      var_types = []

      # get the probabilities
      Rails.logger.info "Found #{selected_variables.count} variables"

      i_var = 0
      selected_variables.each do |var|
        Rails.logger.info "sampling variable #{var.name} for measure #{var.measure.name}"
        variable_samples = nil
        # todo: would be nice to have a field that said whether or not the variable is to be discrete or continuous.
        if var.uncertainty_type == 'discrete_uncertain'
          Rails.logger.info("disrete vars for #{var.name} are #{var.discrete_values_and_weights}")
          variable_samples = var.static_value
          var_types << 'discrete'
        else
          variable_samples = var.static_value
          var_types << 'continuous'
        end

        # always add the data to the grouped hash even if it isn't used
        grouped["#{var.measure.id}"] = {} unless grouped.key?(var.measure.id)
        grouped["#{var.measure.id}"]["#{var.id}"] = variable_samples

        # save the samples to the
        samples["#{var.id}"] = variable_samples

        var.r_index = i_var + 1 # r_index is 1-based
        var.save!

        i_var += 1
      end
 
	  
        # Do the work to mash up the samples, pivots, and static variables before creating the data points
        Rails.logger.info "Samples are #{samples}"
        #samples = hash_of_array_to_array_of_hash(samples)
        Rails.logger.info "Flipping samples around yields #{samples}"

    #Rails.logger.info 'Fixing Pivot dimension'
    #samples = add_pivots(samples, pivot_array)
    #Rails.logger.info "Finished adding the pivots resulting in #{samples}"

    # Add the data points to the database
	#if samples.count > 0
    #  isample = 0
    #  samples.each do |sample| # do this in parallel
    #    isample += 1
    #    dp_name = "LHS Autogenerated #{isample}"
    #    dp = @analysis.data_points.new(name: dp_name)
    #    dp.set_variable_values = sample
    #    dp.save!

    #    Rails.logger.info("Generated data point #{dp.name} for analysis #{@analysis.name}")
    #  end
    #else
	    dp_name = "LHS Autogenerated 1"
        dp = @analysis.data_points.new(name: dp_name)
        dp.set_variable_values = samples
        dp.save!

        Rails.logger.info("Generated data point #{dp.name} for analysis #{@analysis.name}")
	#end
    # Do one last check if there are any data points that were not downloaded
    @analysis.end_time = Time.now
    @analysis.status = 'completed'
    @analysis.save!

    Rails.logger.info("Finished running #{self.class.name}")
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end
end
