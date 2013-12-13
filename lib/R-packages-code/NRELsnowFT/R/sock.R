#
# Socket Implementation
#

makeSOCKclusterFT <- function(spec, names=NULL, ..., options = defaultClusterOptions) {
    all.names <- names
    names <- if (is.null(names)) spec else names[1:spec]
    cl <- makeSOCKcluster(names, ..., options=options)
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

addtoCluster.SOCKcluster <- function(cl, spec, ...,
                                    options = defaultClusterOptions) {
    names <- attr(cl, 'all.hosts')
    options <- addClusterOptions(options, list(...))
  n <- length(cl)
  newcl <- vector("list",n+spec)
  if (!is.null(names)) {
  	if (length(names) < n+spec) names <- rep(names,n+spec)
  } else {
        names <- rep('localhost', n+spec)
    }
    names <- names[1:(n+spec)]
  for (i in seq(along=cl)) {
    newcl[[i]] <- cl[[i]]
    # remove hosts from the list that are already in the cluster
    which.idx <- which.max(cl[[i]]$host == names)
    names <- names[-which.idx]
  }
  j <- 1
  for (i in (n+1):(n+spec)) {
    newcl[[i]] <- newSOCKnode(names[[j]], options = options)
    newcl[[i]]$replic <- 0
    j <- j+1
  }
  class(newcl) <- class(cl)
    attr(newcl, 'all.hosts') <- attr(cl, 'all.hosts')
  newcl
}

processStatus.SOCKnode <- function(node) {
  stop("Function processStatus is not implemented for Socket")
}

getNodeID.SOCKnode <- function(node) {
  return(node$con)
}

do.administration.SOCKcluster <- function(cl, clall, d, p, it, n, manage, mngtfiles, 
									x, frep, freenodes, initfun, 
									gentype, seed, ft_verbose, ...) {
	free.nodes <- FALSE
        if (length(d) <= 0) { # no results arrived yet
            while (TRUE) {
                # do the administration in the waiting time
                # ***************************************
	        updated.values <- manage.replications.and.cluster.size(cl, clall, p, n, manage, mngtfiles, 
									freenodes, initfun, gentype, seed, ft_verbose=ft_verbose)
                newp <- updated.values$newp
                if (updated.values$cluster.increased) {
                    p <- updated.values$p
                    cl <- updated.values$cl
                    clall <- updated.values$clall
                    freenodes <- updated.values$freenodes
                    break
                }
                p <- newp              
                d <- recvOneResultFT(clall,'t',time=5) # wait for a result for
                                                       # 5 sec
                if (length(d) > 0) break # some results arrived, if not
                                         # do administration again
            }  # end of while loop ****************************
            if ((length(freenodes) > 0) && (it <= n)) free.nodes <- TRUE
        }
        return(list(cl=cl, clall=clall, frep=frep, freenodes=freenodes, p=p, d=d, is.free.node=free.nodes))
}


