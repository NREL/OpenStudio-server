\name{vectorgrad}
\alias{vectorgrad}
\title{vectorgrad}
\description{vectorized gradient}
\usage{
vectorgrad(func, x, method="one", eps=1e-4, cl=NULL, debug=FALSE, lb=NULL, ub=NULL)
}
\arguments{
  \item{func}{f}
  \item{x}{x}
  \item{method}{one|two|four}
  \item{eps}{epsilon}
  \item{cl}{cluster object}
  \item{debug}{debug flag}
  \item{lb}{lower bound vector}
  \item{ub}{upper bound vector}
}
\value{
  numerical gradient of f.
}
\author{
Brian Ball \email{brian.ball@nrel.gov}
}
\references{ http://www.r-bloggers.com/generate-uuids-in-r/
}
\examples{
#vectorgrad(func, x, method="one", eps=1e-4, cl=NULL)
}
