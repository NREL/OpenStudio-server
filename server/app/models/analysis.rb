class Analysis
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  require 'delayed_job_mongoid'

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :version_uuid
  field :name, :type => String
  field :display_name, :type => String
  field :description, :type => String
  field :run_flag, :type => Boolean
  field :delayed_job_ids, :type => Array, default: []
  field :status, :type => String
  field :analysis_type, :type => String
  field :start_time, :type => DateTime
  field :end_time, :type => DateTime
  field :results, :type => Hash, default: nil
  field :problem
  field :status_message, :type => String # the resulting message from the analysis
  field :output_variables, :type => Array, default: [] # list of variable that are needed for output including objective functions
  field :os_metadata # don't define type, keep this flexible
  field :use_shm, :type => Boolean, default: false #flag on whether or not to use SHM for analysis (impacts file uploading)

  # Temp location for these vas
  field :samples, :type => Integer

  has_mongoid_attached_file :seed_zip,
                            :url => "/assets/analyses/:id/:style/:basename.:extension",
                            :path => ":rails_root/public/assets/analyses/:id/:style/:basename.:extension"

  # Relationships
  belongs_to :project
  has_many :data_points
  has_many :algorithms
  has_many :variables # right now only having this a one-to-many (ideally this can go both ways)
  has_many :measures
  #has_many :problems

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({project_id: 1})
  index({uuid: 1, status: 1})
  index({uuid: 1, download_status: 1})

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  # validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  # Callbacks
  after_create :verify_uuid
  before_destroy :remove_dependencies

  # TODO: Move this into the compute node class and call this with delayed jobs if applicable
  def initialize_workers(options = {})

    # delete the master and workers and reload them everysingle time an analysis is initialized
    ComputeNode.delete_all

    Rails.logger.info "initializing workers"

    # load in the master and worker information if it doesn't already exist
    ip_file = "/home/ubuntu/ip_addresses"
    if !File.exists?(ip_file)
      ip_file = "/data/launch-instance/ip_addresses" # somehow check if this is a vagrant box -- RAILS ENV?
    end

    ips = File.read(ip_file).split("\n")
    ips.each do |ip|
      cols = ip.split("|")
      if cols[0] == "master" #TODO: eventually rename this from master to server. The database calls this server
        node = ComputeNode.find_or_create_by(node_type: "server", ip_address: cols[1])
        node.hostname = cols[2]
        node.cores = cols[3]
        node.user = cols[4]
        node.password = cols[5].chomp
        if options[:use_server_as_worker] && cols[6].chomp == "true"
          node.valid = true
        else
          node.valid = false
        end
        node.save!

        logger.info("Server node #{node.inspect}")
      elsif cols[0] == "worker"
        node = ComputeNode.find_or_create_by(node_type: "worker", ip_address: cols[1])
        node.hostname = cols[2]
        node.cores = cols[3]
        node.user = cols[4]
        node.password = cols[5].chomp
        node.valid = false
        if cols[6] && cols[6].chomp == "true"
          node.valid = true
        end
        node.save!

        logger.info("Worker node #{node.inspect}")
      end
    end

    # get server and worker characteristics
    ComputeNode.get_system_information

    # check if this fails
    ComputeNode.copy_data_to_workers(self)
  end

  def start(no_delay, analysis_type='batch_run', options = {})
    defaults = {skip_init: false, use_server_as_worker: false}
    options = defaults.merge(options)

    # TODO need to also check if the workers have been initialized, if so, then skip
    if !options[:skip_init]
      self.start_time = Time.now # this is the time it was queued, not starts
      self.end_time = nil
      Rails.logger.info("Initializing workers in database")
      self.initialize_workers(options)

      Rails.logger.info("Queuing up analysis #{self.uuid}")
      self.analysis_type = analysis_type
      self.status = 'queued'
      self.save!
    end

    Rails.logger.info("Starting #{analysis_type}")
    if no_delay
      Rails.logger.info("Running in foreground analysis for #{self.uuid} with #{analysis_type}")
      abr = "Analysis::#{analysis_type.camelize}".constantize.new(self.id, options)
      abr.perform
    else
      Rails.logger.info("Running in delayed jobs analysis for #{self.uuid} with #{analysis_type}")
      job = Delayed::Job.enqueue "Analysis::#{analysis_type.camelize}".constantize.new(self.id, options), :queue => 'analysis'
      self.delayed_job_ids << job.id
      self.save!
    end
  end

  def run_analysis(no_delay = false, analysis_type = 'batch_run', options = {})
    defaults = {allow_multiple_jobs: false}
    options = defaults.merge(options)

    # check if there is already an analysis in the queue (this needs to move to the analysis class)
    # there is no reason why more than one analyses can be queued at the same time.
    Rails.logger.info("called run_analysis analysis of type #{analysis_type} with options: #{options}")

    if options[:allow_multiple_jobs]
      # go ahead and submit the job no matter what
      self.start(no_delay, analysis_type, options)

      return [true]
      # TODO: need to test for each of these cases!
    elsif self.delayed_job_ids.empty? || !Delayed::Job.where(:_id.in => self.delayed_job_ids).exists? || self.status != "queued" || self.status != "started"
      self.start(no_delay, analysis_type, options)

      return [true]
    else
      Rails.logger.info("Analysis is already queued with #{dj} and option was not passed to allow multiple analyses")
      return [false, "An analysis is already queued"]
    end
  end

  def stop_analysis
    logger.info("attempting to stop analysis")
    # check if the project is running
    if self.status == "queued" || self.status == "started"
      self.run_flag = false
      self.status = 'completed'
      self.end_time = Time.now
      # TODO: add a flag that this was killed
    end

    [self.save!, self.errors]
  end

  def pull_out_os_variables
    pat_json = false
    # get the measures first
    Rails.logger.info("pulling out openstudio measures")
    # note the measures first
    if self['problem'] && self['problem']['workflow']
      Rails.logger.info("found a problem and workflow")
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
        if !pat_json
          new_measure = Measure.create_from_os_json(self.id, wf, pat_json)
        end
      end
    end

    if pat_json
      Rails.logger.error("Appears to be a PAT JSON formatted file, pulling variables out of metadata for now")
      if self.os_metadata && self.os_metadata['variables']
        self.os_metadata['variables'].each do |variable|
          var = Variable.create_from_os_json(self.id, variable)
        end
      end
    end

    self.save!
  end


  # Method goes through all the data_points in an analysis and finds all the input variables (set_variable_values)
  # It uses map/reduce putting the load on the database to do the unique check.
  # Result is a hash of ids and variable names in the form of:
  #   { "uuid": "variable_name", "uuid2": "variable_name_2"}
  # 2013-02-20: NL Moved to Analysis Model. Updated to use map/reduce.  This runs in 62.8ms on a smallish sized collection compared to 461ms on the
  # same collection
  def get_superset_of_input_variables

    mappings = {}
    start = Time.now

    map = %Q{
      function() {
        for (var key in this.set_variable_values) { emit(key, null); }
      }
    }

    reduce = %Q{
      function(key, nothing) { return null; }
    }

    # todo: do we want to filter this on only completed simulations--i don't think so anymore.
    #   old query .where({download_status: 'completed', status: 'completed'})
    var_ids = self.data_points.map_reduce(map, reduce).out(inline: true)
    var_ids.each do |var|
      v = Variable.where(uuid: var['_id']).only(:name).first
      # todo: can we delete the gsub'ing -- as i think the v.name is always the machine name now
      mappings[var['_id']] = v.name.gsub(" ", "_") if v
    end
    Rails.logger.info "Mappings created in #{Time.now - start}" #with the values of: #{mappings}"

    # sort before sending back
    Hash[mappings.sort_by {|_, v| v}]
  end

  # This returns a slighly different format compared to the method above.  This returs
  # all the result variables that are avaiable in the form:
  # {"air_handler_fan_efficiency_final"=>true, "air_handler_fan_efficiency_initial"=>true, ...
  def get_superset_of_result_variables
    mappings = {}
    start = Time.now

    map = %Q{
      function() {
        for (var key in this.results) { emit(key, null); }
      }
    }

    reduce = %Q{
      function(key, nothing) { return null; }
    }

    # todo: do we want to filter this on only completed simulations--i don't think so anymore.
    #   old query .where({download_status: 'completed', status: 'completed'})
    var_ids = self.data_points.map_reduce(map, reduce).out(inline: true)
    var_ids.each do |var|
      mappings[var['_id']] = true
    end
    Rails.logger.info "Result mappings created in #{Time.now - start}" #with the values of: #{mappings}"

    # sort before sending back
    Hash[mappings.sort]
  end


# copy back the results to the master node if they are finished
  def finalize_data_points
    any_downloaded = false
    self.data_points.and({download_status: 'na'}, {status: 'completed'}).each do |dp|
      downloaded = dp.finalize_data_points
      any_downloaded = any_downloaded || downloaded
    end
    return any_downloaded
  end

  def search(search, status)
    if search
      if status == 'all'
        self.data_points.where(:name => /#{search}/i)
      else
        self.data_points.where(:name => /#{search}/i, :status => status)
      end

    else
      if status == 'all'
        self.data_points
      else
        self.data_points.where(:status => status)
      end
    end
  end

  protected


  def remove_dependencies
    logger.info("Found #{self.data_points.size} records")
    self.data_points.each do |record|
      logger.info("removing #{record.id}")
      record.destroy
    end

    logger.info("Found #{self.algorithms.size} records")
    self.algorithms.each do |record|
      logger.info("removing #{record.id}")
      record.destroy
    end

    logger.info("Found #{self.measures.size} records")
    if self.measures
      self.measures.each do |record|
        logger.info("removing #{record.id}")
        record.destroy
      end
    end

    logger.info("Found #{self.variables.size} records")
    if self.variables
      self.variables.each do |record|
        logger.info("removing #{record.id}")
        record.destroy
      end
    end

    # delete any delayed jobs items
    if self.delayed_job_ids
      self.delayed_job_ids.each do |djid|
        dj = Delayed::Job.find(djid)
        dj.delete unless dj.nil?
      end
    end
  end

  def verify_uuid
    self.uuid = self.id if self.uuid.nil?
    self.save!
  end



end
