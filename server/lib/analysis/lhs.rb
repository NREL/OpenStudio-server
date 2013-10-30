class Analysis::Lhs
  include Analysis::R::Lhs  # include the R Lhs wrapper

  def initialize(analysis_id, options = {})
    defaults = {skip_init: false}
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

    # get pivot variables
    pivot_variables = Variable.where({analysis_id: @analysis, pivot: true}).order_by(:name.asc)
    pivot_hash = {}
    pivot_variables.each do |var|
      Rails.logger.info "Mapping pivot #{var.name} with #{var.map_discrete_hash_to_array}"
      values, weights = var.map_discrete_hash_to_array
      Rails.logger.info "pivot variable values are #{values}"
      pivot_hash[var.uuid] = values
    end
    # multiple and smash the hash of arrays to form a array of hashes. This takes
    # {a: [1,2,3], b:[4,5,6]} to [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    pivot_array = pivot_hash.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
    Rails.logger.info "pivot array is #{pivot_array}"

    # get static variables.  These must be applied after the pivot vars and before the lhs
    static_variables = Variable.where({analysis_id: @analysis, static: true}).order_by(:name.asc)
    static_array = []
    static_variables.each do |var|
      if var.static_value
        static_array << {:"#{var.uuid}" => var.static_value}
      else
        raise "Asking to set a static value but none was passed #{var.name}"
      end
    end
    Rails.logger.info "static array is #{static_array}"

    # get variables / measures
    selected_variables = Variable.where({analysis_id: @analysis, perturbable: true}).order_by(:name.asc)
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
    # TODO: peformance smell... optimize this using Parallel
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

    Rails.logger.info "Samples are #{samples}"
    # multiple and smash the hash of arrays to form a array of hashes. This takes
    # {a: [1,2,3], b:[4,5,6]} to [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    samples = samples.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
    Rails.logger.info "Flipping samples around yields #{samples}"

    Rails.logger.info "Fixing Pivot dimension"
    # each pivot variable gets the same samples
    # take p = [{p1: 1}, {p1: 2}]
    # with s = [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    # make s' = [{p1: 1, a: 1, b: 4}, {p1: 2, a: 1, b: 4}, {p1: 1, a: 2, b: 5},  {p1: 2, a: 2, b: 5}]
    if pivot_array.size > 0
      new_samples = []
      pivot_array.each do |pv|
        samples.each do |sm|
          new_samples << pv.merge(sm)
        end
      end
      samples = new_samples
    end
    Rails.logger.info "Finished adding the pivots"

    # lastly add in any static variables
    if static_array.size > 0
      new_samples = []
      static_array.each do |st|
        samples.each do |sm|
          new_samples << sm.merge(st)
        end
      end
      samples = new_samples
    end
    Rails.logger.info "Samples after static_array #{samples}"

    isample = 0
    samples.each do |sample| # do this in parallel
                             # need to figure out how to map index to variable
      isample += 1
      dp_name = "LHS Autogenerated #{isample}"
      dp = @analysis.data_points.new(name: dp_name)
      dp.variable_values = sample
      dp.save!

      Rails.logger.info("Generated datapoint #{dp.name} for analysis #{@analysis.name}")
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

