require 'rubygems'
require 'rserve/simpler'


#create an instance for R
@r = Rserve::Simpler.new

#install library for DEoptim (always)
#@r.converse "install.packages(DEoptim)"
#@r.converse "library(DEoptim)"
#@r.converse "library(foreach)"
#@r.converse "library(rgenoud)"
@r.converse "library(snowfall)"


@r.command() do
%Q{
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
      z <- shell(y) 
      y <- paste("ruby uuid.rb",x,u)
      z <- system(y,intern=TRUE)
      as.numeric(x)}
     
     library(snowfall)
     sfInit(parallel=TRUE, cpus=8, type="SOCK", socketHosts=rep("localhost",8))     
     sfExport("uuid")
        
     results <- sfLapply(rep(1:100),f)
     sfStop()
  }
end
puts "results ="
puts @r.converse('results')


#puts b



