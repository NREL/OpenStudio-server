\name{NRELsnowFT}
\title{NRELsnowFT Objects}
\alias{addClusterOptions}
\alias{recvOneDataFT}
\alias{recvOneDataFT.SOCKcluster}
\alias{recvOneResultFT}
\alias{GetNodefromReplic}
\alias{addtoCluster.SOCKcluster}
\alias{combinecl} 
\alias{getNodeID}
\alias{getNodeID.SOCKnode}
\alias{processStatus.SOCKnode}
\alias{removecl}
\alias{repairCluster.SOCKcluster} 
\alias{updatecl}
\alias{writetomngtfile}
\alias{do.administration}
\alias{do.administration.SOCKcluster}
\alias{is.manageable}
\alias{is.manageable.SOCKcluster}
\alias{manage.replications.and.cluster.size}
\alias{performParallel}
\alias{clusterApplyFT}
\alias{clusterCallpart}
\alias{clusterEvalQpart}
\alias{printClusterInfo}
\alias{makeClusterFT}
\alias{makeSOCKclusterFT}
\alias{addtoCluster} 
\alias{removefromCluster}
\alias{findFailedNodes}
\alias{processStatus}

\description{
  Functions that extend the collection of cluster-level functions of the
  \pkg{snow} package while providing fault tolerance, reproducibility and additional
  management features. The heart of the package is the function
  \code{performParallel}. 
}

\usage{
performParallel(x, fun, initfun = NULL, exitfun = NULL, 
                printfun = NULL, printargs = NULL, 
                printrepl = max(length(x)/10,1), 
                cltype = getClusterOption("type"),
                cluster.args = NULL, ipList = NULL,
                mngtfiles = c(".clustersize",".proc",".proc_fail"),
                ft_verbose = FALSE)

clusterApplyFT(cl, x, fun, initfun = NULL, exitfun = NULL, 
               printfun = NULL, printargs = NULL, 
               printrepl = max(length(x)/10,1), 
               mngtfiles = c(".clustersize",".proc",".proc_fail"), 
               ft_verbose = FALSE)

clusterEvalQpart(cl, nodes, expr)

printClusterInfo(cl)
}
\arguments{
  \item{ipList}{list of cluster nodes IP addresses.}
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
  \code{\link{makeClusterFT}}). Possible values are 'SOCK' ('PVM','MPI' is currently not available).}
\item{cluster.args}{List of arguments passed to the function \code{\link{makeClusterFT}}. For the \sQuote{SOCK} layer, the most useful argument in this list is \code{names} which can contain a vector of host names, or a list containing specification for each host (see Example in \code{\link[snow]{makeCluster}}). Due to the dynamic resizing feature, the length of this vector (or list) does not need to match the size of the cluster - it is used as a pool from which hosts are taken as they are needed. Another useful argument is \code{outfile}, specifying name of a file to which slave node output is to be directed.}
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
\keyword{NRELsnowFT}
