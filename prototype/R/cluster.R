f <- function(x){
          x1<-x[1]
          x2<-x[2]
          z <- (x1-1)*(x1-1) + (x2-1)*(x2-1)
          as.numeric(z)}

library(snow)



cl <- makeSOCKcluster(c("localhost","localhost"))

     library(lhs)
     a <- randomLHS(10000000,2)

     b <- matrix(0,nrow=10000000,ncol=2)
     b[,1] <- a[,1] * 3.0
     b[,2] <- a[,2] * 180

    d <- split(b,rep(1:nrow(b),each = ncol(b)))
    results_d <- parLapply(cl,d,f)

    stopCluster(cl)