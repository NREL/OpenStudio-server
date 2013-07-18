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
  if (is.list(x)==TRUE){x <- unlist(x)}
  w <- x[1]
  for(i in 2:length(x)){w <- paste(w,x[i])}
  u <- uuid()
  name <- paste("uuids.json",sep="")
  dname <- paste("uuids",sep="")
  dir.create(dname)
  y1 <- paste(dname,"/",name,sep="")
  y <- paste("echo",u,">>",y1)
  z <- system(y)
  as.numeric(u)
}

library(snowfall)
sfInit(parallel=TRUE, type="SOCK", socketHosts=c(rep("localhost",2), rep("192.168.33.11",4)))
sfExport("uuid")

results_d <- sfLapply(rep(1:100000),f)


sfStop()