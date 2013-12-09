fastNonDominatedSorting <-
function(inputData) {
  popSize = nrow(inputData)
  idxDominators = vector("list", popSize)
  idxDominatees = vector("list", popSize)
  for (i in 1:(popSize-1)) {
    for (j in i:popSize) {
      if (i != j) {
        xi = inputData[i, ]
        xj = inputData[j, ]
        if (all(xi <= xj) && any(xi < xj)) {  ## i dominates j
          idxDominators[[j]] = c(idxDominators[[j]], i)
          idxDominatees[[i]] = c(idxDominatees[[i]], j) 
        } else if (all(xj <= xi) && any(xj < xi)) {  ## j dominates i
          idxDominators[[i]] = c(idxDominators[[i]], j)
          idxDominatees[[j]] = c(idxDominatees[[j]], i) 
        }
      }
    }
  }
  noDominators <- lapply(idxDominators,length);
  rnkList <- list();
  rnkList <- c(rnkList,list(which(noDominators==0)));
  solAssigned <- c();
  solAssigned <- c(solAssigned,length(which(noDominators==0)));
  while (sum(solAssigned) < popSize) {
    Q <- c();
    noSolInCurrFrnt <- solAssigned[length(solAssigned)];
    for (i in 1:noSolInCurrFrnt) {
      solIdx <- rnkList[[length(rnkList)]][i];
      hisDominatees <- idxDominatees[[solIdx]]; # A vector
      for (i in hisDominatees) {
        noDominators[[i]] <- noDominators[[i]] - 1;
        if (noDominators[[i]] == 0) {
          Q <- c(Q, i);
        }
      }
    }
    rnkList <- c(rnkList,list(sort(Q))); # sort Q before concatenating
    solAssigned <- c(solAssigned,length(Q));
  }
  return(rnkList);
}
