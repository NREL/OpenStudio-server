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

# Core functions for analysis
module AnalysisLibrary
  module Core
    def database_name
      Mongoid.default_client.database.name
    end

    module_function :database_name

    # Take the samples and add in the pivots.  Each pivot variable
    # will get a full set of samples
    # take p = [{p1: 1}, {p1: 2}]
    # with s = [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    # make s' = [{p1: 1, a: 1, b: 4}, {p1: 2, a: 1, b: 4}, {p1: 1, a: 2, b: 5},  {p1: 2, a: 2, b: 5}]
    def add_pivots(samples, pivots)
      new_samples = []
      unless pivots.empty?
        pivots.each do |pivot|
          samples.each do |sample|
            new_samples << pivot.merge(sample)
          end
        end
        samples = new_samples
      end

      new_samples.empty? ? samples : new_samples
    end

    # static array of hash
    # take static = [{a: 1, b: 2}]
    # with samples = [{c: 3}, {d: 4}]
    # results is [{a:1, b:2, c:3}, {a:1, b:2, d:4}]
    def add_static_variables(samples, statics)
      # Need to test the performance of this
      unless statics.empty?
        samples.each do |sample|
          statics.each do |st|
            sample.merge!(st)
          end
        end
      end

      samples
    end

    # For sampling take hashes of array values and makes them arrays of hashes set to
    # each value in the array index
    def hash_of_array_to_array_of_hash(hash_array)
      # This takes
      # {a: [1,2,3], b:[4,5,6]}
      # and makes:
      # [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
      result = hash_array.map { |k, v| [k].product(v) }.transpose.map { |ps| Hash[ps] }
    end

    # export this function for use outside of class extension
    module_function :hash_of_array_to_array_of_hash

    # This takes
    # {a: [1,2,3], b:[4,5,6]}
    # and makes:
    # [{:a=>1, :b=>4}, {:a=>1, :b=>5}, {:a=>1, :b=>6}, {:a=>2, :b=>4}, {:a=>2, :b=>5}, {:a=>2, :b=>6}, {:a=>3, :b=>4}, {:a=>3, :b=>5}, {:a=>3, :b=>6}]
    def product_hash(hash_array)
      return [] if hash_array.empty?
      attrs   = hash_array.values
      keys    = hash_array.keys
      product = attrs[0].product(*attrs[1..-1])
      result = product.map { |p| Hash[keys.zip p] }

      result
    end

    module_function :product_hash

    # return the single dimension samples of the array.  This also runs a dedupe method.
    def hash_of_array_to_array_of_hash_non_combined(hash_array, selected_variables)
      # This takes
      # h = {a: [1, 2, 3], b: ["4", "5", "6"], c: [true, false, false]}
      # and makes
      # [{a:1}, {a:2}, {a:3}, {b:"4"}, ... {c: true}, {c: false}]
      result = hash_array.map { |k, v| v.map { |value| { :"#{k}" => value } } }.flatten.uniq
      # then sets the "static/default" from the other variables
      selected_variables.each do |var|
        result.each_with_index do |r, index|
          unless r.key? var._id.to_sym
            result[index][var._id.to_sym] = var.static_value
          end
        end
      end

      result
    end
    module_function :hash_of_array_to_array_of_hash_non_combined # export this function for use outside of class extension

    # Initialize the analysis and report the data back to the database
    #   analysis: mongoid object which contains the analysis
    #   analysis_job_id: the Delayed Job ID that was given when the analysis was started
    #   options: the options array that is passed into the analysis (merged with defaults)
    def initialize_analysis_job(analysis, analysis_job_id, options)
      analysis_job = Job.find(analysis_job_id)
      analysis.run_flag = true

      # add in the default problem/algorithm options into the analysis object
      # anything at at the root level of the options are not designed to override the database object.
      analysis.problem = options[:problem].deep_merge(analysis.problem) if analysis.problem

      # save other run information in another object in the analysis
      analysis_job.start_time = Time.now
      analysis_job.status = 'started'
      analysis_job.run_options = options.reject { |k, _| [:problem, :data_points, :output_variables].include?(k.to_sym) }
      analysis_job.save!

      # Clear out any former results on the analysis
      analysis.results ||= {} # make sure that the analysis results is a hash and exists
      analysis.results[options[:analysis_type]] = {}

      # merge in the output variables and objective functions into the analysis object which are needed for problem execution
      if options[:output_variables]
        options[:output_variables].reverse_each { |v| analysis.output_variables.unshift(v) unless analysis.output_variables.include?(v) }
        analysis.output_variables.uniq!
      end

      # verify that the objective_functions are unique
      if analysis.problem && analysis.problem['algorithm'] && analysis.problem['algorithm']['objective_functions']
        analysis.problem['algorithm']['objective_functions'].uniq! if analysis.problem['algorithm']['objective_functions']
      end

      # some algorithm specific data to be stored in the database
      # TODO: I have a feeling that this is not initalized in some cases -- so lazily initializing here
      @iteration ||= -1
      analysis['iteration'] = @iteration

      # save all the changes into the database
      analysis.save!

      # return the analysis job db object
      analysis_job
    end
    module_function :initialize_analysis_job

    def initialize_rserve(hostname = 'localhost', port = 6311)
      rserve_options = {
        hostname: hostname,
        port_number: port
      }
      require 'rserve/simpler'
      ::Rserve::Simpler.new(rserve_options)
    end
    module_function :initialize_rserve
  end
end
