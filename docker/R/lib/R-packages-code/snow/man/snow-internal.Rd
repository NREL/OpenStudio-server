\name{snow-internal}
\title{Internal SNOW Objects}
\alias{runMPIslave}
\alias{setMPIcluster}
\alias{stopCluster.default}
\alias{stopCluster.MPIcluster}
\alias{stopCluster.spawnedMPIcluster}
\alias{stopCluster.NWScluster}
\alias{defaultClusterOptions}
\alias{docall}
\alias{slaveLoop}
\alias{sinkWorkerOutput}
\alias{newSOCKnode}
\alias{makeSOCKmaster}
\alias{closeNode.SOCKnode}
\alias{sendData.SOCKnode}
\alias{recvData.SOCKnode}
\alias{newPVMnode}
\alias{makePVMmaster}
\alias{closeNode.PVMnode}
\alias{sendData.PVMnode}
\alias{recvData.PVMnode}
\alias{newMPInode}
\alias{makeMPImaster}
\alias{closeNode.MPInode}
\alias{sendData.MPInode}
\alias{recvData.MPInode}
\alias{newNWSnode}
\alias{makeNWSmaster}
\alias{closeNode.NWSnode}
\alias{sendData.NWSnode}
\alias{recvData.NWSnode}
\alias{closeNode}
\alias{closeNode.default}
\alias{sendData}
\alias{recvData}
\alias{sendNode}
\alias{postNode}
\alias{stopNode}
\alias{sendCall}
\alias{recvResult}
\alias{initSprngNode}
\alias{initRNGstreamNode}
\alias{splitIndices}
\alias{splitList}
\alias{splitRows}
\alias{splitCols}
\alias{addClusterOptions}
\alias{initDefaultClusterOptions}
\alias{findRecvOneTag}
\alias{recvOneData}
\alias{recvOneData.MPIcluster}
\alias{recvOneData.PVMcluster}
\alias{recvOneData.SOCKcluster}
\alias{recvOneData.NWScluster}
\alias{recvOneResult}
\alias{getClusterOption}
\alias{checkCluster}
\alias{checkForRemoteErrors}
\alias{staticClusterApply}
\alias{dynamicClusterApply}
\alias{[.cluster}
\alias{shQuoteIfNeeded}
\usage{
\method{stopCluster}{default}(cl)
\method{stopCluster}{MPIcluster}(cl)
\method{stopCluster}{spawnedMPIcluster}(cl)
\method{stopCluster}{NWScluster}(cl)
defaultClusterOptions
addClusterOptions(options, new)
initDefaultClusterOptions(libname)

docall(fun, args)
slaveLoop(master)
sinkWorkerOutput(outfile)

newSOCKnode(machine = "localhost", ..., options = defaultClusterOptions, rank)
makeSOCKmaster(master = Sys.getenv("MASTER"), port = Sys.getenv("PORT"))
\method{closeNode}{SOCKnode}(node)
\method{sendData}{SOCKnode}(node, data)
\method{recvData}{SOCKnode}(node)

newPVMnode(where = "", options = defaultClusterOptions, rank)
makePVMmaster()
\method{sendData}{PVMnode}(node, data)
\method{recvData}{PVMnode}(node)

setMPIcluster(new)
runMPIslave()
newMPInode(rank, comm)
makeMPImaster(comm)
\method{sendData}{MPInode}(node, data)
\method{recvData}{MPInode}(node)

closeNode(node)
\method{closeNode}{default}(node)
sendData(node, data)
recvData(node)

postNode(con, type, value = NULL, tag = NULL)
stopNode(n)

sendCall(con, fun, args, return = TRUE, tag = NULL)
recvResult(con)

initSprngNode(streamno, nstream, seed, kind, para) 
initRNGstreamNode(stream)

splitIndices(nx, ncl)
splitList(x, ncl)
splitRows(x, ncl)
splitCols(x, ncl)

findRecvOneTag(cl, anytag)
recvOneData(cl)
recvOneResult(cl)
\method{recvOneData}{MPIcluster}(cl)
\method{recvOneData}{PVMcluster}(cl)
\method{recvOneData}{SOCKcluster}(cl)
\method{recvOneData}{NWScluster}(cl)
getClusterOption(name, options = defaultClusterOptions)

checkCluster(cl)
checkForRemoteErrors(val)
staticClusterApply(cl, fun, n, argfun)
dynamicClusterApply(cl, fun, n, argfun)
\method{[}{cluster}(cl, ...)

shQuoteIfNeeded(p)
}
\description{
  Internal functions for the snow package.
}
\details{
  These are not to be called by the user.
}
\keyword{internal}
