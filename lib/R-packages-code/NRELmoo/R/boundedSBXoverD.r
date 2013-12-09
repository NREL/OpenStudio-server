boundedSBXoverD <-
function(parent_chromosome,lowerBounds,upperBounds,vartype,cprob,mu){
  popSize=nrow(parent_chromosome);
  varNo=ncol(parent_chromosome);
  child <- parent_chromosome;
  p <- 1;
  for (i in 1:(popSize/2)) {
    #if the random probability is less than cprob, then crossover
    if (runif(1) < cprob) { 
      for (j in 1:varNo) {
        parent1 <- child[p,j];
        parent2 <- child[p+1,j];
        yl <- lowerBounds[j];
        yu <- upperBounds[j];
        # SBX (Simulated Binary Crossover)
        rnd = runif(1);          
        if (rnd <= 0.5) { # Variable selected
          if (abs(parent1 - parent2) > 0.000001) {
            if (parent2 > parent1){
              y2 <- parent2;
              y1 <- parent1;
            } else {
              y2 <- parent1;
              y1 <- parent2;
            }
            # Find beta value
            if((y1 - yl) > (yu - y2)) {
              beta = 1.0 + (2.0*(yu-y2)/(y2-y1));
            } else {
              beta = 1.0 + (2.0*(y1-yl)/(y2-y1));
            }
            # Fine alpha
            alpha = 2.0 - (beta^(-(1.0+mu)));
            rnd = runif(1);
            if (rnd <= 1.0/alpha) {
              alpha = alpha*rnd;
              betaq = alpha^(1.0/(1.0+mu));
            } else { # rnd > 1.0/alpha
              alpha = alpha*rnd;
              alpha = 1.0/(2.0-alpha);
              betaq = alpha^(1.0/(1.0+mu));
            }
            # Generating two children
            child1 = 0.5*((y1+y2)-betaq*(y2-y1));
            child2 = 0.5*((y1+y2)+betaq*(y2-y1));
            #force discrete
            if (vartype[j] == "discrete") {
              child1 = child[which.min(abs(child1-child[,j])),j]
              child2 = child[which.min(abs(child2-child[,j])),j]
            }
          } else{ # abs(parent1 - parent2) <= 0.000001
            betaq = 1.0;
            y1 = parent1;
            y2 = parent2;
            # Generating two children
            child1 = 0.5*((y1+y2)-betaq*(y2-y1));
            child2 = 0.5*((y1+y2)+betaq*(y2-y1));
            #force discrete
            if (vartype[j] == "discrete") {
              child1 = child[which.min(abs(child1-child[,j])),j]
              child2 = child[which.min(abs(child2-child[,j])),j]
            }
          } # abs(parent1 - parent2) ends here
          if (child1 > yu) {
            child1 = yu;    
          } else if (child1 < yl) {
            child1 = yl;
          }
          if (child2 > yu) {
            child2 = yu;
          } else if (child2 < yl) {
            child2 = yl;
          }
        } else { # Variable NOT selected
        # Copying parents to children
          child1 = parent1;
          child2 = parent2;
        } # Variable selection ends here
        child[p,j] <- child1;
        child[p+1,j] <- child2;
      } # next j (var)
    } # Xover ends here
    p <- p + 2;
  } # next i
  return(child);
}
