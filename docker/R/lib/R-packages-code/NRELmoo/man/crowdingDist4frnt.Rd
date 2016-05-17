\name{crowdingDist4frnt}
\alias{crowdingDist4frnt}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Crowding Distance Assignment for Each Front
}
\description{
This function estimates the density of solutions surrounding a particular solution within each front. It calculates the crowding distances of solutions according to their objectives and those within the same front.  
}
\usage{
crowdingDist4frnt(pop, rnk, rng)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{pop}{Population matrix including decision variables, objective functions, and nondomination rank}
  \item{rnk}{List of solution indices for each front}
  \item{rng}{Vector of each objective function range, i.e. the difference between the maximum and minimum objective function value of each objective}
}
\value{
Return a matrix of crowding distances of all solutions
}
\references{
Deb, K., Pratap, A., Agarwal, S., and Meyarivan, T. (2002), " A fast and elitist multiobjective genetic algorithm: NSGA-II", \emph{IEEE Transactions on Evolutionary Computation}, \bold{6(2)}, 182-197.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
\seealso{
\code{\link{fastNonDominatedSorting}}
}
\examples{
popSize <- 50
lowerBounds <- rep(0,30)
upperBounds <- rep(1,30)
varNo <- length(lowerBounds)
objDim <- 2
set.seed(1234)
population <- t(sapply(1:popSize, function(u) array(runif(length(lowerBounds),
  lowerBounds,upperBounds))))
population <- cbind(population, t(apply(population,1,ZDT2)))
ranking <- fastNonDominatedSorting(population[,(varNo+1):(varNo+objDim)])
rnkIndex <- integer(popSize)
i <- 1
while (i <= length(ranking)) {
  rnkIndex[ranking[[i]]] <- i
  i <- i + 1
} 
population <- cbind(population,rnkIndex)
objRange <- apply(population[,(varNo+1):(varNo+objDim)], 2, max) -
  apply(population[,(varNo+1):(varNo+objDim)], 2, min)
cd <- crowdingDist4frnt(population,ranking,objRange)
cd
}
