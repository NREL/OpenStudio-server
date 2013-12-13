\name{snowFT-startstop}
\title{Starting snowFT Cluster}
\alias{makeClusterFT}
\alias{makeSOCKclusterFT}
\description{
  Functions to start a snowFT cluster and to set default cluster
  options.
}
\usage{
makeClusterFT(spec, type = getClusterOption("type"), 
    names = NULL, ft_verbose = FALSE, ...)
}
\arguments{
  \item{spec}{Cluster size.}
  \item{type}{Character string that specifies cluster type. "MPI" and "SOCK" are supported ("PVM" is currently not available).}
  \item{names}{Used only for the \sQuote{SOCK} layer. It should be a vector of host names, or a list containing specification for each host (see Example in \code{\link[snow]{makeCluster}}). Due to the dynamic resizing feature, the length of this vector (or list) does not need to match the size of the cluster \code{spec} - it is used as a pool from which hosts are taken as they are needed. If \code{names} is \code{NULL}, each node is started on \sQuote{localhost}.}
  \item{ft_verbose}{If TRUE, debugging messages are sent to standard output.}
  \item{...}{Cluster option specifications. A useful option is \code{outfile}, specifying name of a file to which slave node output is to be directed.}
}

\details{
  \code{makeClusterFT} starts a cluster of the specified or default type, loads the \pkg{snowFT} library on each node
  and returns a reference to the cluster. See \code{\link[snow]{makeCluster}} for more details.

  The cluster should be stopped by \code{\link[snow]{stopCluster}} of the \pkg{snow} package.
}
\seealso{\code{snow-startstop} functions of the snow package.} 
\examples{
\dontrun{
cl <- makeClusterFT(5)
res <- clusterApplyFT(cl, 1:10, get("+"), 3)
stopCluster(res[[2]])
print(res[[1]])
  }
}
\keyword{programming}
