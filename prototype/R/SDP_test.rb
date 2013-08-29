require 'rubygems'
require 'rserve/simpler'


#create an instance for R
@r = Rserve::Simpler.new
puts "Setting working directory ="
puts @r.converse('setwd("/data/prototype/R")')
puts "R working dir ="
puts @r.converse('getwd()')
puts "starting cluster and running"
@r.converse "library(snow)"
@r.converse "library(snowfall)"

@r.command() do
%Q{
  #read in ipaddresses
  ips = read.table("slave_info.sh", as.is = 1)
  #create character list of ipaddresses
  b <- character(length=nrow(ips))
  for(i in 1:nrow(ips)) {b[i] = ips[i,]}
        
  f <- function(x){ 
      y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /home/vagrant/SimulateDataPoint.rb -d ~/analysis/data_point_",x,sep="")
      z <- system(y,intern=TRUE)
      j <- length(z)
      z}
     
     #sfInit(parallel=TRUE, type="SOCK", socketHosts=rep("localhost",4))
     sfInit(parallel=TRUE, type="SOCK", socketHosts=b)
     sfExport("f")
     
     dpts = read.table("data_point_uuids.txt", as.is = 1)
     datapoints <- character(length=nrow(dpts))
     for(i in 1:nrow(dpts)) {datapoints[i] = dpts[i,]}
     
     results <- sfLapply(datapoints,f)
     sfStop()
  }
end
puts "results ="
puts @r.converse('results')


#puts b



