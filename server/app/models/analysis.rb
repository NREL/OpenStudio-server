# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
  field :cli_debug, type: String, default: '--debug' # set default to --debug so CI tests pass
  field :cli_verbose, type: String, default: '--verbose' # set default to --verbose to CI tests pass
  field :initialize_worker_timeout, type: Integer, default: 28800 # set default to 8 hrs
  field :upload_results_timeout, type: Integer, default: 28800 # set default to 8 hrs
  field :run_workflow_timeout, type: Integer, default: 28800 # set default to 8 hrs
  field :download_zip, type: Boolean, default: true
  field :download_osm, type: Boolean, default: true
  field :download_osw, type: Boolean, default: true
  field :gemfile, type: Boolean, default: false
  field :download_reports, type: Boolean, default: true
  field :delete_simulation_dir, type: Boolean, default: true # delete the simulation directory in the workers after everything is done
  field :variable_display_name_choice, type: String, default: 'display_name'

  # Hash of the jobs to run for the analysis
  # field :jobs, type: Array, default: [] # very specific format
  # move the results into the jobs array
  field :results, type: Hash, default: {} # this was nil, can we have this be an empty hash? Check Measure Group JSONS!

  field :problem
  field :status_message, type: String, default: '' # the resulting message from the analysis
  field :output_variables, type: Array, default: [] # list of variable that are needed for output including objective functions
  field :os_metadata # don't define type, keep this flexible
  field :analysis_logs, type: Hash, default: {} # store the logs from the analysis init and finalize
  
  field :urbanopt, type: Boolean, default: false # is UrbanOpt run?
  field :urbanopt_variables, type: Array, default: [] #array of UrbanOpt variables
  field :feature_file, type: String, default: '' # name of UrbanOpt Feature_file.json file
  field :scenario_file, type: String, default: '' # name of UrbanOpt Scenario.csv file
  field :reopt, type: Boolean, default: false # is ReOpt run?
  field :reopt_type, type: String, default: '' # name of ReOpt run scenario or feature
  
  # Temp location for these vas
  field :samples, type: Integer
  field :significant_digits, type: Integer, default: 3

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
  #index(id: 1)
  index(name: 1)
  index(created_at: 1)
  index(updated_at: -1)
  index(project_id: 1)

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  validates_attachment_content_type :seed_zip, content_type: ['application/zip']

  # Callbacks
  before_create :set_uuid_from_id
  after_create :verify_uuid
  before_destroy :queue_delete_files

  def self.status_states
    ['na', 'init', 'queued', 'started', 'post-processing', 'completed']
  end

  # FIXME: analysis_type is somewhat ambiguous here, as it's argument to this method and also a class method name
  def start(no_delay, analysis_type = 'batch_run', options = {})
    logger.debug "analysis.start enter"
    defaults = { skip_init: false }
    options = defaults.merge(options)

    logger.info "Calling start on #{analysis_type} with options #{options}"

    unless options[:skip_init]
      logger.info("Queuing up analysis #{uuid}")
      save!
    end

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
        Resque.enqueue(ResqueJobs::InitializeAnalysis, analysis_type, id, aj.id, options)
        aj.delayed_job_id = nil
      else
        raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
      end
      aj.save!

      save!
      reload
    end
    logger.debug "analysis.start leave"
  end

  # Options take the form of?
  # Run the analysis
  def run_analysis(no_delay = false, analysis_type = 'batch_run', options = {})
    logger.debug "analysis.run_analysis enter"
    defaults = {}
    options = defaults.merge(options)

    # check if there is already an analysis in the queue (this needs to move to the analysis class)
    # there is no reason why more than one analyses can be queued at the same time.
    logger.info("called run_analysis analysis of type #{analysis_type} with options: #{options}")

    start(no_delay, analysis_type, options)
    logger.debug "analysis.run_analysis leave"
    [true]
  end

  def stop_analysis
    logger.info('attempting to stop analysis')

    self.run_flag = false

    jobs.each do |j|
      unless j.status == 'completed'
        j.status = 'completed'
        j.end_time = Time.new
        j.status_message = 'datapoint canceled'
        j.save!
      end
    end

    # Remove all the queued background jobs for this analysis
    data_points.where(status: 'queued').each(&:set_canceled_state)

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
    output_variables&.each do |variable|
      logger.debug "Saving off output variables: #{variable}"
      var = Variable.create_output_variable(id, variable)
    end

    save!
  end

  # Method that pulls out the urbanopt variables from the uploaded problem/analysis JSON.
  def pull_out_urbanopt_variables
    pat_json = false
    # get the measures first
    logger.info('pull_out_urbanopt_variables')
    # note the measures first
    if self['urbanopt_variables']
      logger.info('found urbanopt_variables')
      self['urbanopt_variables'].each do |uo_var|
        uo_var['uuid'] = nil if !UUID.validate(uo_var['uuid'])
        var = Variable.where(analysis_id: self.id, uuid: uo_var['uuid']).first
        if var
          raise "UrbanOpt Variable already exists for '#{var.name}' : '#{var.uuid}'"
        else
          logger.info("Adding a new UrbanOpt variable/argument named: '#{uo_var['name']}' with UUID '#{uo_var['uuid']}'") if self.cli_debug == '--debug'
          var = Variable.find_or_create_by(analysis_id: self.id, uuid: uo_var['uuid'])
          logger.info("Created Var: #{var.to_json}") if self.cli_debug == '--debug'
          exclude_fields = ['uuid', 'type', 'argument', 'uncertainty_description']
          uo_var.each do |k, v|
            var[k] = v unless exclude_fields.include? k
            var.perturbable = v if k == 'variable'
            if var.perturbable
              var.export = true
              var.visualize = true
              var.uo_variable = true #set this flag to true since its an urbanopt variable
            end
            # if the variable has an uncertainty description, then it needs to be flagged
            # as a perturbable (or pivot) variable
            if k == 'uncertainty_description'
              # need to flatten this
              var['uncertainty_type'] = v['type'] if v['type']
              if v['attributes']
                v['attributes'].each do |attribute|
                  # grab the name of the attribute to append the
                  # other characteristics
                  attribute['name'] ? att_name = attribute['name'] : att_name = nil
                  next unless att_name

                  attribute.each do |k2, v2|
                    exclude_fields_2 = ['uuid', 'version_uuid']
                    var["#{att_name}_#{k2}"] = v2 unless exclude_fields_2.include? k2
                  end
                end
              end
            end
      
          end

          logger.info("Updated Var: #{var.to_json}") if self.cli_debug == '--debug'
          var.save!
        end

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
    page_no = page_no.presence || 1
    logger.debug("search: #{search}, status: #{status}, page: #{page_no}, view_all: #{view_all}")

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
    logger.debug "analysis.status enter"
    j = jobs_status
    if j
      begin
        s = j.last[:status]
        # in environments using Resque, we allow finalization script to run ('post-processing') and do not consider analysis "completed"
        # until after finalization script step completes ('post-processing completed').
        if Rails.application.config.job_manager == :resque
          if s == 'completed'
            return 'post-processing'
          #   job status is updated to post-processing completed
          elsif s == 'post-processing finished'
            return 'completed'
          end
        end
        # if resque env -specific checks above didn't trigger return, proceed as usual
        return s
      rescue StandardError
        'unknown'
      end
    else
      return 'unknown'
    end
  end

  # update the job status to indicate that postprocessing is complete.
  # used from finalize method which is only called for environments using resque
  def complete_postprocessing!
    logger.debug "analysis.complete_postprocessing enter"
    raise 'Post-processing should only happen in environments that use Resque for job management.' unless Rails.application.config.job_manager == :resque

    job = jobs.order_by(:index.asc).last
    raise "Attempt to complete postprocessing for job with status '#{job.status}'.  Only permitted for status 'completed'." unless job.status == 'completed'

    job.status = 'post-processing finished'
    job.save!
    logger.debug "analysis.complete_postprocessing leave"
  rescue Exception => e
    logger.error e
  end

  # Return the last job's status message
  def job_status_message
    j = jobs_status
    if j
      begin
        return j.last[:status_message]
      rescue StandardError
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
    if j&.analysis_type
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

  # path to analysis in osdata volume - this is used on web node by resque init and finalize  analysis jobs
  def shared_directory_path
    "#{APP_CONFIG['server_asset_path']}/analyses/#{id}"
  end

  # Unpack analysis.zip into the osdata volume for use by background and web
  # specific usecase is to run analysis initialization and finalization scripts.
  # currently only used with Resque, as it's called by ResqueJobs::InitializeAnalysis job
  # runs on web node

  # The method call below is failing on windows due to ruby bindings issue. see https://github.com/NREL/OpenStudio/issues/3942
  # This is local function for workaround until that is resolved
  # OpenStudio::Workflow.extract_archive(download_file, analysis_dir)
  def extract_archive(archive_filename, destination, overwrite = true)
    ::Zip.sort_entries = true
    Zip::File.open(archive_filename) do |zf|
      zf.each do |f|
        logger.debug "Extracting #{f.name}"
        f_path = File.join(destination, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        if File.exist?(f_path)
          logger.debug "SKIPPED: #{f.name}, already existed."
        else
          zf.extract(f, f_path)
        end
      end
    end
  end

  def run_initialization
    #   unpack seed zip file into osdata
    #   run initialize.sh if present
    # Extract the zip
    extract_count = 0
    extract_max_count = 3
    logger.info 'Running analysis initialization scripts'
    logger.info "Extracting seed zip #{seed_zip.path} to #{shared_directory_path}"
    begin
      Timeout.timeout(3600) do # change to 1hr for large models
        extract_count += 1
        # The method call below is failing on windows due to ruby bindings issue. see https://github.com/NREL/OpenStudio/issues/3942
        # This is local function for workaround until that is resolved
        # OpenStudio::Workflow.extract_archive(download_file, analysis_dir)
        extract_archive(seed_zip.path, shared_directory_path)
      end
    rescue StandardError => e
      retry if extract_count < extract_max_count
      raise "Extraction of the seed.zip file failed #{extract_max_count} times with error #{e.message}"
    end
     
    run_script_with_args 'initialize'
    
  end

  # runs on web node
  def run_finalization
    logger.info 'Running analysis finalization scripts'
    run_script_with_args 'finalize'
    # update status to reflect that finalization has run
    complete_postprocessing!
  end

  protected

  # Queue up the task to delete all the files in the background
  def queue_delete_files
    analysis_dir = "#{APP_CONFIG['sim_root_path']}/analysis_#{id}"

    if analysis_dir =~ %r{^.*/analysis_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$}
      if Rails.application.config.job_manager == :delayed_job
        Delayed::Job.enqueue DjJobs::DeleteAnalysis.new(analysis_dir)
      elsif Rails.application.config.job_manager == :resque
        Resque.enqueue(ResqueJobs::DeleteAnalysis, analysis_dir)
        # AP: does this double delete indicate that we are duplicating the unzip??
        Resque.enqueue(ResqueJobs::DeleteAnalysis, shared_directory_path)
      else
        raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
      end
    else
      logger.error 'Will not delete analysis directory because it does not conform to pattern'
    end
  end

  def set_uuid_from_id
    self.uuid = id
  end
  
  def verify_uuid
    self.uuid = id if uuid.nil?
    save!
  end

  def run_script_with_args(script_name)
    dir_path = "#{shared_directory_path}/scripts/analysis"
    #  paths to check for args and script files
    args_path = "#{dir_path}/#{script_name}.args"
    script_path = "#{dir_path}/#{script_name}.sh"
    # if you change this path, also change it in analyses controller debug_log action
    log_path = "#{dir_path}/#{script_name}.log"

    logger.info "Checking for presence of args file at #{args_path}"
    args = nil
    if File.file? args_path
      args = Utility::Oss.load_args args_path
      logger.info " args loaded from file #{args_path}: #{args}"
    end

    logger.info "Checking for presence of script file at #{script_path}"
    if File.file? script_path
      # TODO: how long do we want to set timeout?
      # SCRIPT_PATH - path to where the scripts were extracted
      # HOST_URL - URL of the server
      # RAILS_ROOT - location of rails
      Utility::Oss.run_script(script_path, 4.hours, { 'SCRIPT_PATH' => dir_path, 'ANALYSIS_ID' => id, 'HOST_URL' => APP_CONFIG['os_server_host_url'], 'RAILS_ROOT' => Rails.root.to_s, 'ANALYSIS_DIRECTORY' => shared_directory_path }, args, logger, log_path)
    end
  ensure
    if File.exist? log_path
      analysis_logs[script_name] = File.read(log_path).lines
    end
  end
end
