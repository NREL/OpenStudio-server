f <- function(x){
          x1<-x[1]
          x2<-x[2]
          z <- (x1-1)*(x1-1) + (x2-1)*(x2-1)
          as.numeric(z)}

library(snow)

localOptions <- list(host = "localhost")
lnxOptions <- list(host = "192.168.33.11", snowlib = "/home/vagrant/R/x86_64-pc-linux-gnu-library/3.0")




cl <- makeCluster(c(rep(list(localOptions), 2), rep(list(lnxOptions),2)), type="SOCK")


     library(lhs)
     a <- randomLHS(1000000,2)

     b <- matrix(0,nrow=1000000,ncol=2)
     b[,1] <- a[,1] * 3.0
     b[,2] <- a[,2] * 180

    d <- split(b,rep(1:nrow(b),each = ncol(b)))
    results_d <- parLapply(cl,d,f)

    stopCluster(cl)

    cl <- makeCluster(c("localhost", "localhost", rep(list(lnxOptions),2)), type="SOCK")