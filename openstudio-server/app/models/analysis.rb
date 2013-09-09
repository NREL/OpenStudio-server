class Analysis
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  field :uuid, :type => String
  field :_id, :type => String, default: ->{ uuid || UUID.generate}
  field :version_uuid
  field :name, :type => String
  field :display_name, :type => String
  field :description, :type => String
  field :status, :type => String # enum on the status of the analysis

  belongs_to :project

  has_many :data_points
  has_many :algorithms
  has_many :problems

  has_mongoid_attached_file :seed_zip,
                            :url  => "/assets/analyses/:id/:style/:basename.:extension",
                            :path => ":rails_root/public/assets/analyses/:id/:style/:basename.:extension"

  # validations
  #validates_format_of :uuid, :with => /[^0-]+/

  #validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  before_destroy :remove_dependencies


  def start_r_and_run_sample

    # determine which problem to run

    # add into delayed job
    require 'rserve/simpler'
    require 'uuid'

    #create an instance for R
    @r = Rserve::Simpler.new
    self.status = 'running'
    self.save!

    @r.command() do
      %Q{
        f <- function(x){
          x1<-x[1]
          x2<-x[2]
          z <- (x1-1)*(x1-1) + (x2-1)*(x2-1)
          as.numeric(z)}

          b<-optim(c(1.5,4),f,method='L-BFGS-B',lower=c(-5,-5), upper=c(5,5))
        }
    end


    out = @r.converse('b$par').to_ruby

    # for now just create the datapoints
    out.each do |value|
      datapoint = self.data_points.new
      datapoint.uuid = UUID.new().generate
      datapoint.name = "automatically generated from R #{datapoint.uuid}"
      datapoint['values'] = [ {"variable_index" => 0, "variable_uuid" => UUID.new().generate, "value" => value}]
      datapoint.save!
    end

    self.status = 'complete'
    self.save!

  end
  handle_asynchronously :start_r_and_run_sample # :run_at => Proc.new { 10.seconds.from_now }

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

end
