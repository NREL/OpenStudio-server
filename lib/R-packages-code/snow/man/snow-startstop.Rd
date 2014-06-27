\name{snow-startstop}
\title{Starting and Stopping SNOW Clusters}
\alias{getMPIcluster}
\alias{makeMPIcluster}
\alias{makePVMcluster}
\alias{makeNWScluster}
\alias{makeSOCKcluster}
\alias{makeCluster}
\alias{stopCluster}
\alias{setDefaultClusterOptions}
\usage{
makeCluster(spec, type = getClusterOption("type"), ...)
stopCluster(cl)

setDefaultClusterOptions(...)

makeSOCKcluster(names, ..., options = defaultClusterOptions)
makePVMcluster(count, ..., options = defaultClusterOptions)
makeMPIcluster(count, ..., options = defaultClusterOptions)
makeNWScluster(names, ..., options = defaultClusterOptions)
getMPIcluster()
}
\arguments{
  \item{spec}{cluster specification}
  \item{count}{number of nodes to create}
  \item{names}{character vector of node names}
  \item{options}{cluster options object}
  \item{cl}{cluster object}
  \item{...}{cluster option specifications}
  \item{type}{character; specifies cluster type.}
}
\description{
  Functions to start and stop a SNOW cluster and to set default cluster
  options.
}
\details{
  \code{makeCluster} starts a cluster of the specified or default type
  and returns a reference to the cluster.  Supported cluster types are
  \code{"SOCK"}, \code{"PVM"}, \code{"MPI"}, and \code{"NWS"}.  For
  \code{"PVM"} and
  \code{"MPI"} clusters the \code{spec} argument should be an integer
  specifying the number of slave nodes to create.  For \code{"SOCK"} and
  \code{"NWS"}
  clusters \code{spec} should be a character vector naming the hosts on
  which slave nodes should be started; one node is started for each
  element in the vector.  For \code{"SOCK"} and \code{"NWS"} clusters
  \code{spec} can also be an integer specifying the
  number of slaves nodes to create on the local machine.

  For \code{SOCK} and \code{NWS} clusters the \code{spec} can also be a
  list of machine specifications, each a list of named option values.
  Such a list must include a character value named \code{host} host
  specifying the name or address of the host to use.  Any other option
  can be specified as well.  For \code{SOCK} and \code{NWS} clusters
  this may be a more convenient alternative than inhomogeneous cluster
  startup procedure.  The options \code{rscript} and \code{snowlib} are
  often useful; see the examples below.

  \code{stopCluster} should be called to properly shut down the cluster
  before exiting R.  If it is not called it may be necessary to use
  external means to ensure that all slave processes are shut down.

  \code{setDefaultClusterOptions} can be used to specify alternate
  values for default cluster options.  There are many options.  The
  most useful ones are \code{type} and \code{homogeneous}.  The
  default value of the \code{type} option is currently set to
  "MPI" if \pkg{Rmpi} is on the search path.  Otherwise it is set to
  \code{"PVM"} if the \pkg{rpvm} package is available, to \code{"MPI"}
  if \pkg{Rmpi} is available but \pkg{rpvm} is not, and to
  \code{"SOCK"} if neither of these packages is found.

  The \code{homogeneous} option should be set to \code{FALSE} to
  specify that the startup procedure for inhomogeneous clusters is to
  be used; this requires some additional configuration. The default
  setting is \code{TRUE} unless the environment variable
  \code{R_SNOW_LIB} is defined on the master host with a non-empty
  value.

  The option\code{outfile} can be used to specify the file to which
  slave node output is to be directed.  The default is \code{/dev/null};
  during debugging of an installation it can be useful to set this to a
  proper file.  On some systems setting \code{outfile} to \code{""} or
  to \code{/dev/tty} will result in worker output being sent tothe
  terminal running the master process.

  The functions \code{makeSOCKcluster}, \code{makePVMcluster},
  \code{makeMPIcluster}, and \code{makeNWScluster} can be used to start
  a cluster of the corresponding type.

  In MPI configurations where process spawning is not available and
  something like \code{mpirun} is used to start a master and a set of slaves
  the corresponding cluster will have been pre-constructed and can be obtained
  with \code{getMPIcluster}.  It is also possible to obtain a reference
  to the running cluster using \code{makeCluster} or
  \code{makeMPIcluster}.  In this case the \code{count} argument can be
  omitted; if it is supplied, it must equal the number of nodes in the
  cluster.  This interface is still experimental and
  subject to change.

  For SOCK and NWS clusters the option \code{manual = TRUE} forces a
  manual startup mode in which the master prints the command to be run
  manually to start a worker process. Together with setting the
  \code{outfile} option this can be useful for debugging cluster startup.

  For more details see
  \url{http://www.stat.uiowa.edu/~luke/R/cluster/cluster.html}.
}
\examples{
  \dontrun{
## Two workers run on the local machine as a SOCK cluster.
cl <- makeCluster(c("localhost","localhost"), type = "SOCK")
clusterApply(cl, 1:2, get("+"), 3)
stopCluster(cl)
## Another approach to running on the local machine as a SOCK cluster.
cl <- makeCluster(2, type = "SOCK")
clusterApply(cl, 1:2, get("+"), 3)
stopCluster(cl)
## A SOCK cluster with two workers on Mac OS X, two on Linux, and two
## on Windows:
macOptions <-
    list(host = "owasso",
         rscript = "/Library/Frameworks/R.framework/Resources/bin/Rscript",
         snowlib = "/Library/Frameworks/R.framework/Resources/library")
lnxOptions <-
    list(host = "itasca",
         rscript = "/usr/lib64/R/bin/Rscript",
	 snowlib = "/home/luke/tmp/lib")
winOptions <-
    list(host="192.168.1.168",
         rscript="C:/Program Files/R/R-2.7.1/bin/Rscript.exe",
         snowlib="C:/Rlibs")
cl <- makeCluster(c(rep(list(macOptions), 2), rep(list(lnxOptions), 2),
                    rep(list(winOptions), 2)), type = "SOCK")
clusterApply(cl, 1:6, get("+"), 3)
stopCluster(cl)
  }
}
\keyword{programming}
