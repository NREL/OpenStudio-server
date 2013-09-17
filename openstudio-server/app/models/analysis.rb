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
                            :path => ":rails_root/public/assets/analyses/:id/:style/:basename.:extension"

  # validations
  #validates_format_of :uuid, :with => /[^0-]+/

  #validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  before_destroy :remove_dependencies


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

    self.status = 'running'
    self.run_flag = true

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

=begin
    # I think we can do this with mongoid at the moment... no reason to make this complicated until we have to send
    # the data to the worker nodes
    @r.command() do
      %Q{
         master_ip = read.table("master_ip_address", as.is = 1)
         ip <- character(length=nrow(master_ip))
         ip[1] = master_ip[1,]
         mongo <- mongoDbConnect("openstudio_server_development", host=ip, port=27017)
         output <- dbRemoveQuery(mongo,"control","{_id:1}")
         if (output != "ok"){stop(options("show.error.messages"="TRUE"),"cannot remove control flag in Mongo")}
         input <- dbInsertDocument(mongo,"control",'{"_id":1,"run":"TRUE"}')
         if (input != "ok"){stop(options("show.error.messages"="TRUE"),"cannot insert control flag in Mongo")}
         flag <- dbGetQuery(mongo,"control",'{"_id":1}')
         if (flag["run"] != "TRUE" ){stop(options("show.error.messages"="TRUE"),"run flag is not TRUE")}
         dbDisconnect(mongo)
      }
    end
=end


    puts "ready to run ="
    puts @r.converse('flag["run"]')

    @r.command() do
      %Q{
        #read in ipaddresses
        #ips = read.table("hosts_slave_file.sh", as.is = 1)
        ips = read.table("worker_ips", as.is = 1)

        #create character list of ipaddresses
        b <- character(length=nrow(ips))
        for(i in 1:nrow(ips)) {b[i] = ips[i,]}
        master_ip = read.table("master_ip_address", as.is = 1)
        ip <- character(length=nrow(master_ip))
        ip[1] = master_ip[1,]
           #sfInit(parallel=TRUE, type="SOCK", socketHosts=rep("localhost",4))
           sfInit(parallel=TRUE, type="SOCK", socketHosts=b)
           sfLibrary(RMongo)

           f <- function(x){
             #library(RMongo)
             mongo <- mongoDbConnect("openstudio_server_development", host=ip, port=27017)
             flag <- dbGetQuery(mongo,"control",'{"_id":1}')
             if (flag["run"] == "FALSE" ){stop(options("show.error.messages"="TRUE"),"run flag is not TRUE")}
             dbDisconnect(mongo)
             y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /mnt/openstudio/SimulateDataPoint.rb -d /mnt/openstudio/analysis/data_point_",x," -r AWS",sep="")
             z <- system(y,intern=TRUE)
             j <- length(z)
             z}

           sfExport("f")
           sfExport("ip")
           dpts = read.table("data_point_uuids.txt", as.is = 1)
           datapoints <- character(length=nrow(dpts))
           for(i in 1:nrow(dpts)) {datapoints[i] = dpts[i,]}

           results <- sfLapply(datapoints,f)
           sfStop()
        }
    end
    puts "results ="
    puts @r.converse('results')


    self.status = 'completed'
    self.save!
  end
  #handle_asynchronously :start_r_and_run_sample

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

  def initialize_workers
    # copy analysis.zip to all worker nodes


    # Copy uploaded files from server to worker after upload api,

  end

end
