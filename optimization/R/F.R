function(x){
x1<-x[1]
x2<-x[2]
y <- paste("ruby F.rb",x1,x2)
z <- system(y,intern=TRUE)
j <- length(z)
as.numeric(z[j])}

function(x){
    x1<-x[1]
    x2<-x[2]
    x3<-x[3]
    y <- paste("ruby F.rb",x1,x2,x3)
    z <- system(y,intern=TRUE)
    j <- length(z)
    as.numeric(z[j])}

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

  f <- function(x){
    x1<-x[1]
    x2<-x[2]
    x3<-x[3]
    x4<-x[4]
    x5<-x[5]
    y <- paste("ruby F.rb",x1,x2,x3,x4,x5)
    z <- system(y,intern=TRUE)
    w <- numeric(2)
    j <- length(z)
    w[1] <- as.numeric(z[j-1])
    w[2] <- as.numeric(z[j])
    return(w)}