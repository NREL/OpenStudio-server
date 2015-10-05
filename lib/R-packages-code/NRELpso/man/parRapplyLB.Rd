\name{parRapplyLB}
\alias{parRapplyLB}
\title{Apply Operation using Clusters}
\description{
  This function is a modified way to parallelize computations using a cluster.}
\usage{
parRapplyLB(cl = NULL, x, FUN, ...)
splitRow(x, ncl)
splitIndicies(nx, ncl)
}
\arguments{
  \item{cl}{SOCK cluster object}
  \item{x}{An array for \code{parRapply}.}
  \item{FUN}{function or character string naming a function.}
  \item{ncl, nx}{blah}
}
\value{
\code{parRapplyLB} follow \code{\link{apply}}.
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
