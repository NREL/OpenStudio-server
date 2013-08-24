class Analysis
  include Mongoid::Document
  include Mongoid::Timestamps

  field :_id, :type => String, default: ->{ uuid || UUID.generate}
  field :version_uuid
  field :name, :type => String
  field :display_name, :type => String
  field :description, :type => String

  belongs_to :project

  has_many :data_points

  has_many :algorithms
  has_many :problems

  #validates_format_of :uuid, :with => /[^0-]+/

  def start_r_and_run_sample

    # determine which problem to run

    # add into delayed job
    require 'rserve/simpler'
    require 'uuid'

    #create an instance for R
    @r = Rserve::Simpler.new

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

  end
  handle_asynchronously :start_r_and_run_sample # :run_at => Proc.new { 10.seconds.from_now }

end
