boundedPolyMutationD <-
function(parent_chromosome,lowerBounds,upperBounds,vartype,mprob,mum){
  popSize=nrow(parent_chromosome);
  varNo=ncol(parent_chromosome);
  child <- parent_chromosome;
    for (i in 1:popSize) {
      for (j in 1:varNo){
        y = child[i,j];
        # if the random probability is less than mprob, then mutate that variable
        if (runif(1) < mprob) {
          yl = lowerBounds[j];
          yu = upperBounds[j];
          if (y > yl) { 
            if ((y-yl) < (yu-y)) {
              delta = (y-yl)/(yu-yl);
            } else {
              delta = (yu-y)/(yu-yl);
            }
            rnd = runif(1);
            mut_pow = 1.0/(mum + 1.0);
            if (rnd < 0.5){
              xy = 1.0-delta;
              val = 2.0*rnd+(1.0-2.0*rnd)*(xy^(mum+1.0));
              deltaq = val^mut_pow - 1.0;
            } else {
              xy = 1.0-delta;
              val = 2.0*(1.0-rnd)+2.0*(rnd-0.5)*(xy^(mum+1.0));
              deltaq = 1.0 - val^mut_pow;
            }
            y = y + deltaq*(yu-yl);
            #force discrete
            if (vartype[j] == "discrete") {
              y = child[which.min(abs(y-child[,j])),j]
            }
            if (y > yu) {
              y = yu;
            } else if (y < yl) {
              y = yl;
            }
            child[i,j] = y;
          } else { # y <= yl
            xy = runif(1);
            y = yl + xy*(yu-yl);            
            #force discrete
            if (vartype[j] == "discrete") {
              child[i,j] = child[which.min(abs(y-child[,j])),j]
            } else {
              child[i,j] = y;
            }
          }  
        } # runif(1) > mprob, do not perform mutation
      } # next j
    } # next i
  return(child);
}
