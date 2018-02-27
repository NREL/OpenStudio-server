# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

module AnalysisLibrary::R  
  class Doe
    def initialize(r_session)
      @r = r_session

      @r.converse 'library(DoE.base)'
      @r.converse 'library(lhs)'
      @r.converse 'library(triangle)'
      @r.converse 'library(e1071)'
    end

    # Take the number of variables and number of samples and generate the bins for
    # a LHS sample
    def lhs_probability2(num_variables, sample_size)
      logger.info "Start generating of LHS #{Time.now}"
      a = @r.converse "a <- randomLHS(#{sample_size}, #{num_variables})"

      # returns a matrix so convert over to an ordered hash so that we can send back to R when needed
      o = {}
      (0..a.column_size - 1).each do |col|
        o[col] = a.column(col).to_a
      end

      # return as an ordered hash
      logger.info "Finished generating of LHS #{Time.now}"
      o
    end

    # Sample the data in a discrete manner. This requires that the user passes in an array of the
    # samples to choose from which can contain the weights.
    def discrete_sample_from_probability2(probabilities_array, var)
      @r.converse "print('creating discrete distribution')"
      if var.map_discrete_hash_to_array.nil? || var.discrete_values_and_weights.empty?
        raise 'no hash values and weight passed'
      end
      values, weights = var.map_discrete_hash_to_array

      dataframe = { 'data' => probabilities_array }.to_dataframe

      if var.uncertainty_type == 'discrete'
        @r.command(df: dataframe, values: values, weights: weights) do
          "
            print(values)
            samples <- qdiscrete(df$data, weights, values)
          "
        end
      elsif var.uncertainty_type == 'bool' || var.uncertainty_type == 'boolean'
        raise 'bool distribution needs some updating to map from bools'
        @r.command(df: dataframe, values: values, weights: weights) do
          "
            print(values)
            samples <- qdiscrete(df$data, weights, values)
          "
        end
      else
        raise "discrete distribution type #{var.uncertainty_type} not known for R"
      end

      samples = @r.converse 'samples'
      samples = [samples] unless samples.is_a? Array # ensure it is an array
      logger.info("R created the following samples #{@r.converse('samples')}")

      samples
    end

    # Take the values/probabilities from the LHS sample and transform them into
    # the other distribution using the quantiles of the other distribution.
    # Note that the probabilities and the samples must be an array so there are
    # checks to make sure that it is.  If R only has one sample, then it will not
    # wrap it in an array.
    def samples_from_probability2(probabilities_array, distribution_type, mean, stddev, min, max)
      probabilities_array = [probability_array] unless probabilities_array.is_a? Array # ensure array

      logger.info 'Creating sample from probability'
      r_dist_name = ''
      if distribution_type == 'normal'
        r_dist_name = 'qnorm'
      elsif distribution_type == 'lognormal'
        r_dist_name = 'qlnorm'
      elsif distribution_type == 'uniform'
        r_dist_name = 'qunif'
      elsif distribution_type == 'triangle'
        r_dist_name = 'qtriangle'
      else
        raise "distribution type #{distribution_type} not known for R"
      end

      @r.converse "print('creating distribution')"
      dataframe = { 'data' => probabilities_array }.to_dataframe

      if distribution_type == 'uniform'
        @r.command(df: dataframe) do
          "
            samples <- #{r_dist_name}(df$data, #{min}, #{max})
          "
        end
      elsif distribution_type == 'lognormal'
        @r.command(df: dataframe) do
          "
            sigma <- sqrt(log(#{stddev}/(#{mean}^2)+1))
            mu <- log((#{mean}^2)/sqrt(#{stddev}+#{mean}^2))
            samples <- #{r_dist_name}(df$data, mu, sigma)
            samples[(samples > #{max}) | (samples < #{min})] <- runif(length(samples[(samples > #{max}) | (samples < #{min})]),#{min},#{max})
          "
        end
      elsif distribution_type == 'triangle'
        @r.command(df: dataframe) do
          "
          print(df)
          samples <- #{r_dist_name}(df$data, #{min}, #{max}, #{mean})
        "
        end
      else
        @r.command(df: dataframe) do
          "
            samples <- #{r_dist_name}(df$data, #{mean}, #{stddev})
            samples[(samples > #{max}) | (samples < #{min})] <- runif(length(samples[(samples > #{max}) | (samples < #{min})]),#{min},#{max})
          "
        end
      end

      samples = @r.converse 'samples'
      samples = [samples] unless samples.is_a? Array # ensure it is an array
      logger.info("R created the following samples #{@r.converse('samples')}")

      samples
    end

    def full_factorial(selected_variables, number_of_samples)
      samples = {}
      samples_temp = {}
      var_types = []
      var_names = []
      min_max = {}
      min_max[:min] = []
      min_max[:max] = []
      min_max[:eps] = []

      # @r.converse 'doe.orig <- data.frame()'
      # @r.converse 'doe.orig <- list()'
      @r.converse "doe.orig <- vector(mode='list', length=#{selected_variables.count})"

      # get the probabilities
      logger.info "Sampling #{selected_variables.count} variables with #{number_of_samples} samples"
      p = lhs_probability2(selected_variables.count, number_of_samples)
      logger.info "Probabilities #{p.class} with #{p.inspect}"

      # TODO: performance smell... optimize this using Parallel
      i_var = 0
      selected_variables.each do |var|
        logger.info "sampling variable #{var.name} for measure #{var.measure.name}"
        variable_samples = nil
        var_names << var.name
        # TODO: would be nice to have a field that said whether or not the variable is to be discrete or continuous.
        # IF discrete, just get the original values of the variables.
        if var.uncertainty_type == 'discrete'
          logger.info("disrete vars for #{var.name} are #{var.discrete_values_and_weights}")
          # variable_samples = discrete_sample_from_probability(p[i_var], var)
          if var.map_discrete_hash_to_array.nil? || var.discrete_values_and_weights.empty?
            raise 'no hash values and weight passed'
          end
          values, weights = var.map_discrete_hash_to_array
          logger.info("values is #{values}")
          variable_samples = values
          logger.info("variable_samples is #{variable_samples}")
          var_types << 'discrete'
        # IF continuous, then sample the variable to make it "discrete"
        else
          variable_samples = samples_from_probability2(p[i_var], var.uncertainty_type, var.modes_value, var.stddev_value,
                                                       var.lower_bounds_value, var.upper_bounds_value)
          var_types << 'continuous'
        end

        min_max[:min] << var.lower_bounds_value
        min_max[:max] << var.upper_bounds_value
        if var.delta_x_value
          min_max[:eps] << var.delta_x_value
        else
          min_max[:eps] << 0
        end

        var.r_index = i_var + 1 # r_index is 1-based
        var.save!

        i_var += 1
        # @r.converse "doe.orig <- rbind.fill(doe.orig,as.data.frame(#{variable_samples}))"
        # @r.converse "#{var.name} <- #{variable_samples}"
        @r.command(var_names: var.name, var_sample: variable_samples) do
          %{
            #print(paste("doe.orig:",doe.orig))
            #print(paste("legnth of doe.orig:",length(doe.orig)))
            #print(paste("typeof(var_names):",typeof(var_names)))
            #num_var <- length(var_names)
            #print(paste("num_var:",num_var))
            print(paste("var_names:",var_names))
            #print(paste("typeof(var_sample):",typeof(var_sample)))
            #print(paste("var_sample:",var_sample))
            #num_var_sample <- length(var_sample)
            #print(paste("num_var_sample:",num_var_sample))
            doe.orig[[#{var.r_index}]] <- var_sample
            print(paste("doe.orig:",doe.orig))
            print(paste("r_index:",#{var.r_index}))
          }
        end
      end

      @r.converse "print('creating full factorial')"
      @r.command(var_names: var_names) do
        %{
          fac_design<- fac.design(factor.names=doe.orig, randomize=FALSE)
        }
      end
      @r.converse 'print(fac_design)'
      samples_temp = @r.converse 'fac_design'
      logger.info("samples_temp is #{samples_temp}")

      def is_number? string
        true if Float(string) rescue false
      end
      
      selected_variables.each_with_index do |var, idx|
        if is_number?(samples_temp[idx][0])
          #samples[var.id.to_s] = samples_temp[idx].to_f
          samples[var.id.to_s] =  samples_temp[idx].map {|i| i.to_f}
        else
          samples[var.id.to_s] = samples_temp[idx]
        end
      end

      logger.info("samples is #{samples}")

      [samples, var_types, min_max, var_names]
    end

    def logger
      Rails.logger
    end
  end
end
