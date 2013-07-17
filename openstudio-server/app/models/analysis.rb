class Analysis
  include Mongoid::Document

  field :uuid
  field :version_uuid
  field :name, :type => String
  field :display_name, :type => String
  field :description, :type => String

  belongs_to :project

  has_many :data_points

  has_many :algorithms
  has_many :problems


  def start_r_and_run_sample()

    # determine which problem to run

    # add into delayed job
    require 'rserve/simpler'

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

    @r.converse('b')


  end

end
