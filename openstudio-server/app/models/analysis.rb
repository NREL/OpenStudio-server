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
  field :delayed_job_id # ObjectId
  field :status, :type => String # enum on the status of the analysis (queued, started, completed)
  field :analysis_output, :type => Array
  field :start_time, :type => DateTime
  field :end_time, :type => DateTime

  has_mongoid_attached_file :seed_zip,
                            :url => "/assets/analyses/:id/:style/:basename.:extension",
                            :path => ":rails_root/public/assets/analyses/:id/:style/:basename.:extension"

  # Relationships
  belongs_to :project
  has_many :data_points
  has_many :algorithms
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

    # load in the master and worker information if it doesn't already exist
    ip_file = "/home/ubuntu/ip_addresses"
    if !File.exists?(ip_file)
      ip_file = "/data/launch-instance/ip_addresses_vagrant" # somehow check if this is a vagrant box
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
        if !cols[6].nil? && cols[6].chomp == "true"
          wn.valid = true
        end
        wn.save!

        logger.info("Worker node #{wn.inspect}")
      end
    end

    # check if this fails
    copy_data_to_workers()
  end


  def start(no_delay, analysis_type='batch_run')
    # get the data points that are going to be run
    data_points_hash = {}
    data_points_hash[:data_points] = []
    self.data_points.all.each do |dp|
      dp.status = 'queued'
      dp.save!
      data_points_hash[:data_points] << dp.uuid
    end
    Rails.logger.info(data_points_hash)

    if no_delay
      abr = "Analysis::#{analysis_type.camelize}".constantize.new(self.id, data_points_hash)
      abr.perform
    else
      job = Delayed::Job.enqueue "Analysis::#{analysis_type.camelize}".constantize.new(self.id, data_points_hash), :queue => 'analysis'
      self.delayed_job_id = job.id
      self.save!
    end
  end

  def run_r_analysis(no_delay = false)
    # check if there is already an analysis in the queue (this needs to move to the analysis class)
    # there is no reason why more than one analyses can be queued at the same time.

    self.delayed_job_id.nil? ? dj = nil : dj = Delayed::Job.find(self.delayed_job_id)

    if !dj.nil? || self.status == "queued" || self.status == "started"
      logger.info("analysis is already queued with #{dj}")
      return [false, "An analysis is already queued"]
    else
      # NL: I would like to move this inside the queued analysis piece. I think
      # we could have an issue if there are many worker nodes and this method times out.
      self.start_time = Time.now

      logger.info("Initializing workers in database")
      self.initialize_workers

      logger.info("queuing up analysis #{@analysis}")
      self.status = 'queued'
      self.save!

      self.start(no_delay)

      return [true]
    end
  end

  def stop_analysis
    logger.info("stopping analysis")
    self.run_flag = false
    self.status = 'completed'
    self.save!
  end

  # copy back the results to the master node if they are finished
  def download_data_from_workers
    any_downloaded = false
    self.data_points.and({download_status: 'na'}, {status: 'completed'}).each do |dp|
      downloaded = dp.download_datapoint_from_worker
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

    # delete any delayed jobs items
    if !self.delayed_job_id.nil?
      dj = Delayed::Job.find(self.delayed_job_id)
      dj.delete unless dj.nil?
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
        session.scp.upload!(self.seed_zip.path, "/mnt/openstudio/")

        session.exec!("cd /mnt/openstudio && unzip -o #{self.seed_zip_file_name}") do |channel, stream, data|
          logger.info(data)
        end
        session.loop
      end
    end
  end


end
