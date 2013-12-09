\name{sigmaK}
\alias{sigmaK}
\title{
K-Nearest Neighbor Density Estimation
}
\description{
This function estimates the k-nearest neighbor density surrounding a particular solution within each front.
}
\usage{
sigmaK(k, inputData)
}
\arguments{
  \item{k}{k-th nearest neighbor as the density estimate.}
  \item{inputData}{matrix of solutions with objective function values.}
}
\details{
K-th nearest neighbor density estimation technique is incorporated which allows a more precise guidance of the search process. The density at any point is a decreasing function of the distance to the k-th nearest data point.
}
\value{
return a matrix of k-th nearest neighbor of all solutions.
}
\references{
Zitzler, E., Laumanns, M., Thiele, L., SPEA2: Improving the strength pareto evolutionary algorithm. Technical report 103, Computer Engineering and Networks Laboratory (TIK), Swiss Federal Institute of Technology (ETH) Zurich, Gloriastrasse 35, CH-8092 Zurich, Switzerland, 2001.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
