vectorgrad <- function(func, x, method="one", eps=1e-4, cl=NULL){

  n <- length(x)	 #number of variables in argument
  df <- rep(NA,n)

  if(method=="one"){
    f <- func(x)
    temp <-matrix(rep(x,n), n, n)
    if (n > 1) {
      temp <-temp+diag(n)*eps
    } else {
      temp <-temp+(n)*eps    
    }
    gf <- function(x){(func(x)-f)/eps}
    demo<- parCapply(cl, temp, gf)
    df<-matrix(unlist(demo),1,n)
    return(df)
  } else if(method=="two"){
    temp <-matrix(rep(x,n), n, n)
    if (n > 1) {
      tempminus <-temp-diag(n)*eps
      tempplus <-temp+diag(n)*eps
    }  else {
      tempminus <-temp-(n)*eps
      tempplus <-temp+(n)*eps
    }
    fplus <- parCapply(cl, tempplus, func)
    fminus <- parCapply(cl, tempminus, func)
    demo<- (fplus - fminus)/(2*eps)
    df<-matrix(unlist(demo),1,n)
    return(df)
  } else if(method=="four"){
    temp <-matrix(rep(x,n), n, n)
    if (n > 1) {
      temp1 <-temp+diag(n)*2*eps
      temp2 <-temp+diag(n)*eps
      temp3 <-temp-diag(n)*eps
      temp4 <-temp-diag(n)*2*eps
    } else {  
      temp1 <-temp+(n)*2*eps
      temp2 <-temp+(n)*eps
      temp3 <-temp-(n)*eps
      temp4 <-temp-(n)*2*eps
    }
    f1 <- parCapply(cl, temp1, func)
    f2 <- parCapply(cl, temp2, func)
    f3 <- parCapply(cl, temp3, func)
    f4 <- parCapply(cl, temp4, func)    
    demo<- (-f1 + 8*f2 - 8*f3 + f4)/(12*eps)
    df<-matrix(unlist(demo),1,n)
    return(df)  
  }
}
