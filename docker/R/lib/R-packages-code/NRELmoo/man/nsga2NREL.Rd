\name{nsga2NREL}
\alias{nsga2NREL}
\title{
A parallel R Based Non-dominated Sorting Genetic Algorithm II
}
\description{
A fast and elitist multiobjective genetic algorithm based on R. Modified nsga2R by NREL for parallel F evals and mixed continuous and discrete variables.
}
\usage{
nsga2NREL(cl, fn, objDim, variables, vartype, tourSize = 2, generations = 20, 
  cprob = 0.7, XoverDistIdx = 5, mprob = 0.5, MuDistIdx = 10)
}
\arguments{
  \item{cl}{SOCK cluster object}
  \item{fn}{Objective functions to be minimized}
  \item{objDim}{Number of objective functions}
  \item{variables}{matrix of variable values as column vectors. columns must have same length}
  \item{vartype}{character vector of variable type [discrete,continuous]}
  \item{tourSize}{Size of tournament}
  \item{generations}{Number of generations}
  \item{cprob}{Crossover probability}
  \item{XoverDistIdx}{Crossover distribution index, it can be any nonnegative real number}
  \item{mprob}{Mutation probability}
  \item{MuDistIdx}{Mutation distribution index, it can be any nonnegative real number}
}
\value{
The returned value is a 'nsga2R' object with the following fields in additional to above NSGA-II settings:

\item{parameters}{Solutions of decision variables found}
\item{objectives}{Non-dominated objective function values}
\item{paretoFrontRank}{Nondomination ranks (or levels) that each non-dominated solution belongs to}
\item{crowdingDistance}{Crowding distance of each non-dominated solution}
}
\references{
Deb, K., Pratap, A., Agarwal, S., and Meyarivan, T. (2002), " A fast and elitist multiobjective genetic algorithm: NSGA-II", \emph{IEEE Transactions on Evolutionary Computation}, \bold{6(2)}, 182-197.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
\examples{
# find the non-dominated solutions of zdt1 test problem
library(parallel)
cl <- makePSOCKcluster(rep("localhost",8))
vars <- cbind(seq(0,1,length.out=200),seq(0,1,length.out=200))
vartype <- c("discrete","continuous")
results <- nsga2NREL(cl,fn=ZDT1,2,vars,vartype,generations=40,mprob=0.8)
stopCluster(cl)
#plot(results$objectives)
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{optimize}
