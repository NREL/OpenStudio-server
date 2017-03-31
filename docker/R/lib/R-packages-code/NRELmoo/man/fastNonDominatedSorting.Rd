\name{fastNonDominatedSorting}
\alias{fastNonDominatedSorting}
\title{
Fast Non-dominated Sorting
}
\description{
A fast approach to sort non-dominated solutions into different nondomination levels.
}
\usage{
fastNonDominatedSorting(inputData)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{inputData}{Matrix of solutions with objective function values}
}
\value{
Return a list of indices for all fronts.
}
\references{
Deb, K., Pratap, A., Agarwal, S., and Meyarivan, T. (2002), " A fast and elitist multiobjective genetic algorithm: NSGA-II", \emph{IEEE Transactions on Evolutionary Computation}, \bold{6(2)}, 182-197.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
\examples{
set.seed(1234)
# randomly generate a polulation of fifty chromosomes, each with two objectives
y <- matrix(runif(100, -5, 5), nrow=50, ncol=2)
rankIdxList <- fastNonDominatedSorting(y)
rankIdxList
}
