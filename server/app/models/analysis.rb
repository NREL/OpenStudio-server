class Analysis
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  require 'delayed_job_mongoid'

  field :uuid, type: String
  field :_id, type: String, default: -> { uuid || SecureRandom.uuid }
  field :version_uuid
  field :name, type: String
  field :display_name, type: String
  field :description, type: String
  field :run_flag, type: Boolean, default: false
  field :exit_on_guideline14, type: Boolean, default: false

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
                            path: ':rails_root/public/assets/analyses/:id/:style/:basename.:extension'

  # Relationships
  belongs_to :project

  has_many :data_points
  has_many :algorithms
  has_many :variables # right now only having this a one-to-many (ideally this can go both ways)
  has_many :measures
  has_many :paretos
  has_many :jobs

  # Indexes
  index({ uuid: 1 }, unique: true)
  index({ id: 1 }, unique: true)
  index(name: 1)
  index(created_at: 1)
  index(updated_at: -1)
  index(project_id: 1)
  index(uuid: 1, download_status: 1)

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  validates_attachment_content_type :seed_zip, content_type: %w(application/zip)

  # Callbacks
  after_create :verify_uuid
  before_destroy :remove_dependencies

  def self.status_states
    %w(na init queued started completed)
  end

  def start(no_delay, analysis_type = 'batch_run', options = {})
    defaults = { skip_init: false }
    options = defaults.merge(options)

    Rails.logger.info "calling start on #{analysis_type} with options #{options}"

    # TODO: need to also check if the workers have been initialized, if so, then skip
    unless options[:skip_init]
      Rails.logger.info("Queuing up analysis #{uuid}")
      self.save!

      # TODO: Remove the idea of initialing workers here. The cluster needs to be defined before running this method
      Rails.logger.info('Initializing workers in database')
      # initialize_workers(options)
    end

    Rails.logger.info("Starting #{analysis_type}")
    if no_delay
      Rails.logger.info("Running in foreground analysis for #{uuid} with #{analysis_type}")
      aj = jobs.new_job(id, analysis_type, jobs.length, options)
      self.save!
      reload
      abr = "Analysis::#{analysis_type.camelize}".constantize.new(id, aj.id, options)
      abr.perform
    else
      Rails.logger.info("Running in delayed jobs analysis for #{uuid} with #{analysis_type}")
      aj = jobs.new_job(id, analysis_type, jobs.length, options)
      job = Delayed::Job.enqueue "Analysis::#{analysis_type.camelize}".constantize.new(id, aj.id, options), queue: 'analysis'
      aj.delayed_job_id = job.id
      aj.save!

      self.save!
      reload
    end
  end

  # Options take the form of?
  # Run the analysis
  def run_analysis(no_delay = false, analysis_type = 'batch_run', options = {})
    defaults = { allow_multiple_jobs: false }
    options = defaults.merge(options)

    # check if there is already an analysis in the queue (this needs to move to the analysis class)
    # there is no reason why more than one analyses can be queued at the same time.
    Rails.logger.info("called run_analysis analysis of type #{analysis_type} with options: #{options}")

    dj_ids = jobs.map { |v| v[:delayed_job_ids] }
    Rails.logger.info "Delayed Job ids are #{dj_ids}"
    if options[:allow_multiple_jobs]
      # go ahead and submit the job no matter what
      start(no_delay, analysis_type, options)

      return [true]
    elsif delayed_job_ids.empty? || !Delayed::Job.where(:_id.in => delayed_job_ids).exists?
      start(no_delay, analysis_type, options)

      return [true]
    else
      Rails.logger.info "Analysis is already queued with #{dj} or option was not passed to allow multiple analyses"
      return [false, 'An analysis is already queued']
    end
  end

  def stop_analysis
    logger.info('attempting to stop analysis')

    self.run_flag = false
    # The ensure block will clean up the jobs and save the statuses

    # jobs.each do |j|
    #   unless j.status == 'completed'
    #     j.status = 'completed'
    #     j.end_time = Time.new
    #     j.status_message = 'canceled by user'
    #     j.save
    #   end
    # end

    [self.save!, errors]
  end

  # Method that pulls out the variables from the uploaded problem/analysis JSON.
  def pull_out_os_variables
    pat_json = false
    # get the measures first
    Rails.logger.info('pulling out openstudio measures')
    # note the measures first
    if self['problem'] && self['problem']['workflow']
      Rails.logger.info('found a problem and workflow')
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
      Rails.logger.error('Appears to be a PAT JSON formatted file, pulling variables out of metadata for now')
      if os_metadata && os_metadata['variables']
        os_metadata['variables'].each do |variable|
          var = Variable.create_from_os_json(id, variable)
        end
      end
    end

    # pull out the output variables
    if output_variables
      output_variables.each do |variable|
        Rails.logger.info "Saving off output variables: #{variable}"
        var = Variable.create_output_variable(id, variable)
      end
    end

    self.save!
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

    # TODO: do we want to filter this on only completed simulations--i don't think so anymore.
    #   old query .where({download_status: 'completed', status: 'completed'})
    var_ids = data_points.map_reduce(map, reduce).out(inline: true)
    var_ids.each do |var|
      v = Variable.where(uuid: var['_id']).only(:name).first
      # TODO: can we delete the gsub'ing -- as i think the v.name is always the machine name now
      mappings[var['_id']] = v.name.tr(' ', '_') if v
    end
    Rails.logger.info "Mappings created in #{Time.now - start}" # with the values of: #{mappings}"

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
    jobs.order_by(:index.asc).map { |j| { analysis_type: j.analysis_type, status: j.status } }
  end

  # Return the last job's status for the analysis
  def status
    j = jobs.last
    if j && j.status
      return j.status
    else
      return 'unknown'
    end
  end

  def analysis_types
    jobs.order_by(:index.asc).map(&:analysis_type)
  end

  def analysis_type
    j = jobs.last
    if j && j.analysis_type
      return j.analysis_type
    else
      return 'unknown'
    end
  end

  def start_time
    j = jobs.first

    return j.start_time if j

    nil
  end

  def end_time
    j = jobs.last
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

  # TODO: Make these :dependent_destroys
  def remove_dependencies
    logger.info("Found #{data_points.size} records")
    data_points.each do |record|
      logger.info("removing #{record.id}")
      record.destroy
    end

    logger.info("Found #{algorithms.size} records")
    algorithms.each do |record|
      logger.info("removing #{record.id}")
      record.destroy
    end

    logger.info("Found #{measures.size} records")
    if measures
      measures.each do |record|
        logger.info("removing #{record.id}")
        record.destroy
      end
    end

    logger.info("Found #{variables.size} records")
    if variables
      variables.each do |record|
        logger.info("removing #{record.id}")
        record.destroy
      end
    end

    # delete any delayed jobs items
    delayed_job_ids.each do |djid|
      next unless djid
      dj = Delayed::Job.find(djid)
      dj.delete unless dj.nil?
    end

    jobs.each do |r|
      logger.info("removing #{r.id}")
      r.destroy
    end
  end

  def verify_uuid
    self.uuid = id if uuid.nil?
    self.save!
  end
end
