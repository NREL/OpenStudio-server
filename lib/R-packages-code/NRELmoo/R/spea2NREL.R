#############################################################
# Strength Pareto Evolutionary Algorithm 2 in R
# Main Program Oct./12/2013
# Author: Prof. Ching-Shih (Vince) Tsou, Ph.D.
# Affiliation: Institute of Information and Decision Sciences
#              National Taipei College of Business
# Email: cstsou@mail.ntcb.edu.tw
#############################################################

# Arguments description
# fn               =  the objective functions
# varNo                 =  the dimension of decision space
# objDim                =  the dimension of objective space
# lowerBounds           =  the lower bounds of decision variables
# upperBounds           =  the upper bounds of decision variables
# popSize               =  the population size  
# archiveLimit          =  the archive limit (usually same as the population size)
# tourSize              =  the tournament size of mating selection
# generations           =  max. number of generations  
# cprob and mprob       =  the prob. for crossover and mutation operator
# cidx and midx         =  the crossover and mutation index
# monitorFunc           =  the monitor function for plotting the intermediate result

spea2NREL <-
function(cl, fn, objDim, variables, vartype, archiveLimit=nrow(variables), tourSize=2, generations=20, cprob=0.7, cidx=20, mprob=0.1, midx=20) {
  cat("########## Strength Pareto Evolutionary Algorithm 2 coded in R ##########")
  cat("\n")
  flag.store = character(0);            
    
  cat("\n")
  cat("input checking")
  if (length(vartype)!= ncol(variables)) {print("vartype length not same as number of variable columns");stop}

  cat("initializing the population")
  cat("\n")
  varNo = ncol(variables)
  popSize = nrow(variables)
  lowerBounds = rep(-Inf, varNo)
  upperBounds = rep(Inf, varNo)
  for (i in 1:varNo) {
    lowerBounds[i] = min(variables[,i])
    upperBounds[i] = max(variables[,i])
  }
  #setup parent population from input variables and randomly reorder them.
  parent <- data.matrix(variables)
  for (i in 1:varNo) {
    parent[,i] <- sample(variables[,i],nrow(variables))
  }
  print(parent)
  archive <- matrix(nrow=archiveLimit, ncol=varNo);

  #setup save objects
  parametersSave <- matrix(NA,nrow=(popSize+archiveLimit),ncol=(varNo)*generations)
  objectivesSave <- matrix(NA,nrow=(popSize+archiveLimit),ncol=(objDim)*generations)
  
  cat("check cluster\n")
  if (is.null(cl)) {print("cluster not initialized");stop}
  
  # do iterations  
  for (iter in 1:generations) { 
    cat("---------------generation---------------",iter,"starts");
    cat("\n");
        
    if (iter != 1) {
      archive <- archive[,1:varNo];
      parent <- rbind(parent, archive);
      parent <- unique(parent);
    }                      
    cat("Finess assignment");
    cat("\n");
    parentSize = nrow(parent); # Will parentSize less than popSize? Possible.
    parent <- cbind(parent, t(parApply(cl,parent,1,fn))); # objective function evaluation
    cat("save params and objectives\n")
    parametersSave[1:nrow(parent),((iter-1)*varNo+1):(varNo*iter)] <- as.vector(parent[,1:varNo])
    objectivesSave[1:nrow(parent),((iter-1)*objDim+1):(objDim*iter)] <- as.vector(parent[,(varNo+1):(varNo+objDim)])

    parent <- cbind(parent, strengthRawFitness(parent[,varNo+1:objDim])); # strength and raw fitness, please load strengthRawFitness functin first
    k <- round(sqrt(parentSize));   
    parent <- cbind(parent,1/(sigmaK(k,parent[,varNo+1:objDim])+2)); # density estimation, load kNNdensityEstimation.R first
    parent <- cbind(parent, parent[ ,varNo+objDim+1] + parent[ ,varNo+objDim+2]); # fitness = raw fitness + density
    nonDominateID <- which(parent[,varNo+objDim+3] < 1);
    archive <- parent[nonDominateID,,drop=F]; 
    archiveSize <- nrow(archive);
    
    cat("Environmental selection");
    cat("\n");
    if (archiveSize > archiveLimit) { # truncation
      truncSize <- archiveSize - archiveLimit;
      archive <- truncationOperator(truncSize, archive, varNo, objDim); # throw all archive inside, and get the truncated one back
      flag.store[iter] <- 'trunc' ;                 
    } else if (archiveSize < archiveLimit) { # fill
      fillSize <- archiveLimit - archiveSize;
      nonArchive <- parent[-nonDominateID, ];
      archive <- rbind(archive, nonArchive[order(nonArchive[,varNo+objDim+3]),][1:fillSize,]);
      flag.store[iter] <- 'fill';
    } else { # otherwise do nothing
      flag.store[iter] <- 'nothing';  
    }
    
    cat("Termination");
    cat("\n");
    if (iter >= generations) {      
      break;  
    }
    cat("Tournament selection");
    cat("\n");
    matingPool <- NULL; # matingPool must be nulled out first
    counter <- 1;
    while (counter <= popSize) {
      candidate = sample(nrow(archive),tourSize);      
      tmp <- archive[candidate,];
      matingPool <- rbind(matingPool,tmp[order(tmp[,varNo+objDim+3])[1],]);
      counter <- counter + 1;
    } 

    cat("Variation - crossover operator");
    cat("\n");
    childAfterX <- boundedSBXoverD(matingPool[,1:varNo],lowerBounds,upperBounds,vartype,cprob,cidx);                     
    cat("Variation - mutation operator");
    cat("\n");
    parent <- boundedPolyMutationD(childAfterX,lowerBounds,upperBounds,vartype,mprob,midx);
        print(nrow(parent))
        print(ncol(parent))
  } # loop for iter !!
  nonDominated <- archive[,varNo+objDim+3] < 1;
  # report on SPEA2 settings & results  
        results <- list(functions=fn, noParameter=varNo, noObjective=objDim, lowerBounds=lowerBounds, upperBounds=upperBounds, popSize=popSize, archiveLimit=archiveLimit, tournamentSize=tourSize, iter=iter, generations=generations, crossoverProb=cprob, mutationProb=mprob, truncateRecord=flag.store, population=parent, parameters=archive[,1:varNo], objectives=archive[,(varNo+1):(varNo+objDim)], fitness=archive[,varNo+objDim+3], nonDominated=nonDominated, parametersSave=parametersSave, objectivesSave=objectivesSave);                       
  class(results)="spea2R";
  return(results);
}
