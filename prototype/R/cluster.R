library(snowfall)

f <- function(x){
          x1<-x[1]
          x2<-x[2]
          z <- (x1-1)*(x1-1) + (x2-1)*(x2-1)
          as.numeric(z)}


localOptions <- list(host = "localhost")
lnxOptions <- list(host = "192.168.33.11",
                   rscript = "/usr/bin/Rscript",
                   snowlib = "/usr/local/lib/R/site-library")


#sfSetMaxCPUs(100)
sfInit(parallel=TRUE, type="SOCK", socketHosts=c(rep("localhost",2), rep("192.168.33.11",4)))
sfExport("f")


library(lhs)
a <- randomLHS(1000000,2)

b <- matrix(0,nrow=1000000,ncol=2)
b[,1] <- a[,1] * 3.0
b[,2] <- a[,2] * 180

d <- split(b,rep(1:nrow(b),each = ncol(b)))
results_d <- sfLapply(d,f)

sfStop()
