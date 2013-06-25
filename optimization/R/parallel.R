## Set up the cluster
require("parallel");
nlocalcores = NULL; # Default to "Cores available - 1" if NULL.
if(is.null(nlocalcores)) { nlocalcores = detectCores() - 1; }
if(nlocalcores < 1) { print("Multiple cores unavailable! See code!!"); return()}
print(paste("Using ",nlocalcores,"cores for parallelized gradient computation."))
cl=makeCluster(nlocalcores);
print(cl)


# Now define a gradient function: both in serial and in parallel
mygr <- function(params, ...) {
  dp = cbind(rep(0,length(params)),diag(params * 1e-8)); # TINY finite difference
  Fout = apply(dp,2, function(x) fn(params + x,...));     # Serial 
  return((Fout[-1]-Fout[1])/diag(dp[,-1]));                # finite difference 
}

mypgr <- function(params, ...) { # Now use the cluster 
  dp = cbind(rep(0,length(params)),diag(params * 1e-8));   
  Fout = parCapply(cl, dp, function(x) fn(params + x,...)); # Parallel 
  return((Fout[-1]-Fout[1])/diag(dp[,-1]));                  #
}


## Lets try it out!
fr <- function(x, slow=FALSE) { ## Rosenbrock Banana function from optim() documentation.
  if(slow) { Sys.sleep(0.1); }   ## Modified to be a little slow, if needed.
  x1 <- x[1]
  x2 <- x[2]
  100 * (x2 - x1 * x1)^2 + (1 - x1)^2
}

grr <- function(x, slow=FALSE) { ## Gradient of 'fr'
  if(slow) { Sys.sleep(0.1); }   ## Modified to be a little slow, if needed.
  x1 <- x[1]
  x2 <- x[2]
  c(-400 * x1 * (x2 - x1 * x1) - 2 * (1 - x1),
    200 *      (x2 - x1 * x1))
}

## Make sure the nodes can see these functions & other objects as called by the optimizer
fn <- fr;  # A bit of a hack
clusterExport(cl, "fn");

# First, test our gradient approximation function mypgr
print( mypgr(c(-1.2,1)) - grr(c(-1.2,1)))

## Some test calls, following the examples in the optim() documentation
tic = Sys.time();
fit1 = optim(c(-1.2,1), fr, slow=FALSE);                          toc1=Sys.time()-tic
fit2 = optim(c(-1.2,1), fr, gr=grr, slow=FALSE, method="BFGS");   toc2=Sys.time()-tic-toc1
fit3 = optim(c(-1.2,1), fr, gr=mygr, slow=FALSE, method="BFGS");  toc3=Sys.time()-tic-toc1-toc2
fit4 = optim(c(-1.2,1), fr, gr=mypgr, slow=FALSE, method="BFGS"); toc4=Sys.time()-tic-toc1-toc2-toc3


## Now slow it down a bit
tic = Sys.time();
fit5 = optim(c(-1.2,1), fr, slow=TRUE);                           toc5=Sys.time()-tic
fit6 = optim(c(-1.2,1), fr, gr=grr, slow=TRUE, method="BFGS");    toc6=Sys.time()-tic-toc5
fit7 = optim(c(-1.2,1), fr, gr=mygr, slow=TRUE, method="BFGS");   toc7=Sys.time()-tic-toc5-toc6
fit8 = optim(c(-1.2,1), fr, gr=mypgr, slow=TRUE, method="BFGS");  toc8=Sys.time()-tic-toc5-toc6-toc7

print(cbind(fast=c(default=toc1,exact.gr=toc2,serial.gr=toc3,parallel.gr=toc4),
            slow=c(toc5,toc6,toc7,toc8)))