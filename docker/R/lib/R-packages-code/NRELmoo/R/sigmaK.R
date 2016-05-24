#############################################################
# Strength Pareto Evolutionary Algorithm 2 in R
# k-Nearest Neighbor Density Estimation Module Oct./12/2013
# Author: Prof. Ching-Shih (Vince) Tsou, Ph.D. and 
#         Jyun-Hao Chen  <janjeanjanjean@hotmail.com>
# Affiliation: Institute of Information and Decision Sciences
#              National Taipei College of Business
# Email: cstsou@mail.ntcb.edu.tw
#############################################################
sigmaK <-
function(k, inputData) { 
   sigmaK <- rep(NA, nrow(inputData))
   distanceMatrix <- matrix(NA, nrow(inputData), nrow(inputData))
   distanceMatrix <- as.matrix(dist(inputData))
   sigmaK <- sapply(1:nrow(inputData), function(u) sigmaK[u] <- sort(distanceMatrix[u, ])[k+1])
   return(sigmaK)
}
