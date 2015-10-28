#############################################################
# Nondominated Sorting Genetic Algorithm 2 in R
# Main Program Oct./12/2013
# Author: Prof. Ching-Shih (Vince) Tsou, Ph.D.
# Affiliation: Institute of Information and Decision Sciences
#              National Taipei College of Business
# Email: cstsou@mail.ntcb.edu.tw
#############################################################

# Arguments description
# cl                    =  snow cluster
# fn                    =  the objective functions
# objDim                =  the dimension of objective space
# variables             =  matrix of variables
# vartype               =  list of variable types
# tourSize              =  the tournament size of mating selection
# generations           =  max. number of generations  
# cprob and mprob       =  the prob. for crossover and mutation operator
# XoverDistIdx          =  crossover index
# MuDistIdx             =  mutation index
nsga2NREL <-
function(cl, fn, objDim, variables, vartype,
                    tourSize=2, generations=20, cprob=0.7, XoverDistIdx=5, mprob=0.5, MuDistIdx=10) {
    cat("********** R based Nondominated Sorting Genetic Algorithm II *********")
    cat("\n")
    cat("input checking\n")
    if (length(vartype)!= ncol(variables)) {print("vartype length not same as number of variable columns");stop}
    
    cat("initializing the population\n")
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
    cat("parent:\n")
    print(parent)
    cat("ncol parent:\n")
    print(ncol(parent))
    cat("nrow parent:\n")
    print(nrow(parent))
    
    cat("check cluster\n")
    if (is.null(cl)) {print("cluster not initialized");stop}

    cat("start parallel pop\n")
    parent <- cbind(parent, t(parApplyLB(cl,parent,1,fn)));
    cat("save params and objectives")
    parametersSave <- parent[,1:varNo]
    objectivesSave <- parent[,(varNo+1):(varNo+objDim)]
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
        childAfterX <- boundedSBXoverD(matingPool[,1:varNo],lowerBounds,upperBounds,vartype,cprob,XoverDistIdx); # Only design parameters are input as the first argument
        cat("mutation operator")
        cat("\n")
        childAfterM <- boundedPolyMutationD(childAfterX,lowerBounds,upperBounds,vartype,mprob,MuDistIdx);
        cat("evaluate the objective fns of childAfterM")
        cat("\n")
        cat("start child parallel\n")
        childAfterM <- cbind(childAfterM, t(parApplyLB(cl,childAfterM,1,fn)));
        cat("save params and objectives")
        parametersSave <- cbind(parametersSave,childAfterM[,1:varNo])
        objectivesSave <- cbind(objectivesSave,childAfterM[,(varNo+1):(varNo+objDim)])
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

    # report on nsga2 settings and results
    result = list(functions=fn, parameterDim=varNo, objectiveDim=objDim, lowerBounds=lowerBounds,
                  upperBounds=upperBounds, popSize=popSize, tournamentSize=tourSize,
                  generations=generations, XoverProb=cprob, XoverDistIndex=XoverDistIdx,
                  mutationProb=mprob, mutationDistIndex=MuDistIdx, parameters=parent[,1:varNo],
                  objectives=parent[,(varNo+1):(varNo+objDim)], paretoFrontRank=parent[,varNo+objDim+1],
                  crowdingDistance=parent[,varNo+objDim+2], parametersSave=parametersSave, objectivesSave=objectivesSave);
    class(result)="nsga2R";
    return(result)
}
