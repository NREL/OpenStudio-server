\name{snow-timing}
\title{Timing SNOW Clusters}
\alias{snow.time}
\alias{plot.snowTimingData}
\alias{print.snowTimingData}
\usage{
snow.time(expr)
\method{print}{snowTimingData}(x, ...)
\method{plot}{snowTimingData}(x, xlab = "Elapsed Time", ylab = "Node",
                              title = "Cluster Usage", ...)
}
\arguments{
  \item{expr}{expression to evaluate}
  \item{x}{timing data object to plot or print}
  \item{xlab}{x axis label}
  \item{ylab}{y axis label}
  \item{title}{plot main title}
  \item{...}{additional arguments}
}
\description{
  Experimental functions to collect and display timing data for cluster
  computations.
}
\details{
  \code{snow.time} collects and returns and returns timing information
  for cluster usage in evaluating \code{expr}. The return value is an
  object of class \code{snowTimingData}; details of the return
  value are subject to change.  The \code{print} method for
  \code{snowTimingData} objects shows the total elapsed time, the total
  communication time between master and worker nodes, and the compute
  time on each worker node.  The \code{plot}, motivated by the display
  produced by \code{xpvm}, produces a Gantt chart of the computation, with
  green rectangles representing active computation, blue horizontal lines
  representing a worker waiting to return a result, and red lines
  representing master/worker communications.  
}
\examples{
  \dontrun{
cl <- makeCluster(2,type="SOCK")
x <- rnorm(1000000)
tm <- snow.time(clusterCall(cl, function(x) for (i in 1:100) sum(x), x))
print(tm)
plot(tm)
stopCluster(cl)
  }
}
\keyword{programming}
