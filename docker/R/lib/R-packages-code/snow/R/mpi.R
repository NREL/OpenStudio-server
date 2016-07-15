#
# MPI Implementation
#

newMPInode <- function(rank, comm)
    structure(list(rank = rank, RECVTAG = 33, SENDTAG = 22, comm = comm),
              class = "MPInode")

makeMPImaster <- function(comm = 0)
    structure(list(rank = 0, RECVTAG = 22, SENDTAG = 33, comm = comm),
              class = "MPInode")

sendData.MPInode <- function(node, data)
    mpi.send.Robj(data, node$rank, node$SENDTAG, node$comm)

recvData.MPInode <- function(node)
    mpi.recv.Robj(node$rank, node$RECVTAG, node$comm)

recvOneData.MPIcluster <- function(cl) {
    rtag <- findRecvOneTag(cl, mpi.any.tag())
    comm <- cl[[1]]$comm  # should all be the same
    status <- 0
    mpi.probe(mpi.any.source(), rtag, comm, status)
    srctag <- mpi.get.sourcetag(status)
    data <- mpi.recv.Robj(srctag[1], srctag[2], comm)
    list(node = srctag[1], value = data)
}

getMPIcluster <- NULL
setMPIcluster <- NULL
local({
    cl <- NULL
    getMPIcluster <<- function() cl
    setMPIcluster <<- function(new) cl <<- new
})

makeMPIcluster <- function(count, ..., options = defaultClusterOptions) {
    options <- addClusterOptions(options, list(...))
    cl <- getMPIcluster()
    if (! is.null(cl)) {
        if (missing(count) || count == length(cl))
             cl
        else stop(sprintf("MPI cluster of size %d already running",
                          length(cl)))
    }
    else if (missing(count)) {
        # assume something like mpirun -np count+1 has been used to start R
        count <- mpi.comm.size(0) - 1
        if (count <= 0)
            stop("no nodes available.")
        cl <- vector("list",count)
        for (i in seq(along=cl))
            cl[[i]] <- newMPInode(i, 0)
        class(cl) <- c("MPIcluster","cluster")
        setMPIcluster(cl)
        cl
    }
    else {
	# use process spawning to create cluster
        if (! require(Rmpi))
            stop("the `Rmpi' package is needed for MPI clusters.")
        comm <- 1
        intercomm <- 2
        if (mpi.comm.size(comm) > 0)
            stop(paste("a cluster already exists", comm))
        scriptdir <- getClusterOption("scriptdir", options)
        outfile <- getClusterOption("outfile", options)
        homogeneous <- getClusterOption("homogeneous", options)
        if (getClusterOption("useRscript", options)) {
            if (homogeneous) {
                rscript <- shQuoteIfNeeded(getClusterOption("rscript", options))
                snowlib <- getClusterOption("snowlib", options)
                script <- shQuoteIfNeeded(file.path(snowlib, "snow",
                                                    "RMPInode.R"))
                args <- c(script,
                          paste("SNOWLIB=", snowlib, sep=""),
                          paste("OUT=", outfile, sep=""))
                mpitask <- rscript
            }
            else {
                args <- c("RMPInode.R",
                          paste("OUT=", outfile, sep=""))
                mpitask <- "RunSnowWorker"
            }
        }
        else {
            if (homogeneous) {
                script <- shQuoteIfNeeded(file.path(scriptdir, "RMPInode.sh"))
                rlibs <- paste(getClusterOption("rlibs", options),
                               collapse = ":")
                rprog <- shQuoteIfNeeded(getClusterOption("rprog", options))
                args <- c(paste("RPROG=", rprog, sep=""),
                          paste("OUT=", outfile, sep=""),
                          paste("R_LIBS=", rlibs, sep=""),
                          script)
            }
            else {
                args <- c(paste("OUT=", outfile, sep=""),
                          "RunSnowNode", "RMPInode.sh")
            }
            mpitask <- "/usr/bin/env"
        }
        count <- mpi.comm.spawn(slave = mpitask, slavearg = args,
                                nslaves = count, intercomm = intercomm)
        if (mpi.intercomm.merge(intercomm, 0, comm)) {
            mpi.comm.set.errhandler(comm)
            mpi.comm.disconnect(intercomm)
        }
        else stop("Failed to merge the comm for master and slaves.")
        cl <- vector("list",count)
        for (i in seq(along=cl))
            cl[[i]] <- newMPInode(i, comm)
        class(cl) <- c("spawnedMPIcluster",  "MPIcluster", "cluster")
        setMPIcluster(cl)
        cl
    }
}

runMPIslave <- function() {
    comm <- 1
    intercomm <- 2
    mpi.comm.get.parent(intercomm)
    mpi.intercomm.merge(intercomm,1,comm)
    mpi.comm.set.errhandler(comm)
    mpi.comm.disconnect(intercomm)

    slaveLoop(makeMPImaster(comm))

    mpi.comm.disconnect(comm)
    mpi.quit()
}

stopCluster.MPIcluster <- function(cl) {
    NextMethod()
    setMPIcluster(NULL)
}
    
stopCluster.spawnedMPIcluster <- function(cl) {
    comm <- 1
    NextMethod()
    mpi.comm.disconnect(comm)
}

#**** figure out how to get mpi.quit called (similar issue for pvm?)
#**** fix things so stopCluster works in both versions.
#**** need .Last to make sure cluster is shut down on exit of master
#**** figure out why the slaves busy wait under mpirun
