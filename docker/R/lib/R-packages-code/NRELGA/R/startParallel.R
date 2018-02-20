startParallel <- function(parallel = TRUE, numIslands = 4,...)
{
# Start parallel computing for GA package
  
  # if a cluster is provided as input argument use that cluster and exit
  if(any(class(parallel) == "cluster"))
    { 
      # check availability of parallel and doParallel (their dependencies, i.e. 
      # foreach and iterators, are specified as Depends on package DESCRIPTION file)
      #if(!all(requireNamespace("parallel", quietly = TRUE),
      #  requireNamespace("doMC", quietly = TRUE)))     
      #stop("packages 'parallel' and 'doMC' required for ISland parallelization!")
      #try this -BLB
      cl <- attr(parallel, "cluster")
      #cl <- parallel
      #parallel <- TRUE
      doMC::registerDoMC(cl,floor((attr(parallel, "cores") - numIslands)/numIslands))
      attr(parallel, "type") <- getDoParName()
      attr(parallel, "cores") <- getDoParWorkers()
      attr(parallel, "cluster") <- cl
      return(parallel)
  }
    
  # get the current number of cores available
  numCores <- parallel::detectCores()

  numCores <- as.integer(parallel)
  parallel <- TRUE 

  
  attr(parallel, "type") <- parallelType
  attr(parallel, "cores") <- numCores

   # multicore functionality on Unix-like systems
    cl <- parallel::makeCluster(numCores, type = "FORK")
    #change from numCores to numIslands -BLB
    doParallel::registerDoParallel(cl, cores = numIslands) 
    attr(parallel, "cluster") <- cl
  
  

  return(parallel)
}