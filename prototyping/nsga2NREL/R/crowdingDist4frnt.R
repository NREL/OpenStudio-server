crowdingDist4frnt <-
function(pop,rnk,rng){
  popSize <- nrow(pop);
  objDim <- length(rng);
  varNo <- ncol(pop)-1-length(rng);
  cd <- matrix(Inf,nrow=popSize,ncol=objDim);
  for (i in 1:length(rnk)){
    selectRow <- pop[,ncol(pop)]==i;
    len <- length(rnk[[i]]);
    if (len > 2) {
      for (j in 1:objDim) {
        originalIdx <- rnk[[i]][order(pop[selectRow,varNo+j])];
        cd[originalIdx[2:(len-1)],j] = abs(pop[originalIdx[3:len],varNo+j] - pop[originalIdx[1:(len-2)],varNo+j])/rng[j];
      }
    }
  }
return(cd);
}
