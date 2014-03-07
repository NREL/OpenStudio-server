vectorgrad <- function(func, x, method="one", eps=1e-4, cl=NULL){
    
    n <- length(x)     #number of variables in argument
    df <- rep(NA,n)
    
    if(method=="one"){
        if (n > 1){
          dp <- cbind(rep(0,n),diag(x*eps))
        } else {
          dp <- cbind(rep(0,n),(x*eps))
        }
        Fout <- parCapply(cl, dp, function(x1) func(x + x1))
        if (n > 1){
          df <- (Fout[-1] - Fout[1])/(diag(dp[,-1]))
        } else {
          df <- (Fout[-1] - Fout[1])/((dp[,-1]))
        }
        return(df)
    } else if(method=="two"){
        if (n > 1){
          dp <- cbind(diag(x*eps),diag(-x*eps))
        } else {
          dp <- cbind((x*eps),(-x*eps))
        }
        Fout <- parCapply(cl, dp, function(x1) func(x + x1))
        if (n > 1){
          df <- (Fout[(1:n)] - Fout[-(1:n)])/(2*diag(dp[,(1:n)]))
        } else {
          df <- (Fout[(1:n)] - Fout[-(1:n)])/(2*(dp[,(1:n)]))
        }
        return(df)
    } else if(method=="four"){
        if (n > 1){
          dp <- cbind(diag(-x*eps),diag(-2*x*eps))
          dp <- cbind(diag(x*eps),dp)
          dp <- cbind(diag(2*x*eps),dp)
        } else {
          dp <- cbind((-x*eps),(-2*x*eps))
          dp <- cbind((x*eps),dp)
          dp <- cbind((2*x*eps),dp)
        }
        Fout <- parCapply(cl, dp, function(x1) func(x + x1))
        if (n > 1){
          df <- (-1*Fout[(1:n)] + 8*Fout[((n+1):(2*n))] -8*Fout[((2*n+1):(3*n))] + Fout[((3*n+1):(4*n))])/(12*diag(dp[,((n+1):(2*n))]))
        } else {
          df <- (-1*Fout[(1:n)] + 8*Fout[((n+1):(2*n))] -8*Fout[((2*n+1):(3*n))] + Fout[((3*n+1):(4*n))])/(12*(dp[,((n+1):(2*n))]))
        }
        return(df)  
    }
}
