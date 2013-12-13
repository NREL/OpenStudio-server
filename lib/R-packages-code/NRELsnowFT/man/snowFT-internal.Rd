\name{snowFT-internal}
\title{Internal snowFT Objects}
\alias{initStream}
\alias{freeStream}
\alias{resetRNG}
\alias{addClusterOptions}
\alias{recvOneDataFT}
\alias{recvOneDataFT.MPIcluster}
%\alias{recvOneDataFT.PVMcluster}
\alias{recvOneDataFT.SOCKcluster}
\alias{recvOneResultFT}
\alias{GetNodefromReplic}
\alias{addtoCluster.MPIcluster}
%\alias{addtoCluster.PVMcluster}
\alias{addtoCluster.SOCKcluster}
\alias{checkSprngNode} 
\alias{checkSPRNG}
\alias{clusterCheckSPRNG} 
\alias{combinecl} 
\alias{getNodeID}
\alias{getNodeID.MPInode}
%\alias{getNodeID.PVMnode}
\alias{getNodeID.SOCKnode}
\alias{initRNGstreamNodeRepli}
\alias{performSequential} 
\alias{processStatus.MPInode} 
%\alias{processStatus.PVMnode}
\alias{processStatus.SOCKnode}
\alias{removecl}
%\alias{repairCluster.PVMcluster}
\alias{repairCluster.SOCKcluster} 
\alias{repairCluster.MPIcluster} 
\alias{updatecl}
\alias{writetomngtfile}

\alias{do.administration}
\alias{do.administration.MPIcluster}
%\alias{do.administration.PVMcluster}
\alias{do.administration.SOCKcluster}
\alias{is.manageable}
\alias{is.manageable.MPIcluster}
%\alias{is.manageable.PVMcluster}
\alias{is.manageable.SOCKcluster}
\alias{manage.replications.and.cluster.size}
\usage{
\method{getNodeID}{SOCKnode}(node)
\method{processStatus}{SOCKnode}(node)

%\method{addtoCluster}{PVMcluster}(cl, spec, ..., options = defaultClusterOptions)
\method{addtoCluster}{SOCKcluster}(cl, spec, ..., options = defaultClusterOptions)
\method{addtoCluster}{MPIcluster}(cl, spec, ..., options = defaultClusterOptions)
%\method{getNodeID}{PVMnode}(node)
\method{getNodeID}{MPInode}(node)
%\method{processStatus}{PVMnode}(node)
%\method{repairCluster}{PVMcluster}(cl, nodes, ..., options = defaultClusterOptions)

initStream(type="RNGstream", name, ...)
freeStream(type="RNGstream", oldrng)
resetRNG(cl, nodes, repl, gentype="RNGstream",seed=rep(123456,6))
checkSprngNode()
clusterCheckSPRNG(cl, prngkind = "default", ...)
initRNGstreamNodeRepli(seed, n)

\method{recvOneDataFT}{MPIcluster}(cl, type='b', time=0)
%\method{recvOneDataFT}{PVMcluster}(cl, type='b', time=0)
\method{recvOneDataFT}{SOCKcluster}(cl, type='b', time=0)

GetNodefromReplic(cl,replic)
combinecl(oldcl, add)
removecl(oldcl, reps)
updatecl(cl, compcl)
writetomngtfile(cl, file)
}
\description{
  Internal functions for the snowFT package.
}
\details{
  These are not to be called by the user.
}
\keyword{internal}
