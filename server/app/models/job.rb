# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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

  #index(id: 1)
  index(created_at: 1)
  index(analysis_id: 1)
  index(analysis_id: 1, index: 1, analysis_type: 1)

  # Create a new job
  def self.new_job(analysis_id, analysis_type, index, initial_options)
    Rails.logger.info "job.new_job"
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
