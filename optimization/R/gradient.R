mypgr <- function(params, ...) { # Now use the cluster 
    dp = cbind(rep(0,length(params)),diag(params * 1e-2));   
    Fout = parCapply(cl, dp, function(x) fnn(params + x,...)); # Parallel 
    return((Fout[-1]-Fout[1])/diag(dp[,-1]));                  #
}


mygr <- function(params, ...) {
    if(length(params)>1){
      dp = cbind(rep(0,length(params)),diag(params * 1e-2)); # TINY finite difference
    } else {dp=cbind(0,params*1e-2)}
    Fout = apply(dp,2, function(x) f(params + x,...));     # Serial 
    return((Fout[-1]-Fout[1])/diag(dp[,-1]));                # finite difference 
}

hnnpgr <- function(params, ...) { # Now use the cluster 
    dp = cbind(rep(0,length(params)),diag(params * 1e-1));   
    Fout = parCapply(cl, dp, function(x) hnn(params + x,...)); # Parallel 
    return((Fout[-1]-Fout[1])/diag(dp[,-1]));                  #
}


h <- function(x){
    x1<-x[1]
    x2<-x[2]
    x3<-x[3]
    x4<-x[4]
    x5<-x[5]
    y <- paste("ruby F.rb",x1,x2,x3,x4,x5)
    z <- system(y,intern=TRUE)
    j <- length(z)
    as.numeric(z[j-1])
    as.numeric(z[j])}


There were 50 or more warnings (use warnings() to see the first 50)
> stopCluster(cl)
> ## Set up the cluster
> require("parallel");
> nlocalcores = NULL; # Default to "Cores available - 1" if NULL.
> if(is.null(nlocalcores)) { nlocalcores = detectCores() - 1; }
> if(nlocalcores < 1) { print("Multiple cores unavailable! See code!!"); return()}
> print(paste("Using ",nlocalcores,"cores for parallelized gradient computation."))
[1] "Using  7 cores for parallelized gradient computation."
> cl=makeCluster(nlocalcores);
> print(cl)
socket cluster with 7 nodes on host ‘localhost’
> ## Make sure the nodes can see these functions & other objects as called by the optimizer
> hnn <- h;  # A bit of a hack
> clusterExport(cl, "hnn");
> fix(h)
> fix(hnn)
> fix(hnnpgr)
> optim(c(1.5,90,0.5,10,10),h,gr=hnnpgr,method='L-BFGS-B',lower=c(.5,0,0.1,1,1), upper=c(2.5,180,0.9,30,30))
$par
[1]  0.50000 90.30987  0.10000 30.00000 30.00000

$value
[1] 15.8

$counts
function gradient 
      28       28 

$convergence
[1] 0

$message
[1] "CONVERGENCE: REL_REDUCTION_OF_F <= FACTR*EPSMCH"
