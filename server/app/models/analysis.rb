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
  field :analysis_output, :type => Array
  field :start_time, :type => DateTime
  field :end_time, :type => DateTime
  field :problem
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
  index({name: 1}, unique: true)
  index({project_id: 1})
  index({uuid: 1, status: 1})
  index({uuid: 1, download_status: 1})

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  # validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  # Callbacks
  after_create :verify_uuid
  before_destroy :remove_dependencies

  def initialize_workers
    # delete the master and workers and reload them
    MasterNode.delete_all
    WorkerNode.delete_all

    Rails.logger.info "initializing workers"

    # load in the master and worker information if it doesn't already exist
    ip_file = "/home/ubuntu/ip_addresses"
    if !File.exists?(ip_file)
      ip_file = "/data/launch-instance/ip_addresses" # somehow check if this is a vagrant box -- RAILS ENV?
    end

    ips = File.read(ip_file).split("\n")
    ips.each do |ip|
      cols = ip.split("|")
      if cols[0] == "master"
        mn = MasterNode.find_or_create_by(:ip_address => cols[1])
        mn.hostname = cols[2]
        mn.cores = cols[3]
        mn.user = cols[4]
        mn.password = cols[5].chomp

        mn.save!

        logger.info("Master node #{mn.inspect}")
      elsif cols[0] == "worker"
        wn = WorkerNode.find_or_create_by(:ip_address => cols[1])
        wn.hostname = cols[2]
        wn.cores = cols[3]
        wn.user = cols[4]
        wn.password = cols[5].chomp
        wn.valid = false
        if cols[6] && cols[6].chomp == "true"
          wn.valid = true
        end
        wn.save!

        logger.info("Worker node #{wn.inspect}")
      end
    end

    # get server and worker characteristics
    get_system_information()

    # check if this fails
    copy_data_to_workers()
  end

  def start(no_delay, analysis_type='batch_run', options = {})
    defaults = {skip_init: false}
    options = defaults.merge(options)

    # TODO need to also check if the workers have been initialized, if so, then skip
    if !options[:skip_init]
      self.start_time = Time.now
      Rails.logger.info("Initializing workers in database")
      self.initialize_workers

      Rails.logger.info("Queuing up analysis #{self.uuid}")
      self.analysis_type = analysis_type
      self.status = 'queued'
      self.save!
    end

    Rails.logger.info("Starting #{analysis_type}")
    # NL: This hash should really be put into the analysis job.  Not sure why we need to create this here.
    data_points_array = []
    Rails.logger.info "Checking which datapoints to run"
    self.data_points.where(status: 'na', download_status: 'na').each do |dp|
      Rails.logger.info "Adding in #{dp.uuid}"
      dp.status = 'queued'
      dp.save!
      data_points_array << dp.uuid
    end

    options[:data_points] = data_points_array
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
    elsif self.delayed_job_ids.empty? || !Delayed::job.where(:_id.in => self.delayed_job_ids).exist? || self.status != "queued" || self.status != "started"
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

        # Currently the PAT format has measures and I plan on igorning them for now
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
      #Rails.logger.error("OpenStudio Metadata is: #{self.os_metadata}")
      if self.os_metadata && self.os_metadata['variables']
        self.os_metadata['variables'].each do |variable|
          var = Variable.create_from_os_json(self.id, variable)
        end
      end
    end

    self.save!
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

  private

  # copy the zip file over the various workers and extract the file.
  # if the file already exists, then it will overwrite the file
  # verify the behaviour of the zip extraction on top of an already existing analysis.
  def copy_data_to_workers
    # copy the datafiles over to the worker nodes
    WorkerNode.all.each do |wn|
      Net::SSH.start(wn.ip_address, wn.user, :password => wn.password) do |session|
        logger.info(self.inspect)
        if !use_shm
          upload_dir = "/mnt/openstudio"
          session.scp.upload!(self.seed_zip.path, "#{upload_dir}/")

          session.exec!("cd #{upload_dir} && unzip -o #{self.seed_zip_file_name}") do |channel, stream, data|
            logger.info(data)
          end
          session.loop
        else
          upload_dir = "/run/shm/openstudio"
          storage_dir = "/mnt/openstudio"
          session.exec!("rm -rf #{upload_dir}") do |channel, stream, data|
            Rails.logger.info(data)
          end
          session.loop

          session.exec!("rm -f #{storage_dir}/*.log && rm -rf #{storage_dir}/analysis") do |channel, stream, data|
            Rails.logger.info(data)
          end
          session.loop

          session.exec!("mkdir -p #{upload_dir}") do |channel, stream, data|
            Rails.logger.info(data)
          end
          session.loop

          session.scp.upload!(self.seed_zip.path, "#{upload_dir}")

          session.exec!("cd #{upload_dir} && unzip -o #{self.seed_zip_file_name} && chmod -R 775 #{upload_dir}") do |channel, stream, data|
            logger.info(data)
          end
          session.loop
        end
      end
    end
  end

  # During the initialization of each analysis, go to each system node and grab its information
  def get_system_information
    #if Rails.env == "development"  #eventually set this up to be the flag to switch between varying environments

    #end

    Socket.gethostname =~ /os-.*/ ? local_host = true : local_host = false

    # For now assume that there is only one master node
    mn = MasterNode.first
    if mn
      if local_host
        mn.ami_id = "Vagrant"
        mn.instance_id = "Vagrant"
      else # must be on amazon -- hit the api for the answers
        mn.ami_id = `curl -L http://169.254.169.254/latest/meta-data/ami-id`
        mn.instance_id = `curl -L http://169.254.169.254/latest/meta-data/instance-id`
      end
      mn.save!
    end

    # go through the worker node
    WorkerNode.all.each do |wn|
      if local_host
        wn.ami_id = "Vagrant"
        wn.instance_id = "Vagrant"
      else
        # have to communicate with the box to get the instance information (ideally this gets pushed from who knew)
        Net::SSH.start(wn.ip_address, wn.user, :password => wn.password) do |session|
          #Rails.logger.info(self.inspect)

          logger.info "Checking the configuration of the worker nodes"
          session.exec!("curl -L http://169.254.169.254/latest/meta-data/ami-id") do |channel, stream, data|
            Rails.logger.info("Worker node reported back #{data}")
            wn.ami_id = data
          end
          session.loop

          session.exec!("curl -L http://169.254.169.254/latest/meta-data/instance-id") do |channel, stream, data|
            Rails.logger.info("Worker node reported back #{data}")
            wn.instance_id = data
          end
          session.loop
        end
      end

      wn.save!
    end
  end
end
