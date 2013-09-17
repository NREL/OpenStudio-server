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

    puts "going to run the analysis now"

    # get the worker ips
    worker_ips_hash = {worker_ips: WorkerNode.all.map{|v| v.ip_address} * 4}
    puts worker_ips_hash

    data_points_hash = {data_points: self.data_points.all.map { |dp| dp.uuid }}
    puts data_points_hash

    # verify that the files are in the right place

    # get the data over to the worker nodes


    @r.command(ips: worker_ips_hash.to_dataframe, dps: data_points_hash.to_dataframe) do
      %Q{
        #read in ipaddresses
        master_ip = "#{master_ip}"
        print(master_ip)
        print(ips)
        print(ips["worker_ips"])

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
        #sfExport("master_ip") # I dont' think i need to do this because the text is interpretted first... right?
        print(dps)

        results <- sfLapply(dps[,1],f)
        sfStop()
      }
    end

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

  def initialize_workers
    # copy analysis.zip to all worker nodes


    # Copy uploaded files from server to worker after upload api,

  end

end
