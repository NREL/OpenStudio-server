class Analysis::Lhs
  include Analysis::R::Lhs # include the R Lhs wrapper
  include Analysis::Core # pivots and static vars

  def initialize(analysis_id, options = {})
    defaults = {
        skip_init: false,
        run_data_point_filename: "run_openstudio_workflow.rb"
    }
    @options = defaults.merge(options)
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

    # Set this if not defined in the JSON
    @analysis.problem['number_of_samples'] ||= 100
    @analysis.problem['random_seed'] ||= 1979
    @analysis.save!

    # Create an instance for R
    @r = Rserve::Simpler.new
    #lhs = Analysis::RWrapper::Lhs.new(@r)

    Rails.logger.info "Initializing analysis for #{@analysis.name} with UUID of #{@analysis.uuid}"
    Rails.logger.info "Setting up R for #{self.class.name}"
    #todo: need to move this to the module class
    @r.converse('setwd("/mnt/openstudio")')
    @r.converse("set.seed(#{@analysis.problem['random_seed']})")
    @r.converse "library(snow)"
    @r.converse "library(snowfall)"
    @r.converse "library(lhs)"
    @r.converse "library(triangle)"
    @r.converse "library(e1071)"

    # discretize the variables and save into hashes
    
    # get pivot variables
    pivot_variables = Variable.pivots(@analysis.id) 
    pivot_hash = {}
    pivot_variables.each do |var|
      Rails.logger.info "Adding variable '#{var.name}' to pivot list"
      Rails.logger.info "Mapping pivot #{var.name} with #{var.map_discrete_hash_to_array}"
      values, weights = var.map_discrete_hash_to_array
      Rails.logger.info "pivot variable values are #{values}"
      pivot_hash[var.uuid] = values
    end
    
    # if there are multiple pivots, then smash the hash of arrays to form a array of hashes. This takes
    # {a: [1,2,3], b:[4,5,6]} to [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    pivot_array = pivot_hash.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
    Rails.logger.info "pivot array is #{pivot_array}"

    # get static variables.  These must be applied after the pivot vars and before the lhs
    static_variables = Variable.statics(@analysis.id)
    static_array = []
    static_variables.each do |var|
      if var.static_value
        static_array << {"#{var.uuid}" => var.static_value}
      else
        raise "Asking to set a static value but none was passed for #{var.name}"
      end
    end
    Rails.logger.info "static array is #{static_array}"

    # get variables / measures
    selected_variables = Variable.variables(@analysis.id)
    Rails.logger.info "Found #{selected_variables.count} Variables to perturb"

    # generate the probabilities for all variables as column vectors
    @r.converse("print('starting lhs')")
    # get the probabilities and persist them for reference
    Rails.logger.info "Starting sampling"
    p = lhs_probability(selected_variables.count, @analysis.problem['number_of_samples'])
    Rails.logger.info "Probabilities #{p.class} with #{p.inspect}"

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.
    # For now, create a new variable_instance, create new datapoints, and add the instance reference
    i_var = 0
    samples = {} # samples are in hash of arrays
    # TODO: performance smell... optimize this using Parallel
    selected_variables.each do |var|
      sfp = nil
      if var.uncertainty_type == "discrete_uncertain"
        Rails.logger.info("disrete vars for #{var.name} are #{var.discrete_values_and_weights}")
        sfp = discrete_sample_from_probability(p[i_var], var, true)
      else
        sfp = samples_from_probability(p[i_var], var.uncertainty_type, var.modes_value, nil, var.lower_bounds_value, var.upper_bounds_value, true)
      end

      samples["#{var.id}"] = sfp[:r]
      if sfp[:image_path]
        pfi = PreflightImage.add_from_disk(var.id, "histogram", sfp[:image_path])
        var.preflight_images << pfi unless var.preflight_images.include?(pfi)
      end

      i_var += 1
    end

    # multiple and smash the hash of arrays to form a array of hashes. This takes
    # {a: [1,2,3], b:[4,5,6]} to [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    Rails.logger.info "Samples are #{samples}"
    samples = samples.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
    Rails.logger.info "Flipping samples around yields #{samples}"

    Rails.logger.info "Fixing Pivot dimension"
    samples = add_pivots(samples, pivot_array)
    Rails.logger.info "Finished adding the pivots resulting in #{samples}"


    Rails.logger.info "Adding in static variables"
    samples = add_static_variables(samples, static_array)
    Rails.logger.info "Samples after static_array #{samples}"

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

