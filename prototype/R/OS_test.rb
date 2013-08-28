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
      y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /home/vagrant/OS_uuid.rb")
      z <- system(y,intern=TRUE)
      j <- length(z)
      z}
     
     #sfInit(parallel=TRUE, type="SOCK", socketHosts=rep("localhost",4))
     sfInit(parallel=TRUE, type="SOCK", socketHosts=b)
     setwd("/home/vagrant")
     results <- sfLapply(rep(1:10000),f)
     sfStop()
  }
end
puts "results ="
puts @r.converse('results')


#puts b



