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

class Analysis
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip
  include Mongoid::Attributes::Dynamic

  require 'delayed_job_mongoid'

  field :uuid, type: String
  field :_id, type: String, default: -> { uuid || SecureRandom.uuid }
  field :version_uuid
  field :name, type: String
  field :display_name, type: String
  field :description, type: String
  field :run_flag, type: Boolean, default: false
  field :exit_on_guideline_14, type: Integer, default: 0

  # Hash of the jobs to run for the analysis
  # field :jobs, type: Array, default: [] # very specific format
  # move the results into the jobs array
  field :results, type: Hash, default: {} # this was nil, can we have this be an empty hash? Check Measure Group JSONS!

  field :problem
  field :status_message, type: String, default: '' # the resulting message from the analysis
  field :output_variables, type: Array, default: [] # list of variable that are needed for output including objective functions
  field :os_metadata # don't define type, keep this flexible

  # Temp location for these vas
  field :samples, type: Integer

  has_mongoid_attached_file :seed_zip,
                            url: '/assets/analyses/:id/:style/:basename.:extension',
                            path: "#{APP_CONFIG['server_asset_path']}/assets/analyses/:id/:style/:basename.:extension"

  # Relationships
  belongs_to :project

  has_many :data_points, dependent: :destroy
  has_many :algorithms, dependent: :destroy
  has_many :variables, dependent: :destroy
  has_many :measures, dependent: :destroy
  has_many :paretos, dependent: :destroy
  has_many :jobs, dependent: :destroy

  embeds_many :result_files

  # Indexes
  index({ uuid: 1 }, unique: true)
  index(id: 1)
  index(name: 1)
  index(created_at: 1)
  index(updated_at: -1)
  index(project_id: 1)

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  validates_attachment_content_type :seed_zip, content_type: %w(application/zip)

  # Callbacks
  after_create :verify_uuid
  before_destroy :queue_delete_files

  def self.status_states
    %w(na init queued started completed)
  end

  def start(no_delay, analysis_type = 'batch_run', options = {})
    defaults = { skip_init: false }
    options = defaults.merge(options)

    logger.info "Calling start on #{analysis_type} with options #{options}"

    unless options[:skip_init]
      logger.info("Queuing up analysis #{uuid}")
      save!
    end

    logger.info("Starting #{analysis_type}")
    if no_delay
      logger.info("Running in foreground analysis for #{uuid} with #{analysis_type}")
      aj = jobs.new_job(id, analysis_type, jobs.length, options)
      save!
      reload
      abr = "AnalysisLibrary::#{analysis_type.camelize}".constantize.new(id, aj.id, options)
      abr.perform
    else
      logger.info("Running in background analysis queue for #{uuid} with #{analysis_type}")
      aj = jobs.new_job(id, analysis_type, jobs.length, options)
      if Rails.application.config.job_manager == :delayed_job
        job = Delayed::Job.enqueue "AnalysisLibrary::#{analysis_type.camelize}".constantize.new(id, aj.id, options), queue: 'analyses'
        aj.delayed_job_id = job.id
      elsif Rails.application.config.job_manager == :resque
        Resque.enqueue(RunAnalysisResque, analysis_type, id, aj.id, options)
        aj.delayed_job_id = nil
      else
        raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
      end
      aj.save!

      save!
      reload
    end
  end

  # Options take the form of?
  # Run the analysis
  def run_analysis(no_delay = false, analysis_type = 'batch_run', options = {})
    defaults = {}
    options = defaults.merge(options)

    # check if there is already an analysis in the queue (this needs to move to the analysis class)
    # there is no reason why more than one analyses can be queued at the same time.
    logger.info("called run_analysis analysis of type #{analysis_type} with options: #{options}")

    start(no_delay, analysis_type, options)

    [true]
  end

  def stop_analysis
    logger.info('attempting to stop analysis')

    self.run_flag = false
    # The ensure block will clean up the jobs and save the statuses

    jobs.each do |j|
      unless j.status == 'completed'
        j.status = 'completed'
        j.end_time = Time.new
        j.status_message = 'datapoint canceled'
        j.save!
      end
    end

    # Remove all the queued background jobs for this analysis
    data_points.where(status: 'queued').each do |dp|
      dp.set_canceled_state
    end

    [save!, errors]
  end

  # Method that pulls out the variables from the uploaded problem/analysis JSON.
  def pull_out_os_variables
    pat_json = false
    # get the measures first
    logger.info('pulling out openstudio measures')
    # note the measures first
    if self['problem'] && self['problem']['workflow']
      logger.info('found a problem and workflow')
      self['problem']['workflow'].each do |wf|
        # Currently the PAT format has measures and I plan on ignoring them for now
        # this will eventually need to be cleaned up, but the workflow is the order of applying the
        # individual measures
        if wf['measures']
          pat_json = true
          #  wf['measures'].each do |measure|
          #    new_measure = Measure.create_from_os_json(self.id, measure)
          #  end
        end

        # In the "analysis" view, the worklow list is just there...
        unless pat_json
          new_measure = Measure.create_from_os_json(id, wf, pat_json)
        end
      end
    end

    if pat_json
      logger.error('Appears to be a PAT JSON formatted file, pulling variables out of metadata for now')
      if os_metadata && os_metadata['variables']
        os_metadata['variables'].each do |variable|
          var = Variable.create_from_os_json(id, variable)
        end
      end
    end

    # pull out the output variables
    if output_variables
      output_variables.each do |variable|
        logger.info "Saving off output variables: #{variable}"
        var = Variable.create_output_variable(id, variable)
      end
    end

    save!
  end



  # Method goes through all the data_points in an analysis and finds all the
  # input variables (set_variable_values). It uses map/reduce putting the load
  # on the database to do the unique check. Result is a hash of ids and variable
  # names in the form of:
  #   { "uuid": "variable_name", "uuid2": "variable_name_2"}
  #
  # 2013-02-20: NL Moved to Analysis Model. Updated to use map/reduce.  This
  # runs in 62.8ms on a smallish sized collection compared to 461ms on the
  # same collection
  def superset_of_input_variables
    mappings = {}
    start = Time.now

    map = "
      function() {
        for (var key in this.set_variable_values) { emit(key, null); }
      }
    "

    reduce = "
      function(key, nothing) { return null; }
    "

    var_ids = data_points.map_reduce(map, reduce).out(inline: true)
    var_ids.each do |var|
      v = Variable.where(uuid: var['_id']).only(:name).first
      mappings[var['_id']] = v.name.tr(' ', '_') if v
    end
    logger.info "Mappings created in #{Time.now - start}" # with the values of: #{mappings}"

    # sort before sending back
    Hash[mappings.sort_by { |_, v| v }]
  end

  # filter results on analysis show page (per status)
  def search(search, status, page_no = 1, view_all = 0)
    page_no = page_no.blank? ? 1 : page_no
    logger.info("search: #{search}, status: #{status}, page: #{page_no}, view_all: #{view_all}")

    if search
      if status == 'all'
        if view_all
          dps = data_points.where(name: /#{search}/i).order_by(:created_at.asc)
        else
          dps = data_points.where(name: /#{search}/i).order_by(:created_at.asc) # .page(page_no).per(50)
        end
      else
        dps = data_points.where(name: /#{search}/i, status: status).order_by(:created_at.asc) # .page(page_no).per(50)
      end
    else
      if status == 'all'
        if view_all
          dps = data_points
        else
          dps = data_points.order_by(:created_at.asc) # .page(page_no).per(50)
        end
      else
        dps = data_points.where(status: status).order_by(:created_at.asc) # .page(page_no).per(50)
      end
    end
    dps
  end

  # Return the list of job statuses
  def jobs_status
    jobs.order_by(:index.asc).map { |j| { analysis_type: j.analysis_type, status: j.status, status_message: j.status_message } }
  end

  # Return the last job's status for the analysis
  def status
    j = jobs_status
    if j
      begin
        return j.last[:status]
      rescue
        'unknown'
      end
    else
      return 'unknown'
    end
  end

  # Return the last job's status message
  def job_status_message
    j = jobs_status
    if j
      begin
        return j.last[:status_message]
      rescue
        'unknown'
      end
    else
      return 'unknown'
    end
  end

  def analysis_types
    jobs.order_by(:index.asc).map(&:analysis_type)
  end

  def analysis_type
    j = jobs.order_by(:index.asc).last
    if j && j.analysis_type
      return j.analysis_type
    else
      return 'unknown'
    end
  end

  def start_time
    j = jobs.order_by(:index.asc).first

    return j.start_time if j

    nil
  end

  def end_time
    j = jobs.order_by(:index.asc).last
    if j && j['end_time']
      return j['end_time']
    else
      return nil
    end
  end

  def delayed_job_ids
    jobs.map { |v| v[:delayed_job_ids] }
  end

  protected

  # Queue up the task to delete all the files in the background
  def queue_delete_files
    analysis_dir = "#{APP_CONFIG['sim_root_path']}/analysis_#{id}"

    if analysis_dir =~ /^.*\/analysis_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      if Rails.application.config.job_manager == :delayed_job
        Delayed::Job.enqueue ::DeleteAnalysisJob.new(analysis_dir)
      elsif Rails.application.config.job_manager == :resque
        Resque.enqueue(DeleteAnalysisJobResque, analysis_dir)
      else
        raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
      end
    else
      logger.error 'Will not delete analysis directory because it does not conform to pattern'
    end

  end

  def verify_uuid
    self.uuid = id if uuid.nil?
    save!
  end
end
