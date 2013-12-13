\name{snowFT-cluster}
\title{Cluster-Level Functions with Fault Tolerance Features}
\alias{performParallel}
\alias{clusterApplyFT}
\alias{clusterCallpart}
\alias{clusterEvalQpart}
\alias{printClusterInfo}

\description{
  Functions that extend the collection of cluster-level functions of the
  \pkg{snow} package while providing fault tolerance, reproducibility and additional
  management features. The heart of the package is the function
  \code{performParallel}. 
}
\usage{
performParallel(count, x, fun, initfun = NULL, exitfun = NULL, 
                printfun = NULL, printargs = NULL, 
                printrepl = max(length(x)/10,1), 
                cltype = getClusterOption("type"),
                cluster.args = NULL,
                gentype = "RNGstream", seed = sample(1:9999999,6), 
                prngkind = "default", para = 0, 
                mngtfiles = c(".clustersize",".proc",".proc_fail"),
                ft_verbose = FALSE, ...)

clusterApplyFT(cl, x, fun, initfun = NULL, exitfun = NULL, 
               printfun = NULL, printargs = NULL, 
               printrepl = max(length(x)/10,1), gentype = "None", 
               seed = rep(123456,6), prngkind = "default", para = 0, 
               mngtfiles = c(".clustersize",".proc",".proc_fail"), 
               ft_verbose = FALSE, ...)
               
clusterCallpart(cl, nodes, fun, ...)

clusterEvalQpart(cl, nodes, expr)

printClusterInfo(cl)
}
\arguments{
  \item{count}{Number of cluster nodes. If \code{count=0}, the process runs sequentially.}
  \item{cl}{Cluster object.}
  \item{x}{Vector of values to be passed to function \code{fun}. 
  	Its length determines how many times \code{fun} is to
  be called. \code{x[i]} is passed to \code{fun} (as its first argument)
  in the i-th call.}
  \item{fun}{Function or character string naming a function.}
\item{initfun}{Function or character string naming a
function with no
  arguments that is to
  be called on each node prior to the computation. 
  It can be used for example for loading required libraries.}
\item{exitfun}{Function or character string naming a function with no
  arguments that is to
  be called on each node after the computation is completed.}
\item{printfun, printargs, printrepl}{\code{printfun} is a function or
  character string naming a function that is to be called on the master
  node after each
  \code{printrepl} completed replicates, and thus it can be used for accessing
  intermediate results. Arguments passed to
  \code{printfun} are: a list (of length \code{|x|}) of results (including
the non-finished
  ones), the number of finished results,
  and \code{printargs}.}
\item{cltype}{Character string that specifies cluster type (see
  \code{\link{makeClusterFT}}). Possible values are 'MPI' and 'SOCK' ('PVM' is currently not available).}
\item{cluster.args}{List of arguments passed to the function \code{\link{makeClusterFT}}. For the \sQuote{SOCK} layer, the most useful argument in this list is \code{names} which can contain a vector of host names, or a list containing specification for each host (see Example in \code{\link[snow]{makeCluster}}). Due to the dynamic resizing feature, the length of this vector (or list) does not need to match the size of the cluster - it is used as a pool from which hosts are taken as they are needed. Another useful argument is \code{outfile}, specifying name of a file to which slave node output is to be directed.}
\item{gentype}{Character string that specifies the type of the random number generator (RNG). 
	Possible values: "RNGstream" (L'Ecuyer's RNG),
  "SPRNG", or "None", see
\code{\link{clusterSetupRNG.FT}}. If
  \code{gentype="None"}, no RNG action is taken.}
\item{seed, prngkind, para}{Seed, kind and parameters for the RNG (see
  \code{\link{clusterSetupRNG.FT}}).}
\item{mngtfiles}{A character vector of length 3 containing names of
  management files: \code{mngtfiles[1]} for managing the
  cluster size, \code{mngtfiles[2]} for monitoring replicates
  as they are processed, \code{mngtfiles[3]} for monitoring failed
  replicates. If any of these files equals an empty string, the
  corresponding management actions (i.e. dynamic cluster resizing, outputting processed replicates, and cluster repair in case of failures) are not performed. If the files
  already exist, their content
  is overwritten. Note that the cluster repair action is only available for PVM. Furthermore, the dynamic cluster resizing is not available for MPI.}
  \item{ft_verbose}{If TRUE, debugging messages are sent to standard output.}
  \item{nodes}{Indices of cluster nodes.}
  \item{expr}{Expression to evaluate.}

  \item{...}{Additional arguments to pass to function \code{fun}.}
}

\details{
  \code{clusterApplyFT} is a fault tolerant version of
  \code{clusterApplyLB} of the snow package with additional features, such as results
  reproducibility, computation transparency and dynamic cluster
resizing. The master process searches for failed nodes in its
  waiting time. If failures are detected, the cluster is
  repaired. All failed computations are restarted (in three additional
  runs) after the replication
  loop is finished, and hence the user should not notice any
  interruptions.

 The file \code{mngtfiles[1]} (which defaults to \sQuote{.clustersize}) is initially written by the master
  prior to the computation and it contains a single integer value corresponding
  to the number of cluster nodes. Then the value can be arbitrarily changed by
  the user (but should remain in the same format). The master reads the
  file  in its waiting time. If the value in this file is larger than
  the current
  cluster size, new nodes are created and the computation is expanded on
  them. If on the other hand the value is smaller, nodes are
  successively discarded after they finish their current
  computation.
  The arguments \code{initfun, exitfun} in
\code{clusterApplyFT} are only used, if there are
  changes in the cluster, i.e. if new nodes are added or if nodes are
  removed from cluster.

  The RNG uses
the scheme 'one stream per replicate', in contrary to 'one stream per
node' used by \code{clusterApplyLB}. Therefore with each replicate, the
RNG is reset to the corresponding stream (identified by the replicate
number). Thus, the final results are reproducible.

  \code{performParallel} is a wrapper function for
  \code{clusterApplyFT} and we recommend using this function rather than
  using \code{clusterApplyFT} directly. It creates a cluster of
\code{count} nodes,
  on all nodes it
  calls \code{initfun} and initializes the RNG. Then it calls
  \code{clusterApplyFT}. After the computation is finished, it calls
  \code{exitfun} on all nodes and stops the cluster. If \code{count=0}, function \code{fun} is invoked sequentially with the same settings (including random numbers) as it would in parallel. This mode can be used for debugging purposes.

  \code{clusterCallpart} calls a function \code{fun} with identical arguments 
  \code{...} on nodes
  specified by indices \code{nodes} in the cluster \code{cl} and returns a list
  of the results.
  
  \code{clusterEvalQpart} evaluates a literal expression on nodes
  specified by indices \code{nodes}. 
  
  \code{printClusterInfo} prints out some basic information about the cluster.
}

\value{\code{clusterApplyFT} returns a list of two elements. The first
  one is a list (of length \code{|x|}) of results, the second one is the
(possibly updated)
  cluster object.

  \code{performParallel} returns a list of results.
}
\examples{
\dontrun{
# generates n normally distributed random numbers in r replicates
# on p nodes and prints their mean after each r/10 replicate.

printfun <- function(res, n, args=NULL) {
  res <- unlist(res)
  res <- res[!is.null(res)]
  print(paste("mean after:", n,"replicates:", mean(res),
           "(from",length(res),"RNs)"))
  }

r<-1000; n<-100; p<-5
res <- performParallel(p, rep(n,r), fun=rnorm,
  gentype="RNGstream", seed=rep(1,6), printfun=printfun)

# Setting p<-0 will run rnorm sequentially and should give 
# exactly the same results
}
}

\keyword{programming}
\author{Hana Sevcikova}
