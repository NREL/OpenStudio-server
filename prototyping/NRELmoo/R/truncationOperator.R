#############################################################
# Strength Pareto Evolutionary Algorithm 2 in R
# Truncation Module 12/10/2013
# Author: Prof. Ching-Shih (Vince) Tsou, Ph.D. and 
#         Jyun-Hao Chen  <janjeanjanjean@hotmail.com>
# Affiliation: Institute of Information and Decision Sciences
#              National Taipei College of Business
# Email: cstsou@mail.ntcb.edu.tw
##############################################################

truncationOperator <-
function(truncateNo,inputData, vNo, oDim) {
   for (j in 1:truncateNo) { 
      popSize <- nrow(inputData);    
      distanceMatrix <- matrix(nrow=popSize, ncol=popSize); # renew the distanceMatrix
      distanceMatrix <- as.matrix(dist(inputData[,vNo+1:oDim]));
      # sort the distance and find the indices of the minimum (except zero)
      candidate.case1 <- which(distanceMatrix==sort(distanceMatrix)[popSize+1],arr.ind=T)[2,1];
      candidate.case2 <- which(distanceMatrix==sort(distanceMatrix)[popSize+1],arr.ind=T)[2,2];
      # find the final truncation 
      candidate.set <- distanceMatrix[c(candidate.case1,candidate.case2), ] ;   
      sort.candidateSet <- matrix(nrow=2, ncol=popSize);        
      sort.candidateSet[1, ] <- sort(candidate.set[1, ]);      
      sort.candidateSet[2, ] <- sort(candidate.set[2, ]);            
      for (index in 3:popSize) {
         if (sort.candidateSet[1,index] != sort.candidateSet[2,index]) {   
            if (sort.candidateSet[1,index] < sort.candidateSet[2,index]) {
               truncationCase <- candidate.case1;
            } else {
               truncationCase <- candidate.case2;
            }          
            break # leave the for loop after finding the loser      
         } # tie for current index, go for next index
         if (index==popSize) {
           truncationCase <- candidate.case1; # all of the distances of their neighbors are the same !
         }
      } # end of for loop
      inputData <- inputData[-truncationCase, ];
   }
   return (inputData);
}
