# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
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

class Job
  include Mongoid::Document
  include Mongoid::Timestamps

  field :queued_time, type: DateTime, default: nil
  field :start_time, type: DateTime, default: nil
  field :end_time, type: DateTime, default: nil
  field :status, type: String, default: ''
  field :status_message, type: String, default: ''
  field :analysis_type, type: String, default: ''
  field :delayed_job_id, type: String
  field :index, type: Integer
  # Options is now a destructive field. Rename options to initial_options
  field :initial_options, type: Hash # these are the passed in options
  field :run_options, type: Hash, default: {} # these are the options after merging with the default
  field :results, type: Hash, default: {}

  belongs_to :analysis

  index(id: 1)
  index(created_at: 1)
  index(analysis_id: 1)
  index(analysis_id: 1, index: 1, analysis_type: 1)

  # Create a new job
  def self.new_job(analysis_id, analysis_type, index, initial_options)
    aj = Job.find_or_create_by(analysis_id: analysis_id, analysis_type: analysis_type, index: index)

    aj.status = 'queued'
    aj.analysis_id = analysis_id
    aj.queued_time = Time.now
    aj.analysis_type = analysis_type
    aj.index = index
    aj.initial_options = initial_options
    aj.save

    aj
  end
end
