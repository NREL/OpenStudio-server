#
# Socket Implementation
#

makeSOCKclusterFT <- function(ipList=NULL, ..., options = defaultClusterOptions) {
    all.names <- ipList
    names <- if (is.null(ipList)) stop('names is size null')
    cl <- makeSOCKcluster(ipList, ..., options=options)
    attr(cl, 'all.hosts') <- all.names
    cl
}

recvOneDataFT.SOCKcluster <- function(cl,type='b',time=0) {
    socklist <- lapply(cl, function(x) x$con)
    timeout <- switch(type,
                n = 0, #non-blocking receive
                b = NULL, # blocking
                t = time, # timeout
                stop('unknown receive type'))

    ready <- socketSelect(socklist, timeout=timeout)
    if(sum(ready) == 0) return (NULL)
    ready.nodes <- which(ready)
    # choose node with the smallest value of 'replic'
    replic <- sapply(cl[ready.nodes], function(x) x$replic)
    n <- ready.nodes[which.min(replic)]
    list(node = n, value = unserialize(socklist[[n]]))
}


is.manageable.SOCKcluster <- function(cl) {
	return (c(cluster.size=TRUE, monitor.procs=TRUE, repair=FALSE))
}

addtoCluster.SOCKcluster <- function(cl, spec, newIPs, ...,options = defaultClusterOptions) {
  names <- attr(cl, 'all.hosts')
  options <- addClusterOptions(options,list())
  n <- length(cl)
  newcl <- vector("list",n+spec)

  names[(n+1):(n+spec)] <- newIPs[1:(spec)]

  for (i in seq(along=cl)) {
    newcl[[i]] <- cl[[i]]
    # remove hosts from the list that are already in the cluster
    #which.idx <- which.max(cl[[i]]$host == names)
    #names <- names[-which.idx]
  }
  j <- (n+1)
  for (i in (n+1):(n+spec)) {
    if (!is.null(names[[i]])){
      newcl[[j]] <- newSOCKnode(names[[j]], ...,options = options, rank=j)
      newcl[[j]]$replic <- 0
      j <- j+1
    }
  }
  class(newcl) <- class(cl)
  attr(newcl, 'all.hosts') <- names
  newcl
}

processStatus.SOCKnode <- function(node) {
  stop("Function processStatus is not implemented for Socket")
}

getNodeID.SOCKnode <- function(node) {
  return(node$con)
}

doAdministration.SOCKcluster <- function(cl, clall, d, p, it, n, manage, mngtfiles, ipFile, resizeFile, x, frep, freenodes, initfun, initlibrary, ft_verbose, removeIPs=removeIPs,...) {
	free.nodes <- FALSE
	newp <- NULL
        if (length(d) <= 0) { # no results arrived yet
            while (TRUE) {
                # do the administration in the waiting time
                # ***************************************
	        updated.values <- manage.replications.and.cluster.size(cl, clall, p, n, manage, mngtfiles, ipFile, resizeFile, freenodes, initfun, initlibrary, ft_verbose=ft_verbose, removeIPs=removeIPs,...)
                newp <- updated.values$newp
                removeIPs <- updated.values$removeIPs
                if (updated.values$cluster.increased) {
                    p <- updated.values$p
                    cl <- updated.values$cl
                    clall <- updated.values$clall
                    freenodes <- updated.values$freenodes
                    break
                }
                p <- newp              
                d <- recvOneResultFT(clall,'t',time=0) # wait for a result for
                                                       # 1 sec
                if (length(d) > 0) break # some results arrived, if not
                                         # do administration again
            }  # end of while loop ****************************
            if ((length(freenodes) > 0) && (it <= n)) free.nodes <- TRUE
        }
        return(list(cl=cl, clall=clall, frep=frep, freenodes=freenodes, p=p, newp=newp, d=d, is.free.node=free.nodes, removeIPs=removeIPs))
}


