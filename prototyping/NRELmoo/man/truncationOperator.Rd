\name{truncationOperator}
\alias{truncationOperator}
\title{
Archive Truncation Method
}
\description{
Tournaments are played among several solutions. The best one is chosen according to their fitness with truncate operator. And it is placed in the mating pool.
}
\usage{
truncationOperator(truncateNo, inputData, vNo, oDim)
}
\arguments{
  \item{truncateNo}{truncated index.}
  \item{inputData}{matrix of solutions with objective function values.}
  \item{vNo}{number of decision variables.}
  \item{oDim}{number of objective functions.}
}
\value{
return a matrix of truncated operation of all solutions.
}
\references{
Zitzler, E., Laumanns, M., Thiele, L., SPEA2: Improving the strength pareto evolutionary algorithm. Technical report 103, Computer Engineering and Networks Laboratory (TIK), Swiss Federal Institute of Technology (ETH) Zurich, Gloriastrasse 35, CH-8092 Zurich, Switzerland, 2001.
}
\author{
Ching-Shih (Vince) Tsou \email{cstsou@mail.ntcb.edu.tw}
}
