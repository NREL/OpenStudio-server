tournamentSelection <-
function(pop,pool_size,tour_size) {
  popSize = nrow(pop);
  Dim = ncol(pop);
  f <- NULL;
  counter <- 1
  while (counter <= pool_size) {
    candidate = sample(popSize,tour_size);      
    tmp <- pop[candidate,];
    f <- rbind(f,tmp[order(tmp[,Dim-1],-tmp[,Dim])[1],]);
    counter <- counter + 1;
  } 
  return(f);
}
