#*******************************************************************************
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
#*******************************************************************************

require 'optparse'

namespace :datapoints do
  desc 'test uploading a result_file'
  task test_file_upload: :environment do
    # This test has been removed.
    puts "Look at the simulate_data_point.rb to see how we are uploading files"
  end

  # rake datapoints:create_datapoint -- -afa5dcadc-ed5b-4209-b907-777e9e2573c8 -v5,3,alsdfjk
  desc 'create new datapoint'
  task :create_datapoint => :environment do
    puts ARGV.inspect

    options = {}
    o = OptionParser.new do |opts|
      opts.banner = "Usage: rake create_datapoint -- '-a <analysis_id -v <[variables]>'"
      opts.on('-a', '--analysis_id ID', String) { |a| options[:analysis_id] = a }
      opts.on('-v', '--variables ID', Array) { |a| options[:variables] = a }
    end
    args = o.order!(ARGV) {}
    o.parse!(args)
    puts options.inspect

    a = RunCreateDatapoint.new(options[:analysis_id], options[:variables])
    uuid = a.perform

    puts uuid
  end
end


