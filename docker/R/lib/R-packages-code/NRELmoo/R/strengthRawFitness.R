#############################################################
# Strength Pareto Evolutionary Algorithm 2 in R
# Strength Value and Raw Fitness Module 01/04/2013
# Author: Prof. Ching-Shih (Vince) Tsou, Ph.D.
# Affiliation: Institute of Information and Decision Sciences
#              National Taipei College of Business
# Email: cstsou@mail.ntcb.edu.tw
#############################################################

strengthRawFitness <-
function(inputData) {
#   inputData = parent[,31:32]
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
  noDominatees <- sapply(idxDominatees,length); # i.e. Strength Value
  rawFitness <- function(u) {
    sum(noDominatees[u])
  }
  raw <- sapply(idxDominators, rawFitness)
  return(raw)
}
