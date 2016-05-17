\name{boundedPolyMutationD}
\alias{boundedPolyMutationD}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Bounded Polynomial Mutation Operator
}
\description{
The bounded polynomial mutation operator is a real-parameter genetic operator. Like in the simulated binary crossover operator, the probability distribution is also a polynomial function instead of a normal distribution.
}
\usage{
boundedPolyMutationD(parent_chromosome, lowerBounds, upperBounds, vartype, mprob, mum)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{parent_chromosome}{Mating pool with decision variables}
  \item{lowerBounds}{Lower bounds of each decision variable}
  \item{upperBounds}{Upper bounds of each decision variable}
  \item{vartype}{character vector of variable type [discrete,continuous]}
  \item{mprob}{Mutation probability}
  \item{mum}{Mutation distribution index, it can be any nonnegative real number}
}
\value{
Return the offspring population with decision variables
}
\references{
Deb, K., Pratap, A., Agarwal, S., and Meyarivan, T. (2002), " A fast and elitist multiobjective genetic algorithm: NSGA-II", \emph{IEEE Transactions on Evolutionary Computation}, \bold{6(2)}, 182-197.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
\examples{
set.seed(1234)
lowerBounds <- rep(0,30)
upperBounds <- rep(1,30)
mprob <- 0.2
MutDistIdx <- 20
matingPool <- matrix(runif(1200, 0, 1), nrow=40, ncol=30)
vartype = rep(c("discrete","continuous"),15)
childAfterM <- boundedPolyMutationD(matingPool,lowerBounds,upperBounds,vartype,mprob,MutDistIdx)
childAfterM
}

