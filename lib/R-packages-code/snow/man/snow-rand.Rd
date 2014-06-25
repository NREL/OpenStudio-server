\name{snow-rand}
\title{Uniform Random Number Generation in SNOW Clusters}
\alias{clusterSetupRNG}
\alias{clusterSetupSPRNG}
\alias{clusterSetupRNGstream}
\usage{
clusterSetupRNG (cl, type = "RNGstream", ...)

clusterSetupRNGstream (cl, seed=rep(12345,6), ...)
clusterSetupSPRNG (cl, seed = round(2^32 * runif(1)),
                   prngkind = "default", para = 0, ...) 

}
\arguments{
  \item{cl}{Cluster object.}
  \item{type}{\code{type="RNGstream"} (default) initializes the
    L'Ecuyer's RNG.  \code{type="SPRNG"} initializes the
    SPRNG generator.}
  \item{...}{Arguments passed to the underlying function (see details
    bellow).} 
  \item{seed}{Integer value (SPRNG) or a vector of six integer values
    (RNGstream) used as seed
    for the RNG.}
  \item{prngkind}{Character string naming generator type used with SPRNG.}
  \item{para}{Additional parameters for the generator.}
}
\description{
  Initialize independent uniform random number streams to be used in a
  SNOW cluster. It uses either the L'Ecuyer's random number generator
  (package rlecuyer required) or the SPRNG generator (package rsprng required).
}
\details{
  \code{clusterSetupRNG} calls (subject to its argument values) one of
  the other functions, passing arguments \code{(cl, ...)}.  If the
  "SPRNG" type is used, then the function \code{clusterSetupSPRNG} is
  called.  If the "RNGstream" type is used, then the function
  \code{clusterSetupRNGstream} is called.

  \code{clusterSetupSPRNG} loads the \code{rsprng} package and initializes
  separate streams  on each node. For further details see the documentation
  of \code{init.sprng}.  The generator on the master is not affected.

  \code{clusterSetupRNGstream} loads the \code{rlecuyer} package,
  creates one stream per node and distributes the stream states
  to the nodes.

  For more details see
  \url{http://www.stat.uiowa.edu/~luke/R/cluster/cluster.html}.
}
\examples{
  \dontrun{
clusterSetupSPRNG(cl)
clusterSetupSPRNG(cl, seed=1234)
clusterSetupRNG(cl, seed=rep(1,6))
  }
}
\keyword{programming}
