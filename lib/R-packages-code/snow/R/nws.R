#
# NWS Implementation
#

# driver side
newNWSnode <- function(machine = "localhost", tmpWsName, rank, ws,
                       wsServer, state, options) {
    if (is.list(machine)) {
        options <- addClusterOptions(options, machine)
        machine <- machine$host
    }
    outfile <- getClusterOption("outfile", options)
    master <- getClusterOption("master", options)
    port <- getClusterOption("port", options)
    manual <- getClusterOption("manual", options)

    ## build the local command for starting the worker
    homogeneous <- getClusterOption("homogeneous", options)
    if (getClusterOption("useRscript", options)) {
        if (homogeneous) {
            rscript <- shQuoteIfNeeded(getClusterOption("rscript", options))
            snowlib <- getClusterOption("snowlib", options)
            script <- shQuoteIfNeeded(file.path(snowlib, "snow", "RNWSnode.R"))
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile,
                         " SNOWLIB=", snowlib,
                         " RANK=", rank,
                         " TMPWS=", tmpWsName, sep="")
            cmd <- paste(rscript, script, env)
        }
        else {
            script <- "RunSnowWorker RNWSnode.R"
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile,
                         " RANK=", rank,
                         " TMPWS=", tmpWsName, sep="")
            cmd <- paste(script, env)
        }
    }
    else {
        if (homogeneous) {
            scriptdir <- getClusterOption("scriptdir", options)
            script <- shQuoteIfNeeded(file.path(scriptdir, "RNWSnode.sh"))
            rlibs <- paste(getClusterOption("rlibs", options), collapse = ":")
            rprog <- shQuoteIfNeeded(getClusterOption("rprog", options))
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile,
                         " RANK=", rank,
                         " TMPWS=", tmpWsName,
                         " RPROG=", rprog,
                         " R_LIBS=", rlibs, sep="")
        }
        else {
            script <- "RunSnowNode RNWSnode.sh"
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile,
                         " RANK=", rank,
                         " TMPWS=", tmpWsName, sep="")
        }
        cmd <- paste("env", env, script)
    }

    if (manual) {
        cat("Manually start worker on", machine, "with\n    ", cmd, "\n")
        flush.console()
    }
    else {
        ## add the remote shell command if needed
        if (machine != "localhost") {
            rshcmd <- getClusterOption("rshcmd", options)
            user <- getClusterOption("user", options)
            cmd <- paste(rshcmd, "-l", user, machine, cmd)
        }

        if (.Platform$OS.type == "windows") {
            ## On windows using input = something seems needed to
            ## disconnect standard input of an ssh process when run
            ## from Rterm (at least using putty's plink).  In
            ## principle this could also be used for supplying a
            ## password, but that is probably a bad idea. So, for now
            ## at least, on windows password-less authentication is
            ## necessary.
            system(cmd, wait = FALSE, input = "")
        }
        else system(cmd, wait = FALSE)
    }

    node <- structure(list(ws = ws,
                           wsServer = wsServer,
                           incomingVar = 'forDriver',
                           outgoingVar = sprintf('forNode%04d', rank),
                           rank = rank,
                           state = state,
                           mybuffer = sprintf('buffer%04d', rank),
                           host = machine),
                      class = "NWSnode")
    recvData(node) ## wait for "ping" from worker
    node
}

# compute engine side
makeNWSmaster <- function() {
    if (! require(nws))
        stop("the `nws' package is needed for NWS clusters.")

    ws <- netWorkSpace(tmpWs <- Sys.getenv("TMPWS"),
                       serverHost = Sys.getenv("MASTER"),
                       port = as.integer(Sys.getenv("PORT")))

    rank = as.integer(Sys.getenv("RANK"))
    structure(list(ws = ws,
                   outgoingVar = 'forDriver',
                   incomingVar = sprintf('forNode%04d', rank),
                   rank = rank),
              class = "NWSnode")
}

closeNode.NWSnode <- function(node) {}

# note that all messages to the driver include the rank of the sender.
# in a context where this information is not needed (and would be
# unexpected), we strip it out.  we can do this because the driver
# signals its interest in the node's identity implicitly via a call to
# recvOneData, rather than recvData.  if this ever changes, we will have
# to revisit this hack.
sendData.NWSnode <- function(node, data) {
  if (node$outgoingVar == 'forDriver')
    data <- list(node = node$rank, data = data)
  nwsStore(node$ws, node$outgoingVar, data)
}

recvData.NWSnode <- function(node) {
  if (node$incomingVar != 'forDriver') {
    data <- nwsFetch(node$ws, node$incomingVar)
  }
  else {
    # first check if we have already received a message for this node
    if (! is.null(node$state[[node$mybuffer]])) {
      # cat("debug: found a buffered message for", node$rank, "\n")
      data <- node$state[[node$mybuffer]]
      node$state[[node$mybuffer]] <- NULL
    }
    else {
      repeat {
        # get the next message
        d <- nwsFetch(node$ws, node$incomingVar)

        # find out who this data is from
        rank <- d$node
        data <- d$data

        # if it's from worker node$rank, we're done
        if (rank == node$rank) {
          # cat("debug: received the right message for", rank, "\n")
          break
        }

        # it's not, so stash this in node$state$buffer<rank>,
        # issuing a warning if node$state$buffer<rank> is not empty
        # cat("debug: received a message for", rank,
        #     "when I want one for", node$rank, "\n")
        k <- sprintf('buffer%04d', rank)
        if (! is.null(node$state[[k]]))
          warning("overwriting previous message")
        node$state[[k]] <- data
      }
    }
  }
  data
}

# only called from the driver and only when we care about
# the source of the data.
recvOneData.NWScluster <- function(cl) {
  # check if there is any previously received data
  # (I don't think there ever should be)
  for (i in seq(along=cl)) {
    bname <- sprintf('buffer%04d', i)
    if (! is.null(cl[[1]]$state[[bname]])) {
      # cat("debug: received a buffered message from node", i, "\n")
      warning("recvOneData called while there is buffered data",
         immediate.=TRUE)
      data <- cl[[1]]$state[[bname]]
      cl[[1]]$state[[bname]] <- NULL
      return(list(node = i, value = data))
    }
  }
  d <- nwsFetch(cl[[1]]$ws, 'forDriver')
  # cat("debug: received a message from node", d$node, "\n")
  list(node = d$node, value = d$data)
}

makeNWScluster <- function(names=rep('localhost', 3), ..., options = defaultClusterOptions) {
    if (! require(nws))
        stop("the `nws' package is needed for NWS clusters.")

    # this allows makeNWScluster to be called like makeMPIcluster and
    # makePVMcluster
    if (is.numeric(names))
        names <- rep('localhost', names[1])

    options <- addClusterOptions(options,
       list(port = 8765, scriptdir = path.package("snow")))
    options <- addClusterOptions(options, list(...))

    wsServer <- nwsServer(serverHost = getClusterOption("master", options),
                           port = getClusterOption("port", options))

    state <- new.env()

    tmpWsName = nwsMktempWs(wsServer, 'snow_nws_%04d')
    ws = nwsOpenWs(wsServer, tmpWsName)
    cl <- vector("list", length(names))
    for (i in seq(along=cl))
        cl[[i]] <- newNWSnode(names[[i]], tmpWsName = tmpWsName, rank = i,
                              ws = ws, wsServer = wsServer, state = state, options = options)

    class(cl) <- c("NWScluster", "cluster")
    cl
}

stopCluster.NWScluster <- function(cl) {
  NextMethod()
  nwsDeleteWs(cl[[1]]$wsServer, nwsWsName(cl[[1]]$ws))
  close(cl[[1]]$wsServer)
}
