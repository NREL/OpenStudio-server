class Analysis::SequentialSearch
  include Analysis::Core # pivots and static vars

  def initialize(analysis_id, options = {})
    defaults = {
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      create_data_point_filename: 'create_data_point.rb',
      output_variables: [
        {
          display_name: 'Total Site Energy (EUI)',
          name: 'total_energy',
          objective_function: true,
          objective_function_index: 0,
          index: 0
        },
        {
          display_name: 'Total Life Cycle Cost',
          name: 'total_life_cycle_cost',
          objective_function: true,
          objective_function_index: 1,
          index: 1
        }
        ],
      problem: {
        random_seed: 1979,
        algorithm: {
          number_of_samples: 10, # to discretize any continuous variables
          max_iterations: 1000,
          objective_functions: %w(total_energy total_life_cycle_cost)
            }
        }
    }.with_indifferent_access # make sure to set this because the params object from rails is indifferential
    @options = defaults.deep_merge(options)
    Rails.logger.info(@options)
    @analysis_id = analysis_id

    # Initialize some algorithm instance variables
    @iteration = 0
    @pareto = []
  end

  def self.create_data_point_list(parameter_space, run_list_ids, iteration, name_moniker = '')
    result = []

    i_sample = 0
    run_list_ids.each do |run_list|
      variables = {}
      i_sample += 1
      run_list.each do |ps_id|
        variables = variables.merge(parameter_space[ps_id][:variables])
      end
      name_moniker = 'Data Point' if name_moniker == ''
      name = "#{name_moniker} [iteration #{iteration} sample #{i_sample}]"
      result << { variable_group: run_list, name: name, variables: variables, iteration: iteration, sample: i_sample }
    end

    result
  end

  def self.mash_up_hash(selected, parameter_space)
    result_ids = []
    parameter_space.each do |ps_id, ps_sample|
      group_list = []
      # add on variables
      if selected.size == 0
        result_ids << [ps_id]
      else
        selected.each do |sel_id, sel_sample|
          if sel_sample[:measure_id] == ps_sample[:measure_id]
            Rails.logger.info "replacing in #{ps_id}"
            group_list << ps_id
          else
            Rails.logger.info "adding in #{ps_id} including #{sel_id}"
            group_list << ps_id << sel_id
          end
          Rails.logger.info group_list.inspect
        end
        new_run = group_list.sort.uniq
        Rails.logger.info "Determined a new ran combination of #{new_run}"
        result_ids << new_run

        # go back a step on the assigned variable?
      end
    end

    # delete myself eventually too--no need to process
    result_ids.uniq
  end

  def perform
    def determine_curve
      new_point_to_evaluate = false
      Rails.logger.info "Determine the Pareto Front for iteration #{@iteration}"
      Rails.logger.info "Current pareto front is: #{@pareto.map { |p| p.name }}"
      if @iteration == 0
        # just add the point to the pareto curve
        min_point = @analysis.data_points.where(iteration: 0).only(:results, :name, :variable_group_list, :uuid)
        if min_point.size == 0
          Rails.logger.info 'could not find the starting point'
        elsif min_point.size > 1
          Rails.logger.info 'found more than one datapoint for the initial iteration'
        else
          min_point = min_point.first
        end
        Rails.logger.info "Adding point to pareto front named '#{min_point.name}'"
        @pareto << min_point
        new_point_to_evaluate = true
      else
        Rails.logger.info 'Iterating over pareto front'
        i_pareto = -1
        orphaning = false
        new_curve = []
        @pareto.each do |pareto_point|
          i_pareto += 1
          new_point_to_evaluate = false
          Rails.logger.info "Pareto curve index #{i_pareto} of size #{@pareto.size}"

          # Skip the starting point when evaluating the curve
          if i_pareto == 0
            new_curve << pareto_point
          end

          # Initialize the variables to determine the next step
          min_point = nil
          slope = -Float::MAX

          # If we just iterating over every single datapoint, then there is no need for an index, other than
          # the analysis_id index on datapoints. TODO: move some of this logic to the database if we index right.
          dps = @analysis.data_points.where(:iteration.gt => 0).only(:results, :name, :variable_group_list, :uuid).order_by(:iteration.asc, :sample.asc) # don't look at the starting point
          dps.each do |dp|
            next if dp._id == pareto_point._id # don't evaluate the same point

            if dp.results && dp.results[@analysis.problem['algorithm']['objective_functions'][0]] && dp.results[@analysis.problem['algorithm']['objective_functions'][1]]
              x = dp.results[@analysis.problem['algorithm']['objective_functions'][0]]
              y = dp.results[@analysis.problem['algorithm']['objective_functions'][1]]

              # check for infinite slope
              temp_slope = nil
              if (x - pareto_point.results[@analysis.problem['algorithm']['objective_functions'][0]]) == 0
                # check if this has the same value, if so, then don't add#
                # todo: this should really cause a derivative analysis to kick off that would
                # then use this point as a potential path as well.
                if y == pareto_point.results[@analysis.problem['algorithm']['objective_functions'][1]]
                  temp_slope = -Float::MAX
                else
                  temp_slope = Float::MAX
                end
              else
                if x < pareto_point.results[@analysis.problem['algorithm']['objective_functions'][0]]
                  temp_slope = (y - pareto_point.results[@analysis.problem['algorithm']['objective_functions'][1]]) /
                      (x - pareto_point.results[@analysis.problem['algorithm']['objective_functions'][0]])
                else
                  temp_slope = -Float::MAX # set this to an invalid point to consider
                end
              end

              Rails.logger.info "Name: '#{dp.name}' Slope: '#{temp_slope}'"
              if temp_slope > slope
                Rails.logger.info "Better point found for datapoint #{dp.name} with slope #{temp_slope}"
                slope = temp_slope
                min_point = dp
              elsif temp_slope == slope
                # Rails.logger.info "Datapoint has same slope as previous point #{dp.name} with slope #{temp_slope}"
              else
                # Rails.logger.info "Slope was lower for #{dp.name} with slope #{temp_slope}"
              end
            end
          end

          # check if the result was the same point, or had the same values
          if min_point
            if i_pareto == (@pareto.size - 1)
              Rails.logger.info "At the end of the pareto array but found a new point, adding #{min_point.name}"
              new_curve << min_point
              new_point_to_evaluate = true
            elsif min_point == @pareto[i_pareto + 1]
              Rails.logger.info 'Pareto search found the same point or values'
              new_curve << min_point # just add in the same point to the new curve
            elsif min_point.results[@analysis.problem['algorithm']['objective_functions'][0]] ==
                @pareto[i_pareto + 1].results[@analysis.problem['algorithm']['objective_functions'][0]] \
                && min_point.results[@analysis.problem['algorithm']['objective_functions'][1]] ==
                @pareto[i_pareto + 1].results[@analysis.problem['algorithm']['objective_functions'][1]]
              Rails.logger.info 'Found the same objective function values in array, skipping'
                                     # new_curve << min_point # just add in the same point to the new curve
            else
              # the min point is new and was found before the end of the array.  Orphaning the other points
              Rails.logger.info "Orphaning previous point in array.  Replacing #{@pareto[i_pareto + 1].name} with #{min_point.name}"
              new_curve << min_point
              new_point_to_evaluate = true
              orphaning = true
              break
            end
          end

          if orphaning
            Rails.logger.info 'Breaking out of loop because of ophan request'
            break
          end
        end

        @pareto = new_curve
      end
      Rails.logger.info "Final pareto front is: #{@pareto.map { |p| p.name }}"

      new_point_to_evaluate
    end

    # need to reduce this to a call without the database
    def determine_run_list(parameter_space)
      data_point_list = []
      Rails.logger.info "Determining run list for iteration #{@iteration}"
      if @iteration == 0
        # run the baseline
        Rails.logger.info 'setting up to run just the starting point'
        data_point_list << { variable_group: [], name: 'Starting Point', variables: {}, iteration: @iteration, sample: 1 }
        # elsif @iteration == 1
        #  # no need to look at anything, just return the array
        #  run_list = Analysis::SequentialSearch.mash_up_hash([], parameter_space)
        #  data_point_list = Analysis::SequentialSearch.create_data_point_list(parameter_space, run_list, 1)
      else
        last_dp = @pareto.last
        if last_dp
          variable_group_list = last_dp['variable_group_list']
          # get the full ps information
          Rails.logger.info("Last pareto front point was #{last_dp.name} with parameter space index #{variable_group_list}")
          full_variable_group_list = parameter_space.select { |k, v| v if variable_group_list.include?(k) }

          # Fix the previous variable groups in the next run
          run_list = Analysis::SequentialSearch.mash_up_hash(full_variable_group_list, parameter_space)
          data_point_list = Analysis::SequentialSearch.create_data_point_list(parameter_space, run_list, @iteration)
        else
          Rails.logger.info('Could not find last point on pareto front')
        end
      end

      # go through each of the run list results and delete any that have already run
      data_point_list.reverse.each do |dp|
        if @analysis.data_points.where(set_variable_values: dp[:variables]).exists?
          Rails.logger.info("Datapoint has already run for #{dp[:name]}")
          data_point_list.delete(dp)
        end
      end

      data_point_list
    end

    require 'rserve/simpler'
    require 'uuid'
    require 'childprocess'

    Rails.logger.info("list of options were #{@options}")

    # get the analysis and report that it is running
    @analysis = Analysis.find(@analysis_id)
    @analysis.status = 'started'
    @analysis.end_time = nil
    @analysis.run_flag = true

    # add in the default problem/algorithm options into the analysis object
    # anything at at the root level of the options are not designed to override the database object.
    @analysis.problem = @options[:problem].deep_merge(@analysis.problem)

    # merge in the output variables and objective functions into the analysis object which are needed for problem execution
    @options[:output_variables].reverse.each { |v| @analysis.output_variables.unshift(v) unless @analysis.output_variables.include?(v) }
    @analysis.output_variables.uniq!

    # verify that the objective_functions are unique
    @analysis.problem['algorithm']['objective_functions'].uniq! if @analysis.problem['algorithm']['objective_functions']

    # save other run information in another object in the analysis
    @analysis.run_options['sequential_search'] = @options.reject { |k, _| [:problem, :data_points, :output_variables].include?(k.to_sym) }

    # some algorithm specific data to be stored in the database
    @analysis['iteration'] = @iteration

    # save the data
    @analysis.save!
    @analysis.reload # after saving the data (needed for some reason yet to be determined)

    # get static variables.  These must be applied after the pivot vars and before the lhs
    pivot_array = Variable.pivot_array(@analysis.id)
    selected_variables = Variable.variables(@analysis.id)

    if pivot_array.size > 1
      Rails.logger.warn 'Pivot arrays are not implemented in sequential search at the moment. Any pivot values will be ignored'
    end

    # Create an instance for R
    @r = Rserve::Simpler.new

    # setup an LHS instance for sampling the continuous variables
    lhs = Analysis::R::Lhs.new(@r)

    # the sequential search operates on measures so get variables / measures
    parameter_space = {}
    measures = Measure.where(analysis_id: @analysis).order_by(:name.asc) # order is not super important here because the analysis has has the order, right?
    measures.each do |measure|
      variables = measure.variables.where(perturbable: true)

      # mash the two variables together if there are more than 1 variable in a measure. This is a simple combinatorial
      measure_values = {}
      variables.each do |variable|
        values = nil
        if variable['uncertainty_type'] =~ /discrete_uncertain/ # not sure what to do with bool_uncertain at the moment
          values, weights = variable.map_discrete_hash_to_array
        else
          # if the variable is continuous then discretize it before running. Pass in as an array of 1 because it
          # expects all variables but we are pinning it to discretize the variables one-by-one.
          values, var_types = lhs.sample_all_variables([variable], @analysis.problem['algorithm']['number_of_samples'])
        end

        # Return the values as an array which requires returning the values portion of the hash then flatten to remove
        # the outer array.
        measure_values["#{variable._id}"] = values.values.flatten
      end
      Rails.logger.info "measure values with variables are #{measure_values}"
      # TODO, test the length of each measure value array
      measure_values = measure_values.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
      Rails.logger.info "measure values array hash is  #{measure_values}"

      measure_values.each do |mvs|
        parameter_space[UUID.new.generate] = { measure_id: measure._id, variables: mvs }
      end
    end
    Rails.logger.info "Parameter space has #{parameter_space.count} and are #{parameter_space}"

    # determine the first list of items to run
    final_message = ''
    @run_list = determine_run_list(parameter_space)
    Rails.logger.info "datapoint list is #{@run_list}"
    new_pareto_point = true
    while (!@run_list.empty?) || (new_pareto_point)
      @run_list.each do |run|
        dp = @analysis.data_points.new(name: run[:name])
        dp['variable_group_list'] = run[:variable_group]
        dp.set_variable_values = run[:variables]
        dp['iteration'] = run[:iteration]
        dp['sample'] = run[:sample]
        if dp.save!
        else
          fail "Could not save datapoint #{dp.errors}"
        end
        Rails.logger.info "Added new datapoint #{dp.name}"
      end
      @analysis.save!

      Rails.logger.info("Kicking off simulations for iteration #{@iteration}")
      @analysis.start(true, 'batch_run', skip_init: true, run_data_point_filename: 'run_openstudio_workflow.rb')
      Rails.logger.info("Finished simulations for iteration #{@iteration}... checking results")
      new_pareto_point = determine_curve
      Rails.logger.info("Determined pareto curve for #{@iteration} and new point flag is set to #{new_pareto_point}")
      Rails.logger.info("Finished simulations for iteration #{@iteration}... iterating")

      if @iteration >= @options[:problem][:algorithm][:max_iterations]
        final_message = "Reached max iterations of #{@analysis.problem['algorithm']['max_iterations']}"
        break
      end

      @run_list = determine_run_list(parameter_space)
      @iteration += 1
    end

    # todo: finish of the pareto front so that it includes all the points to the end

    Rails.logger.info("#{__FILE__} finished after iteration #{@iteration} with message '#{final_message}'")
    # Check the results of the run

    # Only set this data if the analysis was NOT called from another analysis
    unless @options[:skip_init]
      @analysis.end_time = Time.now
      @analysis.status = 'completed'
    end

    @analysis.save!

    Rails.logger.info "Finished running analysis '#{self.class.name}'"
  end

# Since this is a delayed job, if it crashes it will typically try multiple times.
# Fix this to 1 retry for now.
  def max_attempts
    1
  end
end
