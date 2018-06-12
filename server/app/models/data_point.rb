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

class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, type: String
  field :_id, type: String, default: -> { uuid || SecureRandom.uuid }
  field :name, type: String
  field :description, type: String, default: '' # For support of EDAPT users in PAT 2.0
  field :variable_values # This has been hijacked by OS DataPoint. Use set_variable_values
  field :set_variable_values, type: Hash, default: {} # By default this is a hash list with the name being the id of the variable and the value is the value it was set to.
  field :seed, type: String, default: '' # This enables custom seed models for batch_datapoints analyses
  field :weather_file, type: String, default: '' # This enables custom weather files for batch_datapoints analyses
  field :da_descriptions, type: Array, default: [] # This enables custom measure name & description fields

  field :status, type: String, default: 'na' # The available states are [:na, :queued, :started, :completed]
  field :status_message, type: String, default: '' # results of the simulation [:completed normal, :datapoint failure]
  field :job_id, type: String  # The job_id that is being tracked in Resque/Delayed Job
  field :results, type: Hash, default: {}
  field :run_queue_time, type: DateTime, default: nil
  field :run_start_time, type: DateTime, default: nil
  field :run_end_time, type: DateTime, default: nil
  field :sdp_log_file, type: Array, default: []

  # Run location information
  field :ip_address, type: String
  field :internal_ip_address, type: String

  # Relationships
  belongs_to :analysis, index: true
  embeds_many :result_files

  # Indexes
  index({ uuid: 1 }, unique: true)
  index(id: 1)
  index(name: 1)
  index(status: 1)
  index(analysis_id: 1, created_at: 1)
  index(created_at: 1)
  index(uuid: 1, status: 1)
  index(analysis_id: 1, status: 1, ip_address: 1)
  index(run_start_time: -1, name: 1)
  index(run_end_time: -1, name: 1)
  index(analysis_id: 1, iteration: 1, sample: 1)
  index(analysis_id: 1, status: 1, status_message: 1, created_at: 1)

  # Callbacks
  after_create :verify_uuid
  before_destroy :destroy_background_job

  # Before destroy make sure the delayed job ID is also destroyed

  def self.status_states
    [:na, :queued, :started, :completed]
  end

  # Submit the simulation to run in the background task queue
  def submit_simulation
    if Rails.application.config.job_manager == :delayed_job
      job = RunSimulateDataPoint.new(id)
      self.job_id = job.delay(queue: 'simulations').perform.id
    elsif Rails.application.config.job_manager == :resque
      Resque.enqueue(RunSimulateDataPointResque, id)
      self.job_id = id
    else
      raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
    end

    save!
  end

  def set_start_state
    self.run_start_time = Time.now
    self.status = :started
    save!
  end

  def set_success_flag
    self.status_message = 'completed normal'
    save!
  end

  def set_invalid_flag
    self.status_message = 'invalid workflow'
    save!
  end

  def set_cancel_flag
    self.status_message = 'datapoint canceled'
    save!
  end

  def set_error_flag
    self.status_message = 'datapoint failure'
    save!
  end

  def set_complete_state
    self.run_end_time = Time.now
    self.status = :completed

    save!
  end

  def set_canceled_state
    self.destroy_background_job # Remove the datapoint from the delayed jobs queue
    self.run_start_time ||= Time.now
    self.run_end_time = Time.now
    self.status = :completed
    self.status_message = 'datapoint canceled'
    save!
  end

  protected

  def verify_uuid
    self.uuid = id if uuid.nil?
    save!
  end

  def destroy_background_job
    if Rails.application.config.job_manager == :delayed_job
      if job_id
        dj = Delayed::Job.where(id: job_id).first
        dj.destroy if dj
      end
    elsif Rails.application.config.job_manager == :resque
      if job_id
        Resque::Job.destroy(:simulations, 'RunSimulateDataPointResque', job_id)
      end
    else
      raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
    end
  end
end
