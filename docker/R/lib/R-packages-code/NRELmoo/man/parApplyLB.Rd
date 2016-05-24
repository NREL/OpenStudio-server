\name{parApplyLB}
\alias{parApplyLB}
\title{Apply Operation using Clusters}
\description{
  This function is a modified way to parallelize computations using a cluster.}
\usage{
parApplyLB(cl = NULL, X, MARGIN, FUN, ...)
}
\arguments{
  \item{cl}{SOCK cluster object}
  \item{X}{An array for \code{parApply}.}
  \item{FUN}{function or character string naming a function.}
  \item{MARGIN}{vector specifying the dimensions to use.}
}
\value{
\code{parApplyLB} follow \code{\link{apply}}.
}

\author{
  Luke Tierney and Brian BAll.

  Derived from the snow package.
}
\examples{

}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{optimize}
