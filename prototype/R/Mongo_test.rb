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
  
  uuid <- function(uppercase=FALSE) {
    hex_digits <- c(as.character(0:9), letters[1:6])
    hex_digits <- if (uppercase) toupper(hex_digits) else hex_digits
    y_digits <- hex_digits[9:12]
    paste(
        paste0(sample(hex_digits, 8), collapse=''),
        paste0(sample(hex_digits, 4), collapse=''),
        paste0('4', sample(hex_digits, 2), collapse=''),
        paste0(sample(y_digits,1),
               sample(hex_digits, 2),
               collapse=''),
        paste0(sample(hex_digits, 12), collapse=''),
        sep='-')}
       
  f <- function(x){ 
      u <- uuid()
      name <- paste("uuids.json",sep="")
      dname <- paste("uuids",sep="")
      dir.create(dname)
      y1 <- paste(dname,"/",name,sep="")
      y <- paste("echo",x,u,">>",y1)
      z <- system(y) 
      y <- paste("ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ uuid.rb",x,u)
      z <- system(y,intern=TRUE)
      as.numeric(x)}
     
     sfInit(parallel=TRUE, type="SOCK", socketHosts=b)
     sfExport("uuid")   
     results <- sfLapply(rep(1:100000),f)
     sfStop()
  }
end
puts "results ="
puts @r.converse('results')


#puts b



