class Analysis::SequentialSearch < Struct.new(:analysis_id, :data_points, :options)

end

# Perform is the main method that is run in the background.  At the moment if this method crashes
# it will be logged as a failed delayed_job and will fail after max_attempts.
def perform
  def map_discrete_hash_to_array(discrete_values_and_weights)
    Rails.logger.info "received map discrete values with #{discrete_values_and_weights} with size #{discrete_values_and_weights.size}"
    ave_weight = (1.0 / discrete_values_and_weights.size)
    Rails.logger.info "average weight is #{ave_weight}"
    discrete_values_and_weights.each_index do |i|
      if !discrete_values_and_weights[i].has_key? 'weight'
        discrete_values_and_weights[i]['weight'] = ave_weight
      end
    end
    values = discrete_values_and_weights.map { |k| k['value'] }
    weights = discrete_values_and_weights.map { |k| k['weight'] }
    Rails.logger.info "Set values and weights to  #{values} with size #{weights}"

    [values, weights]
  end

  def determine_run_list(parameter_space)
    run_list = []
    @iteration ||= 0
    if @iteration == 0
      # no need to look at anything, just return the array
      isample = 0
      parameter_space.each do |id, sample|
        isample += 1
        dp_name = "Sequestion Search Iteration #{@iteration} Sample #{isample}"
        run_list << {name: dp_name, variables: sample[:variables], iteration: @iteration, sample: isample}
      end
    else
      (0..@iteration).each do |iteration|
        # Get the results for that iteration
        @analysis.where(iteration: iteration).data_points


      end
    end

    # have to figure out what to do

    @iteration += 1

    run_list
  end

  require 'rserve/simpler'
  require 'uuid'
  require 'childprocess'

  # get the analysis and report that it is running
  @analysis = Analysis.find(analysis_id)
  @analysis.status = 'started'
  @analysis.end_time = nil
  @analysis.run_flag = true
  @analysis.iteration = 0
  @iteration = @analysis.iteration

  # Set this if not defined in the JSON
  @analysis.problem['random_seed'] ||= 1979
  @analysis.save!

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
  parameter_space = {}
  measures = Measure.where({analysis_id: @analysis}).order_by(:name.asc) # order is not super important here becuase the analysis has has the order, right?
  measures.each do |measure|
    variables = measure.variables.where(perturbable: true)

    # mash the two variables together
    measure_values = {}
    variables.each do |variable|
      values, weights = map_discrete_hash_to_array(variable.discrete_values_and_weights)
      measure_values["#{variable._id}"] = values
    end
    Rails.logger.info "measure values with variables are #{measure_values}"
    # TODO, test the length of each measure value array
    measure_values = measure_values.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
    Rails.logger.info "measure values array hash is  #{measure_values}"

    measure_values.each do |mvs|
      parameter_space[UUID.new.generate] = {id: UUID.new.generate, measure_id: measure._id, variables: mvs}
    end
  end

  # The resulting parameter space is in the form of a hash with elements like the below
  # "9a1dbc60-1919-0131-be3d-080027880ca6"=>{:measure_id=>"e16805f0-a2f2-4122-828f-0812d49493dd",
  #   :variables=>{"8651b16d-91df-4dc3-a07b-048ea9510058"=>80, "c7cf9cfc-abf9-43b1-a07b-048ea9510058"=>"West"}}

  Rails.logger.info "Parameter space has #{parameter_space.count} and are #{parameter_space}"


  while true
    if run_list.empty? || @iteration == 1
      # must have converged?
    else
      run_list.each do |run|
        dp = @analysis.data_points.new(name: run[:name])
        dp['values'] = run[:variables]
        dp['iteration'] = run[:iteration]
        dp['sample'] = run[:sample]
        dp.save!
      end

      # So why does this work? It should hit run_analysis and it should come back as analysis is queued
      Rails.logger.info("kicking off simulations for iteration #{@iteration}")
      @analysis.start(true, 'batch_run', true)
      Rails.logger.info("finished simulations for iteration #{@iteration}... iterating")
    end


    run_list = determine_run_list(parameter_space)
  end

  Rails.logger.info("#{__FILE__} finished after iteration #{@iteration}")
  # Check the results of the run

  # Do one last check if there are any data points that were not downloaded
  @analysis.end_time = Time.now
  @analysis.status = 'completed'
  @analysis.save!
end

# Since this is a delayed job, if it crashes it will typically try multiple times.
# Fix this to 1 retry for now.
def max_attempts
  return 1
end

end

