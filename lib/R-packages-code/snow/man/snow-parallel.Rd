\name{snow-parallel}
\title{Higher Level SNOW Functions}
\alias{parLapply}
\alias{parRapply}
\alias{parCapply}
\alias{parApply}
\alias{parMM}
\alias{parSapply}
\usage{
parLapply(cl, x, fun, ...)
parSapply(cl, X, FUN, ..., simplify = TRUE, USE.NAMES = TRUE) 
parApply(cl, X, MARGIN, FUN, ...)
parRapply(cl, x, fun, ...)
parCapply(cl, x, fun, ...)
parMM(cl, A, B)
}
\arguments{
  \item{cl}{cluster object}
  \item{fun}{function or character string naming a function}
  \item{X}{array to be used}
  \item{x}{matrix to be used}
  \item{FUN}{function or character string naming a function}
  \item{MARGIN}{vector specifying the dimensions to use.}
  \item{simplify}{logical; see \code{sapply}}
  \item{USE.NAMES}{logical; see \code{sapply}}
  \item{...}{additional arguments to pass to standard function}
  \item{A}{matrix}
  \item{B}{matrix}
}
\description{
  Parallel versions of \code{apply} and related functions.
}
\details{
  \code{parLapply}, \code{parSapply}, and \code{parApply} are parallel
  versions of \code{lapply}, \code{sapply}, and \code{apply}.

  \code{parRapply} and \code{parCapply} are parallel row and column
  \code{apply} functions for a matrix \code{x}; they may be slightly
  more efficient than \code{parApply}.

  \code{parMM} is a very simple(minded) parallel matrix multiply;
  it is intended as an illustration.

  For more details see
  \url{http://www.stat.uiowa.edu/~luke/R/cluster/cluster.html}.
}
\examples{
  \dontrun{
cl <- makeSOCKcluster(c("localhost","localhost"))
parSapply(cl, 1:20, get("+"), 3)
  }
}
\keyword{programming}
