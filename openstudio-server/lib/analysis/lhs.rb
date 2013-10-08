class Analysis::Lhs < Struct.new(:options)
  def initialize(analysis_id, data_points)
    # add into delayed job
    @analysis_id = analysis_id
    @data_points = data_points


  end

  def lhs_probability(num_variables, sample_size)
    Rails.logger.info "Starting generating of LHS #{Time.now}"
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

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    require 'rserve/simpler'
    require 'uuid'
    require 'childprocess'

    @analysis = Analysis.find(@analysis_id)

    #create an instance for R
    @r = Rserve::Simpler.new
    Rails.logger.info "Setting up R for LHS"
    @r.converse('setwd("/mnt/openstudio")')
    @r.converse "library(snow)"
    @r.converse "library(snowfall)"
    @r.converse "library(lhs)"
    @r.converse "library(triangle)"

    # get variables / measures
    # measure['variables'].map { |k, v| var_cnt += 1 if k['method'] == 'lhs' }

    # generate the probabilities for all variables [individually]


    # p = nil
    # if var_cnt > 0
    #   puts "Found #{var_cnt} variables"
    @r.converse("print('starting lhs')")

    # get the probabilities and persist them for reference
    Rails.logger.info "Starting sampling"
    p = lhs_probability(1, 100)
    Rails.logger.info "Samples were #{p}"

    @analysis.status = 'started'
    @analysis.run_flag = true
    @analysis.save!

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    @analysis.analysis_output = p

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

