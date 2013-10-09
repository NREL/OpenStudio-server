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

    def samples_from_probability(probabilities_array, distribution_type, mean, stddev, min, max)
      Rails.logger.info "Creating sample from probability"
      r_dist_name = ""
      if distribution_type == 'normal'
        r_dist_name = "qnorm"
      elsif distribution_type == 'lognormal'
        r_dist_name = "qlnorm"
      elsif distribution_type == 'uniform'
        r_dist_name = "qunif"
      elsif distribution_type == 'triangle'
        r_dist_name = "qtriangle"
      else
        raise "distribution type #{distribution_type} not known for R"
      end

      @r.converse "print('creating distribution')"

      dataframe = {"data" => probabilities_array}.to_dataframe

      if distribution_type == 'uniform'
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
      elsif distribution_type == 'triangle'
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
      @r.converse "samples"
    end

    require 'rserve/simpler'
    require 'uuid'
    require 'childprocess'

    # get the analysis and report that it is running
    @analysis = Analysis.find(@analysis_id)
    @analysis.status = 'started'
    @analysis.run_flag = true
    @analysis.save!

    #create an instance for R
    @r = Rserve::Simpler.new
    Rails.logger.info "Setting up R for #{self.class.name}"
    @r.converse('setwd("/mnt/openstudio")')
    @r.converse "library(snow)"
    @r.converse "library(snowfall)"
    @r.converse "library(lhs)"
    @r.converse "library(triangle)"

    # get variables / measures
    # For some reason the scored variable won't work here! ugh.
    #@analysis.variables.enabled do |variable|
    #@analysis.variables.count
    # TODO: INDEX THIS
    selected_variables = Variable.where({analysis_id: @analysis, perturbable: true})
    Rails.logger.info "Found #{selected_variables.count} Variables to perturb"
    parameter_space = 1
    if false #@analysis.problem.lhs_analysis_type = "Senstiviity"
      parameter_space = selected_variables.count
    end

    # generate the probabilities for all variables [individually]

    # p = nil
    # if var_cnt > 0
    #   puts "Found #{var_cnt} variables"
    @r.converse("print('starting lhs')")
    # get the probabilities and persist them for reference
    Rails.logger.info "Starting sampling"
    p = lhs_probability(parameter_space, 100)
    Rails.logger.info "Probabilities #{p.class} with #{p.inspect}"
    samples = samples_from_probability(p[0], "triangle", 50, 10, 30, 90)
    Rails.logger.info "Samples are #{samples}"

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # create a new datapoint and define the variable_instance
    samples.each do |sample|
      # check variable type
      dp_name = "LHS Autogenerated #{sample.round(2)}"
      dp = @analysis.data_points.new(name: dp_name)
      dp.save!
    end

    @analysis.analysis_output = ""

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

