#
# PVM Implementation
#

newPVMnode <- function(where = "",
                       options = defaultClusterOptions, rank) {
    # **** allow some form of spec here
    # **** make sure options are quoted
    scriptdir <- getClusterOption("scriptdir", options)
    outfile <- getClusterOption("outfile", options)
    homogeneous <- getClusterOption("homogeneous", options)
    if (getClusterOption("useRscript", options)) {
        if (homogeneous) {
            rscript <- shQuoteIfNeeded(getClusterOption("rscript", options))
            snowlib <- getClusterOption("snowlib", options)
            script <- shQuoteIfNeeded(file.path(snowlib, "snow", "RPVMnode.R"))
            args <- c(script,
                      paste("SNOWLIB=", snowlib, sep=""),
                      paste("OUT=", outfile, sep=""))
            pvmtask <- rscript
        }
        else {
            args <- c("RPVMnode.R",
                      paste("OUT=", outfile, sep=""))
            pvmtask <- "RunSnowWorker"
        }
    }
    else {
        if (homogeneous) {
            script <- shQuoteIfNeeded(file.path(scriptdir, "RPVMnode.sh"))
            rlibs <- paste(getClusterOption("rlibs", options), collapse = ":")
            rprog <- shQuoteIfNeeded(getClusterOption("rprog", options))
            args <- c(paste("RPROG=", rprog, sep=""),
                      paste("OUT=", outfile, sep=""),
                      paste("R_LIBS=", rlibs, sep=""),
                      script)
        }
        else
            args <- c(paste("OUT=", outfile, sep=""),
                      "RunSnowNode", "RPVMnode.sh")
        pvmtask <- "/usr/bin/env"
    }
    tid <- .PVM.spawn(task=pvmtask, arglist = args, where = where)
    structure(list(tid = tid, RECVTAG = 33,SENDTAG = 22, rank = rank), class = "PVMnode")
}

makePVMmaster <- function()
    structure(list(tid = .PVM.parent (), RECVTAG = 22, SENDTAG = 33),
              class = "PVMnode")

sendData.PVMnode <- function(node, data) {
    .PVM.initsend ()
    .PVM.serialize(data, node$con)
    .PVM.send (node$tid, node$SENDTAG)
}

recvData.PVMnode <- function(node) {
    .PVM.recv (node$tid, node$RECVTAG)
    .PVM.unserialize(node$con)
}

recvOneData.PVMcluster <- function(cl) {
    rtag <- findRecvOneTag(cl, -1)
    binfo <- .PVM.bufinfo(.PVM.recv(-1, rtag))
    for (i in seq(along = cl)) {
        if (cl[[i]]$tid == binfo$tid) {
            n <- i
            break
        }
    }
    data <- .PVM.unserialize()
    list(node = n, value = data)
}

makePVMcluster <- function(count, ..., options = defaultClusterOptions) {
    if (! require(rpvm))
        stop("the `rpvm' package is needed for PVM clusters.")
    options <- addClusterOptions(options, list(...))
    cl <- vector("list",count)
    for (i in seq(along=cl))
        cl[[i]] <- newPVMnode(options = options, rank = i)
    class(cl) <- c("PVMcluster", "cluster")
    cl
}
