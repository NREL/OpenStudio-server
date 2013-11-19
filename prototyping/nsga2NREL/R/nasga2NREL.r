# test3 <- cbind(seq(0,1,length.out=200),seq(0,1,length.out=200))
# library(snow)
# cl <- makeSOCKcluster(rep("localhost",8))
# install.packages("~/Downloads/nsga2NREL.tar.gz", repos = NULL, type = "source")
# system.time(nrel8 <- nsga2NREL(8,fn=zdt2_delay,2,test3,generations=40,mprob=0.8))

nsga2NREL <-
function(cl=NULL, fn, objDim, variables,
                    tourSize=2, generations=20, cprob=0.7, XoverDistIdx=5, mprob=0.2, MuDistIdx=10) {
    cat("********** R based Nondominated Sorting Genetic Algorithm II *********")
    cat("\n")
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
    parent <- variables
    for (i in 1:varNo) {
      parent[,i] <- sample(variables[,i],nrow(variables))
    }
    print(parent)
    
    cat("check cluster\n")
    require(snow)
    if (is.null(cl)) {print("cluster not initialized");stop}
    #cl <- makeSOCKcluster(rep("localhost",nodes))
    cat("start parallel pop\n")
    parent <- cbind(parent, t(parApply(cl,parent,1,fn)));
    cat("stop\n")
    cat("ranking the initial population")
    cat("\n")  
    ranking <- fastNonDominatedSorting(parent[,(varNo+1):(varNo+objDim)]);
    # Rank index for each chromosome
    rnkIndex <- integer(popSize);
    i <- 1;
    while (i <= length(ranking)) {
        rnkIndex[ranking[[i]]] <- i;
        i <- i + 1;
    } 
    parent <- cbind(parent,rnkIndex);
    cat("crowding distance calculation")
    cat("\n")
    objRange <- apply(parent[,(varNo+1):(varNo+objDim)], 2, max) - apply(parent[,(varNo+1):(varNo+objDim)], 2, min);
    cd <- crowdingDist4frnt(parent,ranking,objRange);
    parent <- cbind(parent,apply(cd,1,sum));
    for (iter in 1: generations){
        cat("---------------generation---------------",iter,"starts")
        cat("\n")
        cat("tournament selection")
        cat("\n")
        matingPool <- tournamentSelection(parent,popSize,tourSize);
        cat("crossover operator")
        cat("\n")  
        childAfterX <- boundedSBXoverD(matingPool[,1:varNo],lowerBounds,upperBounds,cprob,XoverDistIdx); # Only design parameters are input as the first argument
        cat("mutation operator")
        cat("\n")
        childAfterM <- boundedPolyMutationD(childAfterX,lowerBounds,upperBounds,mprob,MuDistIdx);
        cat("evaluate the objective fns of childAfterM")
        cat("\n")
        cat("start child parallel\n")
        childAfterM <- cbind(childAfterM, t(parApply(cl,childAfterM,1,fn)));
        cat("stop\n")
        # Consider use child again and again ...
        cat("Rt = Pt + Qt")
        cat("\n")
        # Combine the parent with the childAfterM (No need to retain the rnkIndex and cd of parent)
        parentNext <- rbind(parent[,1:(varNo+objDim)],childAfterM)
        cat("ranking again")
        cat("\n")
        ranking <- fastNonDominatedSorting(parentNext[,(varNo+1):(varNo+objDim)]);
        i <- 1;
        while (i <= length(ranking)) {
            rnkIndex[ranking[[i]]] <- i;
            i <- i + 1;
        } 
        parentNext <- cbind(parentNext,rnkIndex);
        cat("crowded comparison again")
        cat("\n")
        objRange <- apply(parentNext[,(varNo+1):(varNo+objDim)], 2, max) - apply(parentNext[,(varNo+1):(varNo+objDim)], 2, min);
        cd <- crowdingDist4frnt(parentNext,ranking,objRange);
        parentNext <- cbind(parentNext,apply(cd,1,sum));
        parentNext.sort <- parentNext[order(parentNext[,varNo+objDim+1],-parentNext[,varNo+objDim+2]),];
        cat("environmental selection")
        cat("\n")
        # choose the first 'popSize' rows for next generation
        parent <- parentNext.sort[1:popSize,]
        cat("---------------generation---------------",iter,"ends")
        cat("\n")
        if (iter != generations) {
            cat("\n")
            cat("********** new iteration *********")
            cat("\n")
        } else {
            cat("********** stop the evolution *********")
            cat("\n")
        }
    }
    stopCluster(cl)
    # report on nsga2 settings and results
    result = list(functions=fn, parameterDim=varNo, objectiveDim=objDim, lowerBounds=lowerBounds,
                  upperBounds=upperBounds, popSize=popSize, tournamentSize=tourSize,
                  generations=generations, XoverProb=cprob, XoverDistIndex=XoverDistIdx,
                  mutationProb=mprob, mutationDistIndex=MuDistIdx, parameters=parent[,1:varNo],
                  objectives=parent[,(varNo+1):(varNo+objDim)], paretoFrontRank=parent[,varNo+objDim+1],
                  crowdingDistance=parent[,varNo+objDim+2]);
    class(result)="nsga2R";
    return(result)
}
