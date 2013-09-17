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
  field :status, :type => String # enum on the status of the analysis (queued, started, completed)

  belongs_to :project

  has_many :data_points
  has_many :algorithms
  has_many :problems

  has_mongoid_attached_file :seed_zip,
                            :url => "/assets/analyses/:id/:style/:basename.:extension",
                            :path => ":rails_root/public/assets/analyses/:id/:style/:basename.:extension" #todo: move this to /mnt/...

  # validations
  #validates_format_of :uuid, :with => /[^0-]+/

  #validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  before_destroy :remove_dependencies

  def initialize_workers
    # load in the master and worker information if it doesn't already exist

    # somehow check if this is a vagrant box
    ip_file = "/data/launch-instance/ip_address_vagrant"
    if File.exists?(ip_file)
      #
    else
      # try to find a different file in the
      ip_file = "/home/ubuntu/ip_addresses"
    end

    ips = File.read(ip_file).split("\n")
    ip_count = 0
    ips.each do |ip|
      cols = ip.split("|")
      ip_count += 1
      if ip_count == 1
        sn = MasterNode.find_or_create_by(:ip_address => cols[0])
        sn.save!
      else
        wn = WorkerNode.find_or_create_by(:ip_address => cols[0])
        wn.user = cols[1]
        wn.password = cols[2]
        wn.cores = cols[3]
        wn.save!

        logger.info("Worker node #{wn.inspect}")
      end
    end

    copy_data_to_workers()
  end

  def start_r_and_run_sample
    # TODO: double check if the anlaysis is running, if so, then don't run

    # determine which problem to run

    # add into delayed job
    require 'rserve/simpler'
    require 'uuid'

    #create an instance for R

    @r = Rserve::Simpler.new
    puts "Setting working directory"
    @r.converse('setwd("/mnt/openstudio")')
    wd = @r.converse('getwd()')
    puts "R working dir = #{wd}"
    puts "starting cluster and running"
    @r.converse "library(snow)"
    @r.converse "library(snowfall)"
    @r.converse "library(RMongo)"

    self.status = 'started'
    self.run_flag = true
    self.save!

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = MasterNode.first.ip_address

    # I think we can do this with mongoid at the moment... no reason to make this complicated until we have to send
    # the data to the worker nodes
    @r.command() do
      %Q{
        ip <- "#{master_ip}"
        print(ip)
        #mongo <- mongoDbConnect("openstudio_server_development", host=ip, port=27017)
        #output <- dbRemoveQuery(mongo,"control","{_id:1}")
        #if (output != "ok"){stop(options("show.error.messages"="TRUE"),"cannot remove control flag in Mongo")}
        #input <- dbInsertDocument(mongo,"control",'{"_id":1,"run":"TRUE"}')
        #if (input != "ok"){stop(options("show.error.messages"="TRUE"),"cannot insert control flag in Mongo")}
        #flag <- dbGetQuery(mongo,"control",'{"_id":1}')
        #if (flag["run"] != "TRUE" ){stop(options("show.error.messages"="TRUE"),"run flag is not TRUE")}
        #dbDisconnect(mongo)

        #test the query of getting the run_flag
        mongo <- mongoDbConnect("openstudio_server_development", host=ip, port=27017)
        flag <- dbGetQuery(mongo, "analyses", '{_id:"#{self.id}"}')
        print(flag)

        print(flag["run_flag"])
        if (flag["run_flag"] == "true"  ){
          print("flag is set to true!")
        }
      }
    end

    # get the worker ips
    worker_ips_hash = {}
    worker_ips_hash[:worker_ips] = []

    WorkerNode.all.each do |wn|
      (1..wn.cores).each { |i| worker_ips_hash[:worker_ips] << wn.ip_address}
    end
    logger.info("worker ip hash: #{worker_ips_hash}")

    # update the status of all the datapoints and create a hash map
    data_points_hash = {}
    data_points_hash[:data_points] = []
    self.data_points.all.each do |dp|
      dp.status = 'initialized'
      data_points_hash[:data_points] << dp.uuid
    end
    #data_points_hash = {data_points: self.data_points.all.map { |dp| dp.uuid }}
    logger.info(data_points_hash)

    # verify that the files are in the right place

    # get the data over to the worker nodes


    @r.command(ips: worker_ips_hash.to_dataframe, dps: data_points_hash.to_dataframe) do
      %Q{
        sfInit(parallel=TRUE, type="SOCK", socketHosts=ips[,1])
        sfLibrary(RMongo)

        f <- function(x){
          mongo <- mongoDbConnect("openstudio_server_development", host="#{master_ip}", port=27017)
          flag <- dbGetQuery(mongo, "analyses", '{_id:"#{self.id}"}')
          if (flag["run_flag"] == "false" ){
            stop(options("show.error.messages"="TRUE"),"run flag is not TRUE")
          }
          dbDisconnect(mongo)

          y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /mnt/openstudio/SimulateDataPoint.rb -d /mnt/openstudio/analysis/data_point_",x," -r AWS",sep="")
          #y <- "sleep 1; echo hello"
          z <- system(y,intern=TRUE)
          j <- length(z)
          z
        }

        sfExport("f")
        print(dps)

        results <- sfLapply(dps[,1],f)
        sfStop()
      }
    end

    #self.r_log = @r.converse(messages)

    self.status = 'completed'
    self.save!
  end
  handle_asynchronously :start_r_and_run_sample

  def stop_analysis
    logger.info("stopping analysis")
    self.run_flag = false
    self.status = 'completed'
    self.save!
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

    logger.info("Found #{self.problems.size} records")
    self.problems.each do |record|
      logger.info("removing #{record.id}")
      record.destroy
    end
  end

  private

  # copy the zip file over the various workers and extract the file.
  # if the file already exists, then it will overwrite the file
  # TODO verify the behaviour of the zip extraction on top of an already existing analysis.
  def copy_data_to_workers
    # copy the datafiles over to the worker nodes
    WorkerNode.all.each do |wn|
      Net::SSH.start(wn.ip_address, wn.user, :password => wn.password) do |session|
        logger.info(self.inspect)
        session.scp.upload!(self.seed_zip.path, "/mnt/openstudio/")

        session.exec!( "cd /mnt/openstudio && unzip -o #{self.seed_zip_file_name}" ) do |channel, stream, data|
          logger.info(data)
        end
        session.loop

      end
    end
  end

  def download_data_from_workers

  end


end
