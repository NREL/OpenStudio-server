#
# Process control
#

processStatus <- function(node) UseMethod("processStatus")

# Administration
doAdministration <- function(cl, clall, d, p, it, n, manage, mngtfiles, ipfile, x, frep, freenodes, initfun,ft_verbose) UseMethod("doAdministration")
is.manageable <- function(cl) UseMethod("is.manageable")

#
# Higher-Level Node Functions
#

recvOneDataFT <- function(cl,type,time) UseMethod("recvOneDataFT")
    

#
#  Cluster Modification
#

addtoCluster <- function(cl, spec, ipfile, options = defaultClusterOptions)
  UseMethod("addtoCluster") 

#repairCluster <- function(cl, nodes, options = defaultClusterOptions)
#  UseMethod("repairCluster")

removefromCluster  <- function(cl, nodes, ft_verbose=FALSE) {
  newcl <- vector("list",length(cl)-length(nodes))
  j<-0
  for (i in seq(along=cl)) {
    if (length(nodes[nodes == i])>0) 
      stopNode(cl[[i]])
    else {
      j<-j+1
      newcl[[j]] <- cl[[i]]
    }
  }
    for(clattr in names(attributes(cl))){
        attr(newcl, clattr) <- attr(cl, clattr)
    }
    if(ft_verbose) printClusterInfo(newcl)
  newcl
}

printClusterInfo <- function(cl) {
    cat('\nCluster size:', length(cl))
    cat('\nCluster type:', class(cl))
        if (length(cl) > 0 && is.element('host', names(cl[[1]]))) {
            cat('\nHosts: ')
            for(node in cl) cat(node$host, ', ')
      	}
    cat('\n')
}

#
# Cluster Functions
#

makeClusterFT <- function(type = getClusterOption("type"), ipList=NULL, 
				ft_verbose=FALSE) {
    if (is.null(type))
        stop("need to specify a cluster type")
    cat('ipList:',ipList,'\n')    
    cl <- switch(type,
        SOCK = makeSOCKclusterFT(ipList),
        #PVM = makePVMcluster(spec, ...),
        #MPI = makeMPIcluster(spec, ...),
        stop("unknown cluster type"))
    clusterEvalQ(cl, require(NRELsnowFT))
    if(ft_verbose) {
        cat('\nCluster successfully created.')
        printClusterInfo(cl)
    } 
    return(cl)
}

clusterCallpart  <- function(cl, nodes, fun, ...) {
    for (i in seq(along = nodes))
        sendCall(cl[[nodes[i]]], fun, list(...))
    lapply(cl[nodes], recvResult)
}

clusterEvalQpart <- function(cl, nodes, expr)
    clusterCallpart(cl, nodes, eval, substitute(expr), env=.GlobalEnv)


recvOneResultFT <- function(cl,type='b',time=0) {
    v <- recvOneDataFT(cl,type,time)
    if (length(v) <= 0) return (NULL)
    return(list(value = v$value$value, node=v$node))
}

clusterApplyFT <- function(cl, x, fun, initfun = NULL, exitfun=NULL,
                             printfun=NULL, printargs=NULL,
                             printrepl=max(length(x)/10,1),
                             mngtfiles=c(".clustersize",".proc",".proc_fail"), ipfile=".newips",
                             ft_verbose=FALSE) {

# This function is a combination of clusterApplyLB and FPSS
# (Framework for parallel statistical simulations), written by
# Hana Sevcikova.
# Features:
#  - fault tolerance - checks for failed nodes, in case of failure the
#                      cluster is repaired and the particular replication
#                      restarted.
#  - reproducible results - each replication is assigned to one
#                           particular RNG stream. Thus, proceeding
#                           in any order will give the same results.
#  - dynamic adaptation of degree of parallelism - the function reads the
#                 desired number of nodes from a file (that can be changed
#                 any time) and increases or decreases the number of nodes.
#  - keeping track about the computat`ion status - the replication numbers
#                 that are currently processed and that failed are
#                 written into files.
#  - efficient administration - all the management work is done only
#                 when there is no message arrived and thus nothing
#                 else to do.

	if (all(is.na(pmatch(attr(cl,"class"), c("SOCKcluster"))))) {
    	cat("\nInvalid communication layer.\n")
		return(list(NULL,cl))
  	}

	if (length(cl)<=0) 
    	stop("No cluster created!")

  	lmng <- length(mngtfiles)
  	if (lmng < 3)
    	mngtfiles <- c(mngtfiles, rep('', 3-lmng))
  	manage <- is.manageable(cl) & (nchar(mngtfiles) > 0)
  	if (ft_verbose) {
    	cat("\nFunction clusterApplyFT:\n")
     	if(sum(manage) > 0)
     		cat("   Management files:\n")
     	if(manage['cluster.size'])
			cat("     cluster size:", mngtfiles[1],"\n")
     	if(manage['monitor.procs'])
			cat("     running processes:", mngtfiles[2],"\n")
     	if(manage['repair'])
			cat("     failed nodes:", mngtfiles[3],"\n")
  	}
  	n <- length(x)
  	p <- length(cl)
  	fun <- fun # need to force the argument
  	printfun <- printfun
  	val <- NULL

  	if (n > 0 && p > 0) {
    	wrap <- function(x, i, n){
      		value <- try(fun(x))
      		return(list(value = value, index = i))
    	}
    	submit <- function(node, job, n) {
      		args <- c(list(x[[job]]), list(job), list(n))
      		sendCall(cl[[node]], wrap, args)
    	}

    	val <- vector("list", n)
    	if (manage['cluster.size'])
      		write(p, file=mngtfiles[1])
    	replvec <- 1:n
    	maxit <- if(manage['repair']) 3 else 1 # second and third run is for restarting failed
            	           					# replications
    	for (run in 1:maxit) { 
      		if (run > 1) {
				if (ft_verbose) 
					cat(run,"th run for replications:",frep,"\n")
        		replvec <- frep
        		n<-length(replvec)
      		}
      		for (i in 1 : min(n, p)) {         
        		repl <- replvec[i]
        		submit(i, repl,n)
        		cl[[i]]$replic <- repl
      		}
      		clall<-cl
      		fin <- 0
      		frep <- c() # list of replications of failed nodes
      		if (manage['repair'])
        		write(frep,mngtfiles[3])
      		startit<-min(n, p)
      		freenodes<-c()
      		it<-startit
      		while(fin < (n-length(frep))) {
        		it <- it+1
        		if (it <= n) 
          			repl<-replvec[it]
        		while ((length(freenodes) <= 0) ||
               			((it > n) && fin < (n-length(frep)))) { # all nodes busy
                                        # or wait for remaining results
          			d <- recvOneResultFT(clall,'n') # look if there is any result
          			admin <- doAdministration(cl, clall, d, p, it, n, manage, mngtfiles, ipfile, x, frep, freenodes, initfun,ft_verbose)
					cl <- admin$cl
					clall <- admin$clall
					d <- admin$d
					frep <- admin$frep
					freenodes <- admin$freenodes
					p <- admin$p
					if (admin$is.free.node) break
					if (!is.list(d$value))
						stop(paste('Error in received results:\n', paste(d, collapse='\n')))
					val[d$value$index] <- list(d$value$value)
          			node <- GetNodefromReplic(cl,d$value$index)
          			if (node > 0) {
            			if (length(cl) > p) { # decrease the degree of parallelism
            					if (ft_verbose) 
									cat('\nDecreasing cluster size from', length(cl), 'to', p)
              				if (!is.null(exitfun))
                					clusterCallpart(cl,node,exitfun)
              				clall<-removecl(clall,c(cl[[node]]$replic))
              				cl <- removefromCluster(cl,node, ft_verbose=ft_verbose)
            			} else {
              				freenodes <- c(freenodes,node)
              				cl[[node]]$replic<-0
            			}
          			} else { # result from a failed node
            			frep <- frep[-which(frep == d$value$index)]
            			clall <- removecl(clall,c(d$value$index))
          			}
          			fin <- fin + 1
          			if (!is.null(printfun) & ((fin %% printrepl) == 0))
            			try(printfun(val,fin,printargs))
        		}
        		if (it <= n) {
          			submit(freenodes[1], repl, n)
          			cl[[freenodes[1]]]$replic <- repl
          			clall <- updatecl(clall,cl[[freenodes[1]]])
          			freenodes <- freenodes[-1]
        		}
      		}
      		if (length(frep) <= 0) break # everything went well, no need to go
                                        # to the next run
    	}
    	if (length(frep) > 0)
      		cat("\nWarning: Some replications failed!\n") # even in the third run
  	}
  	return(list(val,cl))
}

performParallel <- function(x, fun, initfun = NULL, exitfun =NULL,
                            printfun=NULL,printargs=NULL,
                            printrepl=max(length(x)/10,1),
                            cltype = getClusterOption("type"),
                            cluster.args=NULL, ipList=NULL, 
			    mngtfiles=c(".clustersize",".proc",".proc_fail"), ipfile=".newips",
                            ft_verbose=FALSE) {


  if (ft_verbose) {
     cat("\nFunction performParallel:\n")
     cat("   creating cluster ...\n")
  }
  if(cltype!="SOCK") {
  	warning('Cluster type is currently unavailable. Using SOCK layer.')
  	cltype <- 'SOCK'
  }
  cat('ipList:',ipList,'\n')
  cl <- do.call('makeClusterFT', c(list(cltype, ipList=ipList, ft_verbose=ft_verbose),cluster.args))

  if (!is.null(initfun)) {
    if (ft_verbose) 
	cat("   calling initfun ...\n")
    clusterCall(cl, initfun)
  }

  if (ft_verbose) 
     cat("   calling clusterApplyFT ...\n")
 
  res <- clusterApplyFT (cl, x, fun, initfun=initfun, exitfun=exitfun,
                           printfun=printfun, printargs=printargs,
                           printrepl=printrepl, mngtfiles=mngtfiles, 
			   ft_verbose=ft_verbose)

  if (ft_verbose) 
     cat("   clusterApplyFT finished.\n")
  val<-res[[1]]
  cl <- res[[2]]
  if (!is.null(exitfun)) {
     if (ft_verbose) 
	cat("   calling exitfun ...\n")
     clusterCall(cl, exitfun)
  }
  stopCluster(cl)
  if (ft_verbose) 
     cat("   cluster stopped.\n")
  return(checkForRemoteErrors(val))
}


getNodeID <- function (node) UseMethod("getNodeID")

findFailedNodes <- function (cl) {
  failed <- matrix(0,nrow=0,ncol=3)
  for (i in seq(along=cl)) {
    if (!processStatus(cl[[i]]))
      failed<-rbind(failed,c(i,cl[[i]]$replic,getNodeID(cl[[i]])))
  }
  return(failed)
}

combinecl <- function(oldcl, add) {
  attr<- attr(oldcl,"class")
  n <- length(oldcl)
  count <- length(add)
  if (count <= 0 ) return (oldcl)
  cl <- vector("list",n+count)
  for (i in seq(along=oldcl))
    cl[[i]] <- oldcl[[i]]
  j<-0
  for (i in (n+1):(n+count)){
    j<-j+1
    cl[[i]] <- add[[j]]
  }
  class(cl) <- c(attr)
  cl
}

removecl <- function(oldcl, reps) {
  attr<- attr(oldcl,"class")
  n <- length(oldcl)
  count<-length(reps)
  cl <- vector("list",n-count)
  j<-0
  for (i in seq(along=oldcl)) {
    if (length(reps[reps == oldcl[[i]]$replic]) <= 0) {
	j <- j+1 
    	cl[[j]] <- oldcl[[i]]
	}
}
  class(cl) <- c(attr)
  cl
}

updatecl <- function(cl, compcl) {
  for (i in seq(along=cl)) {
    if (getNodeID(cl[[i]]) == getNodeID(compcl)) {
      cl[[i]]$replic<-compcl$replic
      break
    }
  }
  cl
}

GetNodefromReplic <- function(cl,replic) {
  for (i in seq(along=cl))
    if (cl[[i]]$replic == replic) return(i)
  return(0)
}

writetomngtfile <- function(cl, file) {
  n <- length(cl)
  repl<-rep(0,n)
  for (i in seq(along=cl))
    repl[i]<-cl[[i]]$replic
  write(repl,file)
}

manage.replications.and.cluster.size <- function(cl, clall, p, n, manage, mngtfiles, ipfile, freenodes, initfun, ft_verbose=FALSE) {
	if (manage['cluster.size']){ 
          scanresize <- try(scan(file=mngtfiles[1],what=integer(),nlines=1, quiet=TRUE))
          if (!inherits(scanresize,'try-error')){
            newp <- scanresize
          } else {
            newp <- p
          }
        } else {
          newp <- p
        }
	if (manage['monitor.procs'])
  	   # write the currently processed replications into a file 
           writetomngtfile(cl,mngtfiles[2])
        cluster.increased <- FALSE
        if (newp > p) { # increase the degree of parallelism
           cat('resizing cluster\n')
           cl<-addtoCluster(cl, newp-p, ipfile=ipfile)
           clusterEvalQpart(cl,(p+1):newp,require(NRELsnowFT))
           if(ft_verbose)
             printClusterInfo(cl)
           if (!is.null(initfun))
             clusterCallpart(cl,(p+1):newp,initfun)
           clall<-combinecl(clall,cl[(p+1):newp])
           freenodes<-c(freenodes,(p+1):newp)
           p <- newp
           cluster.increased <- TRUE
	}
	return(list(cluster.increased=cluster.increased, cl=cl, clall=clall, freenodes=freenodes, p=p, newp=newp))
}

#
#  Library Initialization
#

#.First.lib <- function(libname, pkgname) {
#	   require(snow)
#}
