\name{boundedSBXoverD}
\alias{boundedSBXoverD}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Bounded Simulated Binary Crossover Operator
}
\description{
The simulated binary crossover operator is a real-parameter genetic operator. It simulates the working principal of the single-point crossover operator on binary strings.
}
\usage{
boundedSBXoverD(parent_chromosome, lowerBounds, upperBounds, vartype, cprob, mu)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{parent_chromosome}{Mating pool with decision variables}
  \item{lowerBounds}{Lower bounds of each decision variable}
  \item{upperBounds}{Upper bounds of each decision variable}
  \item{vartype}{character vector of variable type [discrete,continuous]}
  \item{cprob}{Crossover probability}
  \item{mu}{Crossover distribution index, it can be any nonnegative real number}
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
cprob <- 0.7
XoverDistIdx <- 20
matingPool <- matrix(runif(1200, 0, 1), nrow=40, ncol=30)
vartype = rep(c("discrete","continuous"),15)
childAfterX <- boundedSBXoverD(matingPool,lowerBounds,upperBounds,vartype,cprob,XoverDistIdx)
childAfterX
}

