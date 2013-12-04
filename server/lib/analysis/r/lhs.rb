module Analysis::R
  class Lhs
    def initialize(r_session)
      @r = r_session

      @r.converse "library(lhs)"
      @r.converse "library(triangle)"
      @r.converse "library(e1071)"
    end
    
    # Take the number of variables and number of samples and generate the bins for
    # a LHS sample
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

    def discrete_sample_from_probability(probabilities_array, var, save_histogram = true)
      @r.converse "print('creating discrete distribution')"
      if var.map_discrete_hash_to_array.nil? || var.discrete_values_and_weights.empty?
        raise "no hash values and weight passed"
      end
      values, weights = var.map_discrete_hash_to_array

      dataframe = {"data" => probabilities_array}.to_dataframe

      if var.uncertainty_type == 'discrete_uncertain'
        @r.command(:df => dataframe, :values => values, :weights => weights) do
          %Q{
            print(values)
            samples <- qdiscrete(df$data, weights, values)
          }
        end
      elsif var.uncertainty_type == 'bool_uncertain'
        raise "bool_uncertain needs some updating to map from bools"
        @r.command(:df => dataframe, :values => values, :weights => weights) do
          %Q{
            print(values)
            samples <- qdiscrete(df$data, weights, values)
          }
        end
      else
        raise "discrete distribution type #{var.uncertainty_type} not known for R"
      end

      # returns an array
      @r.converse "print(samples)"
      save_file_name = nil
      if save_histogram && !values[0].kind_of?(String)
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
      elsif distribution_type == 'triangle' || distribution_type == 'triangle_uncertain'
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
      elsif distribution_type == 'triangle' || distribution_type == 'triangle_uncertain'
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
      smaples = @r.converse "print(samples)"
      save_file_name = nil
      if save_histogram && !smaples[0].kind_of?(String)
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

    def sample_all_variables(selected_variables, number_of_samples)
      samples = {}
      var_types = []

      # get the probabilities
      p = lhs_probability(selected_variables.count, number_of_samples)
      Rails.logger.info "Probabilities #{p.class} with #{p.inspect}"

      # The resulting parameter space is in the form of a hash with elements like the below
      # "9a1dbc60-1919-0131-be3d-080027880ca6"=>{:measure_id=>"e16805f0-a2f2-4122-828f-0812d49493dd",
      #   :variables=>{"8651b16d-91df-4dc3-a07b-048ea9510058"=>80, "c7cf9cfc-abf9-43b1-a07b-048ea9510058"=>"West"}}

      i_var = 0
      # TODO: performance smell... optimize this using Parallel
      selected_variables.each do |var|
        sfp = nil
        if var.uncertainty_type == "discrete_uncertain"
          Rails.logger.info("disrete vars for #{var.name} are #{var.discrete_values_and_weights}")
          sfp = discrete_sample_from_probability(p[i_var], var, true)
          var_types << "discrete"
        else
          sfp = samples_from_probability(p[i_var], var.uncertainty_type, var.modes_value, nil, var.lower_bounds_value, var.upper_bounds_value, true)
          var_types << "continuous"
        end

        samples["#{var.id}"] = sfp[:r]
        if sfp[:image_path]
          pfi = PreflightImage.add_from_disk(var.id, "histogram", sfp[:image_path])
          var.preflight_images << pfi unless var.preflight_images.include?(pfi)
        end

        var.r_index = i_var + 1 # r_index is 1-based 
        var.save!

        i_var += 1
      end

      [samples, var_types]
    end

    
    # Take each variable and sample it compared to looking at all the variables and sampling them together
    def sample_individual_variables(selected_variables, number_of_samples)
      samples = {}
      var_types = []

      # get the probabilities
      p = lhs_probability(selected_variables.count, number_of_samples)
      Rails.logger.info "Probabilities #{p.class} with #{p.inspect}"

      i_var = 0
      # TODO: performance smell... optimize this using Parallel
      selected_variables.each do |var|
        sfp = nil
        if var.uncertainty_type == "discrete_uncertain"
          Rails.logger.info("disrete vars for #{var.name} are #{var.discrete_values_and_weights}")
          sfp = discrete_sample_from_probability(p[i_var], var, true)
          var_types << "discrete"
        else
          sfp = samples_from_probability(p[i_var], var.uncertainty_type, var.modes_value, nil, var.lower_bounds_value, var.upper_bounds_value, true)
          var_types << "continuous"
        end

        samples["#{var.id}"] = sfp[:r]
        if sfp[:image_path]
          pfi = PreflightImage.add_from_disk(var.id, "histogram", sfp[:image_path])
          var.preflight_images << pfi unless var.preflight_images.include?(pfi)
        end

        var.r_index = i_var + 1 # r_index is 1-based 
        var.save!

        i_var += 1
      end

      [samples, var_types]
    end
  end
end


