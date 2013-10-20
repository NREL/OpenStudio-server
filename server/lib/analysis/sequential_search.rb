class Analysis::SequentialSearch
  def initialize(analysis_id, options = {})
    defaults = {skip_init: false, x_objective_function: "total_energy", y_objective_function: "interior_lighting_electricity"}
    @options = defaults.merge(options)

    @analysis_id = analysis_id
    @iteration = 0
  end

# Perform is the main method that is run in the background.  At the moment if this method crashes
# it will be logged as a failed delayed_job and will fail after max_attempts.
  def self.create_data_point_list(parameter_space, run_list_ids, iteration, name_moniker = "")
    result = []

    i_sample = 0
    run_list_ids.each do |run_list|
      variables = {}
      i_sample += 1
      run_list.each do |ps_id|
        variables = variables.merge(parameter_space[ps_id][:variables])
      end
      name_moniker = "Data Point" if name_moniker == ""
      name = "#{name_moniker} [iteration #{iteration} sample #{i_sample}]"
      result << {variable_group: run_list, name: name, variables: variables, iteration: iteration, sample: i_sample}
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
    # need to reduce this to a call without the database
    def determine_run_list(parameter_space)
      data_point_list = []
      Rails.logger.info "Determining run list for iteration #{@iteration}"
      if @iteration == 0
        # run the baseline
        Rails.logger.info "setting up to run just the starting point"
        data_point_list << {variable_group: [], name: "Starting Point", variables: {}, iteration: @iteration, sample: 1}
      elsif @iteration == 1
        # no need to look at anything, just return the array
        run_list = Analysis::SequentialSearch.mash_up_hash([], parameter_space)
        data_point_list = Analysis::SequentialSearch.create_data_point_list(parameter_space, run_list, 1)
      else
        pareto = []
        (0..@iteration).each do |iteration|
          if iteration == 0
            # only one starting point for now, just set the value into the pareto list
            min_point = @analysis.data_points.where(iteration: 0).only(:results, :name, :variable_group_list, :uuid)
            if min_point.size == 0
              Rails.logger.info "could not find the starting point"
            elsif min_point.size > 1
              Rails.logger.info "found more than one datapoint for the initial iteration"
            else
              min_point = min_point.first
            end
            Rails.logger.info "Using starting point named '#{min_point.name}'"
          else
            prev_min_point = pareto.last
            puts "Previous min point was #{prev_min_point.name}"

            # Initialize the variables to determine the next step
            min_x = nil
            min_y = nil
            min_point = nil
            slope = Float::MAX

            # If we just iterate over every single datapoint, then there is no need for an index, other than
            # the analysis_id index on datapoints. TODO: move some of this logic to the database if we index right.
            dps = @analysis.data_points.all.only(:results, :name, :variable_group_list, :uuid)
            dps.each do |dp|
              if dp.results && dp.results[@analysis['x_objective_function']] && dp.results[@analysis['y_objective_function']]
                x = dp.results[@analysis['x_objective_function']]
                y = dp.results[@analysis['y_objective_function']]
                Rails.logger.info "Evaluating datapoint #{dp.name} with x: #{x} y: #{y}"

                # check for infinite slope (negative)
                temp_slope = nil
                if (x - prev_min_point.results[@analysis['y_objective_function']])
                  temp_slope = Float::MIN
                else
                  temp_slope = (y - prev_min_point.results[@analysis['y_objective_function']]) / (x - prev_min_point.results[@analysis['x_objective_function']])
                end

                if temp_slope < slope
                  Rails.logger.info "Better point found for datapoint #{dp.name} with slope #{temp_slope}"
                  slope = temp_slope
                  min_point = dp
                elsif temp_slope == slope
                  Rails.logger.info "Datapoint has same slope as previous point #{dp.name}"
                else
                  Rails.logger.info "Slope was higher for #{dp.name}"
                end

                min_point = dp if min_point
                Rails.logger.info "datapoint #{dp.name} was added to the pareto list"
              end
            end

            # Now check for increasing y_objective_functions

          end
          pareto << min_point
        end

        last_dp = pareto.last
        if last_dp
          variable_group_list = last_dp['variable_group_list']
          # get the full ps information
          Rails.logger.info("Last pareto front point was #{last_dp.name} with parameter space index #{variable_group_list}")
          full_variable_group_list = parameter_space.select { |k, v| v if variable_group_list.include?(k) }

          # Fix the previous variable groups in the next run
          run_list = Analysis::SequentialSearch.mash_up_hash(full_variable_group_list, parameter_space)
          data_point_list = Analysis::SequentialSearch.create_data_point_list(parameter_space, run_list, @iteration)
        else
          # end this with a message that no point found on pareto front
        end
      end

      # go through each of the run list results and delete any that have already run
      data_point_list.reverse.each do |dp|
        if @analysis.data_points.where(variable_values: dp[:variables]).exists?
          Rails.logger.info("Datapoint has already run for #{dp[:name]}")
          data_point_list.delete(dp)
        end
        #result << {variable_group: run_list, name: name, variables: variables, iteration: iteration, sample: i_sample}
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
    @analysis['iteration'] = @iteration
    @analysis['x_objective_function'] = @options[:x_objective_function]
    @analysis['y_objective_function'] = @options[:y_objective_function]

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
        values, weights = variable.map_discrete_hash_to_array
        measure_values["#{variable._id}"] = values
      end
      Rails.logger.info "measure values with variables are #{measure_values}"
      # TODO, test the length of each measure value array
      measure_values = measure_values.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
      Rails.logger.info "measure values array hash is  #{measure_values}"

      measure_values.each do |mvs|
        parameter_space[UUID.new.generate] = {measure_id: measure._id, variables: mvs}
      end
    end

    # The resulting parameter space is in the form of a hash with elements like the below
    # "9a1dbc60-1919-0131-be3d-080027880ca6"=>{:measure_id=>"e16805f0-a2f2-4122-828f-0812d49493dd",
    #   :variables=>{"8651b16d-91df-4dc3-a07b-048ea9510058"=>80, "c7cf9cfc-abf9-43b1-a07b-048ea9510058"=>"West"}}

    Rails.logger.info "Parameter space has #{parameter_space.count} and are #{parameter_space}"

    @run_list = determine_run_list(parameter_space) # get initial run list
    Rails.logger.info "datapoint list is #{@run_list}"
    while not @run_list.empty?
      if @run_list.empty?
        # must have converged?
        break
      else
        @run_list.each do |run|
          Rails.logger.info "adding new datapoint #{run[:name]} with variables #{run[:variables]}"
          dp = @analysis.data_points.new(name: run[:name])
          Rails.logger.info "class of variables is #{run[:variables]} of class #{run[:variables].class}"

          dp['variable_group_list'] = run[:variable_group]
          dp.variable_values = run[:variables]
          dp['iteration'] = run[:iteration]
          dp['sample'] = run[:sample]
          if dp.save!
          else
            raise "could not save datapoint #{dp.errors}"
          end
          Rails.logger.info "Added new datapoint #{dp.inspect}"
        end
        @analysis.save!

        # So why does this work? It should hit run_analysis and it should come back as analysis is queued
        Rails.logger.info("kicking off simulations for iteration #{@iteration}")
        @analysis.start(true, 'batch_run', {skip_init: true, simulate_data_point_filename: "simulate_data_point_lhs.rb"})
      end

      Rails.logger.info("finished simulations for iteration #{@iteration}... iterating")
      @iteration += 1
      @run_list = determine_run_list(parameter_space)
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

