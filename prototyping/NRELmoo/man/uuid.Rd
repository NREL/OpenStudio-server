\name{uuid}
\alias{uuid}
\title{Version 4 UUID}
\description{Create a Version 4 UUID.}
\usage{
uuid(uppercase=FALSE)
}
\arguments{
  \item{uppercase}{(FALSE)|TRUE}
}
\value{
  Version 4 UUID.
}
\author{
Brian Ball \email{brian.ball@nrel.gov}
}
\references{ http://www.r-bloggers.com/generate-uuids-in-r/
}
\examples{
#create a Version 4 UUID
uuid()
}
