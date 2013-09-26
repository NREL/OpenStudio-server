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
@r.converse "library(RMongo)"

#set run flag to true
@r.command() do
%Q{
   mongo <- mongoDbConnect("os_dev", host="192.168.33.10", port=27017)
   output <- dbRemoveQuery(mongo,"control","{_id:1}")
   if (output != "ok"){stop("cannot remove control flag in Mongo")}
   input <- dbInsertDocument(mongo,"control",'{"_id":1,"run":"TRUE"}')
   if (input != "ok"){stop("cannot insert control flag in Mongo")}
   flag <- dbGetQuery(mongo,"control",'{"_id":1}')
   if (flag["run"] != "TRUE" ){stop()}
   dbDisconnect(mongo)
}
end
puts "ready to run ="
puts @r.converse('flag["run"]')

@r.command() do
%Q{
  #read in ipaddresses
  ips = read.table("slave_info.sh", as.is = 1)
  #create character list of ipaddresses
  b <- character(length=nrow(ips))
  for(i in 1:nrow(ips)) {b[i] = ips[i,]}
             
     #sfInit(parallel=TRUE, type="SOCK", socketHosts=rep("localhost",4))
     sfInit(parallel=TRUE, type="SOCK", socketHosts=b)
     sfLibrary(RMongo)
     
     f <- function(x){ 
       mongo <- mongoDbConnect("os_dev", host="192.168.33.10", port=27017)
       flag <- dbGetQuery(mongo,"control",'{"_id":1}')
       if (flag["run"] != "TRUE" ){stop(options("show.error.messages"="TRUE"),"run flag is not TRUE")}
       dbDisconnect(mongo)
       y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /home/vagrant/OS_uuid.rb")
       z <- system(y,intern=TRUE)
       j <- length(z)
       z}
      
     sfExport("f")
     results <- sfLapply(rep(1:10000),f)
     sfStop()
  }
end
puts "results ="
puts @r.converse('results')


#puts b



