require 'rubygems'
require 'rserve/simpler'

#create an instance for R
@r = Rserve::Simpler.new
puts "Setting working directory ="
puts @r.converse('setwd("/home/ubuntu/")')
puts "R working dir ="
puts @r.converse('getwd()')
puts "starting cluster and running"
@r.converse "library(snow)"
@r.converse "library(snowfall)"
@r.converse "library(RMongo)"

#set run flag to true
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
puts "ready to run ="
puts @r.converse('flag["run"]')

@r.command() do
%Q{
  #read in ipaddresses
  ips = read.table("hosts_slave_file.sh", as.is = 1)
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
       y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /home/ubuntu/SimulateDataPoint.rb -d ~/analysis/data_point_",x,sep="")
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


#puts b



