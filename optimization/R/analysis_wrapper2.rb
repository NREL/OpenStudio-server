require 'rubygems'
require 'rserve/simpler'


#create an instance for R
@r = Rserve::Simpler.new

#install library for DEoptim (always)
#@r.converse "install.packages(DEoptim)"
#@r.converse "library(DEoptim)"
#@r.converse "library(foreach)"
#@r.converse "library(rgenoud)"
@r.converse "library(snow)"


@r.command() do
%Q{
  uuid <- function(uppercase=FALSE) {
     hex_digits <- c(as.character(0:9), letters[1:6])
     hex_digits <- if (uppercase) toupper(hex_digits) else hex_digits
     y_digits <- hex_digits[9:12]
     paste(
       paste0(sample(hex_digits, 8), collapse=''),
       paste0(sample(hex_digits, 4), collapse=''),
       paste0('4', sample(hex_digits, 3), collapse=''),
       paste0(sample(y_digits,1),
           sample(hex_digits, 3),
           collapse=''),
       paste0(sample(hex_digits, 12), collapse=''),
       sep='-')}
       
  f <- function(x){
      if (is.list(x)==TRUE){x <- unlist(x)}
      w <- x[1]
      for(i in 2:length(x)){w <- paste(w,x[i])}
      u <- uuid()
      name <- paste(u,".txt",sep="")
      dname <- paste("sims/",u,sep="")
      dir.create(dname)
      y1 <- paste(dname,"/",name,sep="")
      y <- paste("echo",w,">",y1)
      z <- shell(y)
      if(length(x)==5){y <- paste("ruby F5.rb ",u,sep="")}
      if(length(x)==4){y <- paste("ruby F4.rb ",u,sep="")}
      z <- system(y,intern=TRUE)
      j <- length(z)
    as.numeric(z[j])}
    
     cl <- makeCluster(8)
     clusterExport(cl,"uuid")
     
     library(lhs)
     a <- randomLHS(100,5)
    
     b <- matrix(0,nrow=100,ncol=5)
     b[,1] <- a[,1] * 3.0
     b[,2] <- a[,2] * 180
     b[,3] <- a[,3] * 1.0
     b[,4] <- a[,4] * 30
     b[,5] <- a[,5] * 30
    
    d <- split(b,rep(1:nrow(b),each = ncol(b)))
    results_d <- parLapply(cl,d,f)
    
    c <- matrix(0,nrow=100,ncol=4)
    c[,1]<-b[,1]
    c[,2]<-b[,2]
    c[,3]<-b[,3]
    c[,4]<-b[,4]
    e <- split(c,rep(1:nrow(c),each = ncol(c)))
   
    results_e <- parLapply(cl,e,f)

  }
end
puts "results ="
puts @r.converse('results')


#puts b



