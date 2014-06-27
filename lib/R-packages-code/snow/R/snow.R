#
# Utilities
#

docall <- function(fun, args) {
    if ((is.character(fun) && length(fun) == 1) || is.name(fun))
        fun <- get(as.character(fun), envir = .GlobalEnv, mode = "function")
    do.call("fun", lapply(args, enquote))
}

shQuoteIfNeeded <- function(p) {
    if (length(grep("[[:space:]]", p)) == 0)
        p
    else if (.Platform$OS.type == "windows")
        shQuote(p)
    else stop("file names with spaces do not work properly on this platform")
}


#
# Checking and subsetting
#

checkCluster <- function(cl) {
    if (! inherits(cl, "cluster"))
        stop("not a valid cluster");
}

"[.cluster" <-function(cl,...) {
    v<-unclass(cl)[...]
    class(v)<-class(cl)
    v
}


#
# Slave Loop Function
#

slaveLoop <- function(master) {
    repeat tryCatch({
        msg <- recvData(master)
	cat(paste("Type:", msg$type, "\n"))

        if (msg$type == "DONE") {
            closeNode(master)
            break;
        }
        else if (msg$type == "EXEC") {
            success <- TRUE
            ## This uses the message, rather than the exception since
            ## the exception class/methods may not be available on the
            ## master.
            handler <- function(e) {
                success <<- FALSE
                structure(conditionMessage(e),
                          class=c("snow-try-error","try-error"))
            }
            t1 <- proc.time()
            value <- tryCatch(docall(msg$data$fun, msg$data$args),
                              error = handler)
            t2 <- proc.time()
            value <- list(type = "VALUE", value = value, success = success,
                          time = t2 - t1, tag = msg$data$tag)
            sendData(master, value)
        }
    }, interrupt = function(e) NULL)
}

sinkWorkerOutput <- function(outfile) {
    if (outfile != "") {
        if (.Platform$OS.type == "windows" && outfile == "/dev/null")
            outfile <- "nul:"
        outcon <- file(outfile, open = "w")
        sink(outcon)
        sink(outcon, type = "message")
    }
}


#
# Higher-Level Node Functions
#

closeNode <- function(node) UseMethod("closeNode")
closeNode.default <- function(node) {}

sendData <- function(node, data) UseMethod("sendData")
recvData <- function(node) UseMethod("recvData")

postNode <- function(con, type, value = NULL, tag = NULL) {
    sendData(con, list(type = type, data = value, tag = tag))
}

stopNode <- function(n) {
    postNode(n, "DONE")
    closeNode(n)
}


recvOneData <- function(cl) UseMethod("recvOneData")


#
#  Cluster Creation and Destruction
#

defaultClusterOptions <- NULL

#**** check valid cluster option

initDefaultClusterOptions <- function(libname) {
    rhome <- Sys.getenv("R_HOME")
    if (Sys.getenv("R_SNOW_LIB") != "")
        homogeneous <- FALSE
    else homogeneous <- TRUE
    if (.Platform$OS.type == "windows")
        rscript <- file.path(rhome, "bin", "Rscript.exe")
    else rscript <- file.path(rhome, "bin", "Rscript")
    port <- 10187
    port <- as.integer(Sys.getenv("R_PARALLEL_PORT"))
    if (is.na(port))
        port <-
            11000 + 1000 * ((stats::runif(1L) + unclass(Sys.time())/300) %% 1)
    options <- list(port = as.integer(port),
                    timeout = 60 * 60 * 24 * 30, # 30 days
                    master =  Sys.info()["nodename"],
                    homogeneous = homogeneous,
                    type = NULL,
                    outfile = "/dev/null",
                    rhome = rhome,
                    user = Sys.info()["user"],
                    rshcmd = "ssh",
                    rlibs = Sys.getenv("R_LIBS"),
                    scriptdir = file.path(libname, "snow"),
                    rprog = file.path(rhome, "bin", "R"),
                    snowlib = libname,
                    rscript = rscript,
                    useRscript = file.exists(rscript),
                    manual = FALSE)
    defaultClusterOptions <<- addClusterOptions(emptyenv(), options)
}

addClusterOptions <- function(options, new) {
    if (! is.null(new)) {
        options <- new.env(parent = options)
        names <- names(new)
        for (i in seq(along = new))
            assign(names[i], new[[i]], envir = options)
    }
    options
}

getClusterOption <- function(name, options = defaultClusterOptions)
    get(name, envir = options)

setDefaultClusterOptions <- function(...) {
    list <- list(...)
    names <- names(list)
    for (i in seq(along = list))
        assign(names[i], list[[i]], envir = defaultClusterOptions)
}

makeCluster <- function(spec, type = getClusterOption("type"), ...) {
    if (is.null(type))
        stop("need to specify a cluster type")
    switch(type,
        SOCK = makeSOCKcluster(spec, ...),
        PVM = makePVMcluster(spec, ...),
        MPI = makeMPIcluster(spec, ...),
        NWS = makeNWScluster(spec, ...),
        stop("unknown cluster type"))
}

stopCluster <- function(cl) UseMethod("stopCluster")

stopCluster.default <- function(cl)
    for (n in cl) stopNode(n)


#
# Cluster Functions
#

sendCall <- function (con, fun, args, return = TRUE, tag = NULL) {
    #**** mark node as in-call
    timing <-  .snowTimingData$running()
    if (timing)
        start <- proc.time()[3]
    postNode(con, "EXEC", list(fun = fun, args = args, return = return,
                               tag = tag))
    if (timing)
        .snowTimingData$enterSend(con$rank, start, proc.time()[3])
    NULL
}

recvResult <- function (con)  {
  if (.snowTimingData$running()) {
      start <- proc.time()[3]
      r <- recvData(con)
      end <- proc.time()[3]
      .snowTimingData$enterRecv(con$rank, start, end, r$time[3])
  }
  else r <- recvData(con)
  r$value
}

checkForRemoteErrors <- function(val) {
    count <- 0
    firstmsg <- NULL
    for (v in val) {
        if (inherits(v, "try-error")) {
            count <- count + 1
            if (count == 1) firstmsg <- v
        }
    }
    if (count == 1)
        print(paste("one node produced an error: ", firstmsg))
    else if (count > 1)
        print(paste(count, " nodes produced errors; first error: ",firstmsg))
    val
}

clusterCall  <- function(cl, fun, ...) {
    checkCluster(cl)
    for (i in seq(along = cl))
        sendCall(cl[[i]], fun, list(...))
    checkForRemoteErrors(lapply(cl, recvResult))
}

staticClusterApply <- function(cl, fun, n, argfun) {
    checkCluster(cl)
    p <- length(cl)
    if (n > 0 && p > 0) {
        val <- vector("list", n)
        start <- 1
        while (start <= n) {
            end <- min(n, start + p - 1)
	    jobs <- end - start + 1
            for (i in 1:jobs)
                sendCall(cl[[i]], fun, argfun(start + i - 1))
            val[start:end] <- lapply(cl[1:jobs], recvResult)
            start <- start + jobs
        }
        checkForRemoteErrors(val)
    }
}

clusterApply <- function(cl, x, fun, ...) {
    argfun <- function(i) c(list(x[[i]]), list(...))
    staticClusterApply(cl, fun, length(x), argfun)
}

clusterEvalQ<-function(cl, expr)
    clusterCall(cl, eval, substitute(expr), env=.GlobalEnv)

clusterExport <- local({
    gets <- function(n, v) { assign(n, v, envir = .GlobalEnv); NULL }
    function(cl, list, envir = .GlobalEnv) {
        ## do this with only one clusterCall--loop on slaves?
        for (name in list) {
            clusterCall(cl, gets, name, get(name, envir = envir))
        }
    }
})

## A variant that does the exports one at at ime--this may be useful
## when large objects are being sent
# clusterExportSerial <- function(cl, list) {
#     gets <- function(n, v) { assign(n, v, envir = .GlobalEnv); NULL }
#     for (name in list) {
#         v <- get(name, envir = .GlobalEnv)
#         for (i in seq(along = cl)) {
#             sendCall(cl[[i]], gets, list(name, v))
#             recvResult(cl[[i]])
#         }
#     }
# }

recvOneResult <- function (cl) {
    if (.snowTimingData$running()) {
        start <- proc.time()[3]
        v <- recvOneData(cl)
        end <- proc.time()[3]
        .snowTimingData$enterRecv(v$node, start, end, v$value$time[3])
    }
    else v <- recvOneData(cl)
    list(value = v$value$value, node = v$node, tag = v$value$tag)
}

findRecvOneTag <- function(cl, anytag) {
    rtag <- NULL
    for (node in cl) {
        if (is.null(rtag))
            rtag <- node$RECVTAG
        else if (rtag != node$RECVTAG) {
            rtag <- anytag
            break;
        }
    }
    rtag
}

dynamicClusterApply <- function(cl, fun, n, argfun) {
    checkCluster(cl)
    p <- length(cl)
    if (n > 0 && p > 0) {
        submit <- function(node, job)
            sendCall(cl[[node]], fun, argfun(job), tag = job)
        for (i in 1 : min(n, p))
            submit(i, i)
        val <- vector("list", n)
        for (i in 1:n) {
            d <- recvOneResult(cl)
            j <- i + min(n, p)
            if (j <= n)
                submit(d$node, j)
            val[d$tag] <- list(d$value)
        }
        checkForRemoteErrors(val)
    }
}

clusterApplyLB <- function(cl, x, fun, ...) {
    ## **** this closure is sending all of x to all nodes
    argfun <- function(i) c(list(x[[i]]), list(...))
    dynamicClusterApply(cl, fun, length(x), argfun)
}

## **** should this allow load balancing?
## **** disallow recycling if one arg is length zero?
clusterMap <- function (cl, fun, ..., MoreArgs = NULL, RECYCLE = TRUE) {
    checkCluster(cl)
    args <- list(...)
    if (length(args) == 0)
        stop("need at least one argument")
    n <- sapply(args, length)
    if (RECYCLE) {
        vlen <- max(n)
        if (!all(n == vlen))
            for (i in 1:length(args)) args[[i]] <- rep(args[[i]],
                length = max(n))
    }
    else vlen = min(n)
    ## **** this closure is sending all of ... to all nodes
    argfun <- function(i) c(lapply(args, function(x) x[[i]]), MoreArgs)
    staticClusterApply(cl, fun, vlen, argfun)
}


#
# Cluster RNG Support
#

clusterSetupRNG <- function (cl, type="RNGstream", ...) {
    RNGnames <- c("RNGstream", "SPRNG")
    rng <- pmatch (type, RNGnames)
    if (is.na(rng))
        stop(paste("'", type,
                   "' is not a valid choice. Choose 'RNGstream' or 'SPRNG'.",
                   sep = ""))
    type <- RNGnames[rng]
    if (rng == 1)
        clusterSetupRNGstream(cl, ...)
    else clusterSetupSPRNG(cl, ...)
    type
}


#
# Cluster SPRNG Support
#
# adapted from rpvm (Li & Rossini)

clusterSetupSPRNG <- function (cl, seed = round(2^32 * runif(1)),
                            prngkind = "default", para = 0, ...)
{
    if (!is.character(prngkind) || length(prngkind) > 1)
        stop("'rngkind' must be a character string of length 1.")
    if (!is.na(pmatch(prngkind, "default")))
        prngkind <- "LFG"
    prngnames <- c("LFG", "LCG", "LCG64", "CMRG", "MLFG", "PMLCG")
    kind <- pmatch(prngkind, prngnames) - 1
    if (is.na(kind))
        stop(paste("'", prngkind, "' is not a valid choice", sep = ""))
    nc <- length(cl)
    invisible(clusterApply(cl, 0:(nc-1), initSprngNode, nc, seed, kind, para))
}

initSprngNode <- function (streamno, nstream, seed, kind, para)
{
    if (! require(rsprng))
        stop("the `rsprng' package is needed for SPRNG support.")
    .Call("r_init_sprng", as.integer(kind), as.integer(streamno),
        as.integer(nstream), as.integer(seed), as.integer(para),
        PACKAGE = "rsprng")
    RNGkind("user")
}


#
# rlecuyer support
#

clusterSetupRNGstream <- function (cl, seed=rep(12345,6), ...) {
    if (! require(rlecuyer))
        stop("the `rlecuyer' package is needed for RNGstream support.")
    .lec.init()
    .lec.SetPackageSeed(seed)
    nc <- length(cl)
    names <- as.character(1:nc)
    .lec.CreateStream(names)
    states <- lapply(names, .lec.GetStateList)
    invisible(clusterApply(cl, states, initRNGstreamNode))
}

initRNGstreamNode <- function (stream) {
    if (! require(rlecuyer))
        stop("the `rlecuyer' package is needed for RNGstream support.")

    if (length(.lec.Random.seed.table$name) > 0) {
	rm(".lec.Random.seed.table", envir=.GlobalEnv)
	assign(".lec.Random.seed.table", list(Cg=matrix(0,nrow=0,ncol=6),
                                              Bg=matrix(0,nrow=0,ncol=6),
                                              Ig=matrix(0,nrow=0,ncol=6),
                                              AIP=matrix(0,nrow=0,ncol=2),
                                              name=c()), envir=.GlobalEnv)
    }
    .lec.Random.seed.table$Cg <<- rbind(.lec.Random.seed.table$Cg,
                                        stream$Cg[1:6])
    .lec.Random.seed.table$Bg <<- rbind(.lec.Random.seed.table$Bg,stream$Bg)
    .lec.Random.seed.table$Ig <<- rbind(.lec.Random.seed.table$Ig,stream$Ig)
    .lec.Random.seed.table$AIP <<- rbind(.lec.Random.seed.table$AIP,
                                         c(stream$Anti, stream$IncPrec))
    .lec.Random.seed.table$name <<- c(.lec.Random.seed.table$name, stream$name)

    old.kind<-.lec.CurrentStream(stream$name)
    old.kind
}


#
# Parallel Functions
#

splitIndices <- function(nx, ncl) {
    batchsize <- if (nx %% ncl == 0) nx %/% ncl else 1 + nx %/% ncl
    batches <- (nx + batchsize - 1) %/% batchsize
    split(1:nx, rep(1:batches, each = batchsize)[1:nx])
}

splitIndices <- function(nx, ncl) {
    i <- 1:nx;
    if (ncl == 1) i
    else structure(split(i, cut(i, ncl)), names=NULL)
}

# The fuzz used by cut() is too small when nx and ncl are both large
# and causes some groups to be empty. The definition below avoids that
# while minimizing changes from the results produced by the definition
# above.
splitIndices <- function(nx, ncl) {
    i <- 1:nx;
    if (ncl == 1) i
    else {
        fuzz <- min((nx - 1) / 1000, 0.4 * nx / ncl)
        breaks <- seq(1 - fuzz, nx + fuzz, length = ncl + 1)
        structure(split(i, cut(i, breaks)), names = NULL)
    }
}

clusterSplit <- function(cl, seq)
    lapply(splitIndices(length(seq), length(cl)), function(i) seq[i])

splitList <- function(x, ncl)
    lapply(splitIndices(length(x), ncl), function(i) x[i])

splitRows <- function(x, ncl)
    lapply(splitIndices(nrow(x), ncl), function(i) x[i,, drop=FALSE])

splitCols <- function(x, ncl)
    lapply(splitIndices(ncol(x), ncl), function(i) x[,i, drop=FALSE])

parLapply <- function(cl, x, fun, ...)
    docall(c, clusterApply(cl, splitList(x, length(cl)), lapply, fun, ...))

parRapply <- function(cl, x, fun, ...)
    docall(c, clusterApply(cl, splitRows(x,length(cl)), apply, 1, fun, ...))

parCapply <- function(cl, x, fun, ...)
    docall(c, clusterApply(cl, splitCols(x,length(cl)), apply, 2, fun, ...))

parMM <- function(cl, A, B)
    docall(rbind,clusterApply(cl, splitRows(A, length(cl)), get("%*%"), B))

# adapted from sapply in the R sources
parSapply <- function (cl, X, FUN, ..., simplify = TRUE, USE.NAMES = TRUE)
{
    FUN <- match.fun(FUN) # should this be done on slave?
    answer <- parLapply(cl,as.list(X), FUN, ...)
    if (USE.NAMES && is.character(X) && is.null(names(answer)))
        names(answer) <- X
    if (simplify && length(answer) != 0) {
        common.len <- unique(unlist(lapply(answer, length)))
        if (common.len == 1)
            unlist(answer, recursive = FALSE)
        else if (common.len > 1)
            array(unlist(answer, recursive = FALSE),
                  dim = c(common.len, length(X)),
                  dimnames = list(names(answer[[1]]), names(answer)))
        else answer
    }
    else answer
}

# adapted from apply in the R sources
parApply <- function(cl, X, MARGIN, FUN, ...)
{
    FUN <- match.fun(FUN) # should this be done on slave?

    ## Ensure that X is an array object
    d <- dim(X)
    dl <- length(d)
    if(dl == 0)
	stop("dim(X) must have a positive length")
    ds <- 1:dl

    # for compatibility with R versions prior to 1.7.0
    if (! exists("oldClass"))
	oldClass <- class
    if(length(oldClass(X)) > 0)
	X <- if(dl == 2) as.matrix(X) else as.array(X)
    dn <- dimnames(X)

    ## Extract the margins and associated dimnames

    s.call <- ds[-MARGIN]
    s.ans  <- ds[MARGIN]
    d.call <- d[-MARGIN]
    d.ans  <- d[MARGIN]
    dn.call<- dn[-MARGIN]
    dn.ans <- dn[MARGIN]
    ## dimnames(X) <- NULL

    ## do the calls

    d2 <- prod(d.ans)
    if(d2 == 0) {
        ## arrays with some 0 extents: return ``empty result'' trying
        ## to use proper mode and dimension:
        ## The following is still a bit `hackish': use non-empty X
        newX <- array(vector(typeof(X), 1), dim = c(prod(d.call), 1))
        ans <- FUN(if(length(d.call) < 2) newX[,1] else
                   array(newX[,1], d.call, dn.call), ...)
        return(if(is.null(ans)) ans else if(length(d.call) < 2) ans[1][-1]
               else array(ans, d.ans, dn.ans))
    }
    ## else
    newX <- aperm(X, c(s.call, s.ans))
    dim(newX) <- c(prod(d.call), d2)
    if(length(d.call) < 2) {# vector
        if (length(dn.call)) dimnames(newX) <- c(dn.call, list(NULL))
        arglist <- lapply(1:d2, function(i) newX[,i])
    } else
        arglist <- lapply(1:d2, function(i) array(newX[,i], d.call, dn.call))
    ans <- parLapply(cl, arglist, FUN, ...)

    ## answer dims and dimnames

    ans.list <- is.recursive(ans[[1]])
    l.ans <- length(ans[[1]])

    ans.names <- names(ans[[1]])
    if(!ans.list)
	ans.list <- any(unlist(lapply(ans, length)) != l.ans)
    if(!ans.list && length(ans.names)) {
        all.same <- sapply(ans, function(x) identical(names(x), ans.names))
        if (!all(all.same)) ans.names <- NULL
    }
    len.a <- if(ans.list) d2 else length(ans <- unlist(ans, recursive = FALSE))
    if(length(MARGIN) == 1 && len.a == d2) {
	names(ans) <- if(length(dn.ans[[1]])) dn.ans[[1]] # else NULL
	return(ans)
    }
    if(len.a == d2)
	return(array(ans, d.ans, dn.ans))
    if(len.a > 0 && len.a %% d2 == 0)
	return(array(ans, c(len.a %/% d2, d.ans),
                     if(is.null(dn.ans)) {
                         if(!is.null(ans.names)) list(ans.names,NULL)
                     } else c(list(ans.names), dn.ans)))
    return(ans)
}


#
#  Library Initialization
#

.onLoad <- function(libname, pkgname) {
    initDefaultClusterOptions(libname)
    if (exists("mpi.comm.size"))
        type <- "MPI"
    else if (length(find.package("rpvm", quiet = TRUE)) != 0)
        type <- "PVM"
    else if (length(find.package("Rmpi", quiet = TRUE)) != 0)
        type <- "MPI"
    else if (length(find.package("nws", quiet = TRUE)) != 0)
        type <- "NWS"
    else type <- "SOCK"
    setDefaultClusterOptions(type = type)
}
