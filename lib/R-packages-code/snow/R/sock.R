#
# Socket Implementation
#

#**** allow user to be different on different machines
#**** allow machines to be selected from a hosts list
newSOCKnode <- function(machine = "localhost", ...,
                        options = defaultClusterOptions, rank) {
    # **** allow some form of spec here
    # **** make sure options are quoted
    options <- addClusterOptions(options, list(...))
    if (is.list(machine)) {
        options <- addClusterOptions(options, machine)
        machine <- machine$host
    }
    outfile <- getClusterOption("outfile", options)
    if (machine == "localhost") master <- "localhost"
    else master <- getClusterOption("master", options)
    port <- getClusterOption("port", options)
    manual <- getClusterOption("manual", options)

    ## build the local command for starting the worker
    homogeneous <- getClusterOption("homogeneous", options)
    if (getClusterOption("useRscript", options)) {
        if (homogeneous) {
            rscript <- shQuoteIfNeeded(getClusterOption("rscript", options))
            snowlib <- getClusterOption("snowlib", options)
            script <- shQuoteIfNeeded(file.path(snowlib, "snow", "RSOCKnode.R"))
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile,
                         " SNOWLIB=", snowlib, sep="")
            cmd <- paste(rscript, script, env)
        }
        else {
            script <- "RunSnowWorker RSOCKnode.R"
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile, sep="")
            cmd <- paste(script, env)
        }
    }
    else {
        if (homogeneous) {
            scriptdir <- getClusterOption("scriptdir", options)
            script <- shQuoteIfNeeded(file.path(scriptdir, "RSOCKnode.sh"))
            rlibs <- paste(getClusterOption("rlibs", options), collapse = ":")
            rprog <- shQuoteIfNeeded(getClusterOption("rprog", options))
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile,
                         " RPROG=", rprog,
                         " R_LIBS=", rlibs, sep="")
        }
        else {
            script <- "RunSnowNode RSOCKnode.sh"
            env <- paste("MASTER=", master,
                         " PORT=", port,
                         " OUT=", outfile, sep="")
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
    
    
    ## need timeout here because of the way internals work
    timeout <- getClusterOption("timeout")
    old <- options(timeout = timeout);
    on.exit(options(old))
    con <- socketConnection(port = port, server=TRUE, blocking=TRUE,
                            open="a+b")
    structure(list(con = con, host = machine, rank = rank), class = "SOCKnode")
}

makeSOCKmaster <- function(master = Sys.getenv("MASTER"),
                           port = Sys.getenv("PORT")) {
    port <- as.integer(port)
    ## maybe use `try' and sleep/retry if first time fails?
    ## need timeout here because of the way internals work
    timeout <- getClusterOption("timeout")
    old <- options(timeout = timeout);
    on.exit(options(old))
    con <- socketConnection(master, port = port, blocking=TRUE, open="a+b")
    structure(list(con = con), class = "SOCKnode")
}

closeNode.SOCKnode <- function(node) close(node$con)

sendData.SOCKnode <- function(node, data) {
##     timeout <- getClusterOption("timeout")
##     old <- options(timeout = timeout);
##     on.exit(options(old))
    serialize(data, node$con)
}

recvData.SOCKnode <- function(node) {
##     timeout <- getClusterOption("timeout")
##     old <- options(timeout = timeout);
##     on.exit(options(old))
    unserialize(node$con)
}

recvOneData.SOCKcluster <- function(cl) {
    socklist <- lapply(cl, function(x) x$con)
    repeat {
        ready <- socketSelect(socklist)
        if (length(ready) > 0) break;
    }
    n <- which(ready)[1]  # may need rotation or some such for fairness
    list(node = n, value = unserialize(socklist[[n]]))
}

makeSOCKcluster <- function(names, ..., options = defaultClusterOptions) {
    if (is.numeric(names))
        names <- rep('localhost', names[1])
    options <- addClusterOptions(options, list(...))
    cl <- vector("list",length(names))
    for (i in seq(along=cl))
        cl[[i]] <- newSOCKnode(names[[i]], options = options, rank = i)
    class(cl) <- c("SOCKcluster", "cluster")
    cl
}
