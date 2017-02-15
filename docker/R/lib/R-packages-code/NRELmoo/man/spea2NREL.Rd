\name{spea2NREL}
\alias{spea2NREL}
\title{
A Parallel Strength Pareto Evolutionary Algorithm II based on R
}
\description{
A fast and elitist multiobjective genetic algorithm based on R. Modified spea2R by NREL for parallel F evals and mixed continuous and discrete variables.
}
\usage{
spea2NREL(cl, fn, objDim, variables, vartype, archiveLimit = nrow(variables), 
  tourSize = 2, generations = 20, cprob = 0.7, cidx = 20, mprob = 0.1, 
  midx = 20)
}
\arguments{
  \item{cl}{SOCK cluster object}
  \item{fn}{Objective functions to be minimized}
  \item{objDim}{number of objective functions}
  \item{variables}{matrix of variable values as column vectors. columns must have same length}
  \item{vartype}{character vector of variable type [discrete,continuous]}
  \item{archiveLimit}{limit size of archive.}
  \item{tourSize}{size of tournament.}
  \item{generations}{number of generations.}
  \item{cprob}{crossover probability.}
  \item{cidx}{crossover index.}
  \item{mprob}{mutation probability.}
  \item{midx}{mutation index.}
}
\value{
The returned value is a 'spea2R' object with the following fields in additional to above SPEA-II settings:
\item{parameters}{solutions of decision variables found.}
\item{objectives}{non-dominated objective function values.}
\item{archive}{archive population that each non-dominated solution belongs to.}
}
\references{
Zitzler, E., Laumanns, M., Thiele, L., SPEA2: Improving the strength pareto 
  evolutionary algorithm. Technical report 103, Computer Engineering and Networks
  Laboratory (TIK), Swiss Federal Institute of Technology (ETH) Zurich, Gloriastrasse
  35, CH-8092 Zurich, Switzerland, 2001.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
\examples{
## find the non-dominated solutions of zdt1 test problem
library(parallel)
cl <- makePSOCKcluster(rep("localhost",8))
vars <- cbind(seq(0,1,length.out=200),seq(0,1,length.out=200))
vartype <- c("discrete","continuous")

## evaluate the ZDT3 problem
results <- spea2NREL(cl=cl, fn=ZDT1, objDim=2, variables=vars, vartype=vartype, tourSize=2, generations=50, cprob=0.9, cidx=20, mprob=0.1, midx=3)
stopCluster(cl)
#plot(results$objectives)
}
\keyword{optimize}
