require 'rubygems'
require 'rserve/simpler'


#create an instance for R
@r = Rserve::Simpler.new

#install library for DEoptim (always)
#@r.converse "install.packages(DEoptim)"
#@r.converse "library(DEoptim)"
#@r.converse "library(foreach)"
@r.converse "library(rgenoud)"
@r.converse "library(snow)"

#@r.converse "g<-function(x){5000/x[2] + 80 + 50*x[1] + 100}"
#a = @r.converse "optim(c(1.5,45),g,method='L-BFGS-B',lower=c(.5,30), upper=c(2.5,60))"
#a = @r.converse "DEoptim(g,lower=c(.5,30), upper=c(2.5,60),control=list(itermax=20,NP=20,parallelType=1))"
#puts "a = "
#puts a

@r.command() do
%Q{
  f <- function(x){
    x1<-x[1]
    x2<-x[2]
    x3<-x[3]
    x4<-x[4]
    x5<-x[5]
    y <- paste("ruby F.rb",x1,x2,x3,x4,x5)
    z <- system(y,intern=TRUE)
    j <- length(z)
    as.numeric(z[j])}
    
    #b<-optim(c(1.5,45),f,method='L-BFGS-B',lower=c(.5,30), upper=c(2.5,60))
    #b<-DEoptim(f,lower=c(.5,0.0,0.1,1.0,1.0), upper=c(2.5,180.0,0.9,30.0,30.0),control=list(itermax=20,NP=100,parallelType=1, storepopfrom=1, storepopfreq=1))
    c <- c("localhost","localhost","localhost","localhost","localhost","localhost","localhost","localhost")
    dom <- matrix(c(0.5,0,0.1,1,1,2.0,180,0.9,30,30), nrow=5,ncol=2)
    genoud(f,5,pop.size=100,Domains=dom,boundary.enforcement=2,print.level=2,cluster=c)
  }
end
puts "b ="
puts @r.converse('b')


#puts b



