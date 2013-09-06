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
   mongo <- mongoDbConnect("openstudio_server_development", host="192.168.33.10", port=27017)
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





