vectorgrad <- function(func, x, method="one", eps=1e-4, cl=NULL, debug=FALSE, lb=NULL, ub=NULL){
    
    n <- length(x)     #number of variables in argument
    df <- rep(NA,n)
    if (length(eps) == 1) {eps <- rep(eps,n)}
    if(length(eps) != n){print("length of EPS not equal length of X in gradient; using 1e-4");eps <- rep(1e-4,n)}
    if(length(ub) != 0){
      if (length(ub) == n)    
        {eps <- ifelse(x+eps>ub,ub-x,eps)}
      else
        {print("upper bound length not same as x")}
    }
    if(length(lb) != 0){
      if (length(lb) == n)    
        {eps <- ifelse(x-eps<lb,lb-x,eps)}
      else
        {print("lower bound length not same as x")}
    }
    
    if(method=="one"){
        if (n > 1){
          dp <- cbind(rep(0,n),diag((x+1)*eps))
        } else {
          dp <- cbind(rep(0,n),((x+1)*eps))
        }
        Fout <- parCapply(cl, dp, function(x1) func(x + x1))
        if (debug == TRUE) print(paste("Fout:",Fout))
        if (n > 1){
          df <- (Fout[-1] - Fout[1])/(diag(dp[,-1]))
        } else {
          df <- (Fout[-1] - Fout[1])/((dp[,-1]))
        }
        return(df)
    } else if(method=="two"){
        if (n > 1){
          dp <- cbind(diag((1)*eps),diag(-(1)*eps))
        } else {
          dp <- cbind(((1)*eps),(-(1)*eps))
        }
        Fout <- parCapply(cl, dp, function(x1) func(x + x1))
		if (is.numeric(Fout) == FALSE) {
		  if (debug == TRUE) print("Fout is not numeric")
		  Fout <- as.numeric(Fout) 
		}
        if (debug == TRUE) print(paste("Fout:",Fout))
        if (n > 1){
          if (debug == TRUE) print(paste("diag(dp):",diag(dp[,(1:n)])))
          diag(dp[,(1:n)]) <- replace(diag(dp[,(1:n)]), diag(dp[,(1:n)])==0.0, 1e-16)
          if (debug == TRUE) print(paste("diag(dp):",diag(dp[,(1:n)])))
        } else {
          if (debug == TRUE) print(paste("(dp):",dp[,(1:n)]))
          dp[,(1:n)] <- replace(dp[,(1:n)], dp[,(1:n)]==0.0, 1e-16)
          if (debug == TRUE) print(paste("(dp):",dp[,(1:n)]))    
        }
        if (n > 1){
          df <- (Fout[(1:n)] - Fout[-(1:n)])/(2*diag(dp[,(1:n)]))
        } else {
          df <- (Fout[(1:n)] - Fout[-(1:n)])/(2*(dp[,(1:n)]))
        }
        if (debug == TRUE) print(paste("df:",df))
        df <- replace(df, df==Inf, 1e16)
        df <- replace(df, df==NaN, 1e16)
        if (debug == TRUE) print(paste("df:",df))
        return(df)
    } else if(method=="four"){
        if (n > 1){
          dp <- cbind(diag(-(x+1)*eps),diag(-2*(x+1)*eps))
          dp <- cbind(diag((x+1)*eps),dp)
          dp <- cbind(diag(2*(x+1)*eps),dp)
        } else {
          dp <- cbind((-(x+1)*eps),(-2*(x+1)*eps))
          dp <- cbind(((x+1)*eps),dp)
          dp <- cbind((2*(x+1)*eps),dp)
        }
        Fout <- parCapply(cl, dp, function(x1) func(x + x1))
        if (debug == TRUE) print(paste("Fout:",Fout))
        if (n > 1){
          df <- (-1*Fout[(1:n)] + 8*Fout[((n+1):(2*n))] -8*Fout[((2*n+1):(3*n))] + Fout[((3*n+1):(4*n))])/(12*diag(dp[,((n+1):(2*n))]))
        } else {
          df <- (-1*Fout[(1:n)] + 8*Fout[((n+1):(2*n))] -8*Fout[((2*n+1):(3*n))] + Fout[((3*n+1):(4*n))])/(12*(dp[,((n+1):(2*n))]))
        }
        return(df)  
    }
}
