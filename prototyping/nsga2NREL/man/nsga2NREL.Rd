\name{nsga2NREL}
\alias{nsga2NREL}
\title{
R Based Non-dominated Sorting Genetic Algorithm II
}
\description{
A fast and elitist multiobjective genetic algorithm based on R.
}
\usage{
nsga2R(fn, varNo, objDim, lowerBounds = rep(-Inf, varNo), upperBounds = rep(Inf, varNo),
  popSize = 100, tourSize = 2, generations = 20, cprob = 0.7, XoverDistIdx = 5,
  mprob = 0.2, MuDistIdx = 10)
}
\arguments{
  \item{fn}{Objective functions to be minimized}
  \item{varNo}{Number of decision variables}
  \item{objDim}{Number of objective functions}
  \item{lowerBounds}{Lower bounds of each decision variable}
  \item{upperBounds}{Upper bounds of each decision variable}
  \item{popSize}{Size of population}
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
# find the non-dominated solutions of zdt3 test problem
results <- nsga2R(fn=zdt3, varNo=30, objDim=2, lowerBounds=rep(0,30), upperBounds=rep(1,30),
  popSize=50, tourSize=2, generations=50, cprob=0.9, XoverDistIdx=20, mprob=0.1,MuDistIdx=3)

plot(results$objectives)
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{optimize}
