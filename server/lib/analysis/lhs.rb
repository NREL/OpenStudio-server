class Analysis::Lhs < Struct.new(:options)
  def initialize(analysis_id, data_points)
    # add into delayed job
    @analysis_id = analysis_id
    @data_points = data_points
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    def lhs_probability(num_variables, sample_size)
      Rails.logger.info "Start generating of LHS #{Time.now}"
      a = @r.converse "a <- randomLHS(#{sample_size}, #{num_variables})"

      #returns a matrix so convert over to an ordered hash so that we can send back to R when needed
      o = {}
      (0..a.column_size-1).each do |col|
        o[col] = a.column(col).to_a
      end

      #return as an ordered hash
      Rails.logger.info "Finished generating of LHS #{Time.now}"
      o
    end

    def discrete_sample_from_probability(probabilities_array, distribution_type, hash_values_and_weight, save_histogram = true)
      @r.converse "print('creating discrete distribution')"

      if hash_values_and_weight.nil? || hash_values_and_weight.empty?
        raise "no hash values and weight passed"
      end

      ave_weight = 1 / hash_values_and_weight.size
      hash_values_and_weight.each do |kv|
        kv['weight'] = ave_weight if kv['weight'].nil?
      end
      values = hash_values_and_weight.map { |k| k['value'] }
      weights = hash_values_and_weight.map { |k| k['weight'] }

      Rails.logger.info("values are #{values}, weights are #{weights}")

      dataframe = {"data" => probabilities_array}.to_dataframe

      if distribution_type == 'discrete_uncertain'
        @r.command(:df => dataframe, :values => values, :weights => weights) do
          %Q{
              print(values)
              print(values)
              samples <- qdiscrete(df$data, weights, values)
            }
        end
      elsif distribution_type == 'bool_uncertain'

      else
        raise "discrete distribution type #{distribution_type} not known for R"
      end

      # returns an array
      @r.converse "print(samples)"
      save_file_name = nil
      if save_histogram
        # Determine where to save it
        save_file_name = "/tmp/#{Dir::Tmpname.make_tmpname(['r_plot', '.jpg'], nil)}"
        Rails.logger.info("R image file name is #{save_file_name}")
        @r.command() do
          %Q{
            print("#{save_file_name}")
            png(filename="#{save_file_name}", width = 1024, height = 1024)
            hist(samples, freq=F, breaks=20)
            dev.off()
          }
        end
      end

      {r: @r.converse("samples"), image_path: save_file_name}
    end

    def samples_from_probability(probabilities_array, distribution_type, mean, stddev, min, max, save_histogram = true)
      Rails.logger.info "Creating sample from probability"
      r_dist_name = ""
      if distribution_type == 'normal' || distribution_type == 'normal_uncertain'
        r_dist_name = "qnorm"
      elsif distribution_type == 'lognormal'
        r_dist_name = "qlnorm"
      elsif distribution_type == 'uniform' || distribution_type == 'uniform_uncertain'
        r_dist_name = "qunif"
      elsif distribution_type == 'triangle' || distribution_type == 'triangular_uncertain'
        r_dist_name = "qtriangle"
      else
        raise "distribution type #{distribution_type} not known for R"
      end

      @r.converse "print('creating distribution')"

      dataframe = {"data" => probabilities_array}.to_dataframe

      if distribution_type == 'uniform' || distribution_type == 'uniform_uncertain'
        @r.command(:df => dataframe) do
          %Q{
              samples <- #{r_dist_name}(df$data, #{min}, #{max})
            }
        end
      elsif distribution_type == 'lognormal'
        @r.command(:df => dataframe) do
          %Q{
              sigma <- sqrt(log(#{stddev}/(#{mean}^2)+1))
              mu <- log((#{mean}^2)/sqrt(#{stddev}+#{mean}^2))
              samples <- #{r_dist_name}(df$data, mu, sigma)
              samples[(samples > #{max}) | (samples < #{min})] <- runif(1,#{min},#{max})
            }
        end
      elsif distribution_type == 'triangle' || distribution_type == 'triangular_uncertain'
        @r.command(:df => dataframe) do
          %Q{
            print(df)
            samples <- #{r_dist_name}(df$data, #{min}, #{max}, #{mean})
          }
        end
      else
        @r.command(:df => dataframe) do
          %Q{
              samples <- #{r_dist_name}(df$data, #{mean}, #{stddev})
              samples[(samples > #{max}) | (samples < #{min})] <- runif(1,#{min},#{max})

            }
        end
      end

      # returns an array
      @r.converse "print(samples)"
      save_file_name = nil
      if save_histogram
        # Determine where to save it
        save_file_name = "/tmp/#{Dir::Tmpname.make_tmpname(['r_plot', '.jpg'], nil)}"
        Rails.logger.info("R image file name is #{save_file_name}")
        @r.command() do
          %Q{
            print("#{save_file_name}")
            png(filename="#{save_file_name}", width = 1024, height = 1024)
            hist(samples, freq=F, breaks=20)
            dev.off()
          }
        end
      end

      {r: @r.converse("samples"), image_path: save_file_name}
    end

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
    Rails.logger.info "Setting up R for #{self.class.name}"
    @r.converse('setwd("/mnt/openstudio")')
    @r.converse("set.seed(#{@analysis.problem['random_seed']})")
    @r.converse "library(snow)"
    @r.converse "library(snowfall)"
    @r.converse "library(lhs)"
    @r.converse "library(triangle)"
    @r.converse "library(e1071)"

    # get variables / measures
    # TODO: For some reason the scoped variable won't work here! ugh.
    #@analysis.variables.enabled do |variable|

    selected_variables = Variable.where({analysis_id: @analysis, perturbable: true}).order_by(:name.asc)
    Rails.logger.info "Found #{selected_variables.count} Variables to perturb"
    parameter_space = selected_variables.count

    # generate the probabilities for all variables [individually]

    @r.converse("print('starting lhs')")
    # get the probabilities and persist them for reference
    Rails.logger.info "Starting sampling"
    p = lhs_probability(parameter_space, @analysis.problem['number_of_samples'])
    Rails.logger.info "Probabilities #{p.class} with #{p.inspect}"

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.
    # For now, create a new variable_instance, create new datapoints, and add the instance reference
    i_var = 0
    samples = {} # samples are in hash of arrays
    # TODO: IMPLEMENT THIS in parallel
    selected_variables.each do |var|
      sfp = nil
      if var.uncertainty_type == "discrete_uncertain"
        Rails.logger.info("disrete vars for #{var.name} are #{var.discrete_values_and_weights}")
        sfp = discrete_sample_from_probability(p[i_var], var.uncertainty_type, var.discrete_values_and_weights, var.type != "String")
      else
        sfp = samples_from_probability(p[i_var], var.uncertainty_type, var.modes_value, nil, var.lower_bounds_value, var.upper_bounds_value, var.type != "String")
      end
      samples["#{var.id}"] = sfp[:r]
      if sfp[:image_path]
        pfi = PreflightImage.add_from_disk(var.id, "histogram", sfp[:image_path])
        var.preflight_images << pfi unless var.preflight_images.include?(pfi)
      end

      i_var += 1
    end

    Rails.logger.info "Samples are #{samples}"

    # The arrays of the hash need to always have the same length
    # TODO make sure length is consitent

    # multiple and smash the hash of arrays to form a array of hashes
    #samples = samples.map{ |k, v| [k].product(v) }.transpose.map { |ps| {:values => Hash[ps]} }
    samples = samples.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }

    Rails.logger.info "Flipping samples around yields #{samples}"

    isample = 0
    samples.each do |sample|
      # need to figure out how to map index to variable
      isample += 1
      dp_name = "LHS Autogenerated #{isample}"
      dp = @analysis.data_points.new(name: dp_name)
      dp['values'] = sample
      dp.save!

      #sample[:name] = dp_name
      #sample[:analysis_id] = @analysis.id
      #sample[:uuid] = UUID.new.generate
      #sample[:_id] = sample[:uuid]
    end

    # Bulk save all the data points
    #DataPoint.collection.insert(samples)

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

