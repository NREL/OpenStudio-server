\name{tournamentSelection}
\alias{tournamentSelection}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Tournament Selection
}
\description{
Tournaments are played among several solutions. The best one is chosen according to their nondomination levels and crowding distances. And it is placed in the mating pool.
}
\usage{
tournamentSelection(pop, pool_size, tour_size)
}
\arguments{
  \item{pop}{Population matrix with nondomination rank and crowding distance}
  \item{pool_size}{Size of mating pool, usually same as the population size}
  \item{tour_size}{Size of tournament, the selection pressure can be adjusted by varying the tournament size}
}
\value{
Return the mating pool with decision variables, objective functions, nondomination level, and crowding distance
}
\references{
Deb, K., Pratap, A., Agarwal, S., and Meyarivan, T. (2002), " A fast and elitist multiobjective genetic algorithm: NSGA-II", \emph{IEEE Transactions on Evolutionary Computation}, \bold{6(2)}, 182-197.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
\examples{
tourSize <- popSize <- 10
lowerBounds <- rep(0,30)
upperBounds <- rep(1,30)
varNo <- length(lowerBounds)
objDim <- 2
set.seed(1234)
population <- t(sapply(1:popSize, function(u) array(runif(length(lowerBounds),
  lowerBounds,upperBounds))))
population <- cbind(population, t(apply(population,1,ZDT3)))
ranking <- fastNonDominatedSorting(population[,(varNo+1):(varNo+objDim)])
rnkIndex <- integer(popSize)
i <- 1
while (i <= length(ranking)) {
  rnkIndex[ranking[[i]]] <- i
  i <- i + 1
} 
population <- cbind(population,rnkIndex);
objRange <- apply(population[,(varNo+1):(varNo+objDim)], 2, max) -
  apply(population[,(varNo+1):(varNo+objDim)], 2, min);
cd <- crowdingDist4frnt(population,ranking,objRange)
population <- cbind(population,apply(cd,1,sum))
matingPool <- tournamentSelection(population,popSize,tourSize)
matingPool
}
