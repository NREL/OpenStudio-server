#
# Process control
#

processStatus <- function(node) UseMethod("processStatus")

# Administration
doAdministration <- function(cl, clall, d, p, it, n, manage, mngtfiles, ipFile, resizeFile, x, frep, freenodes, initfun, initlibrary, ft_verbose,removeIPs,...) UseMethod("doAdministration")
is.manageable <- function(cl) UseMethod("is.manageable")

#
# Higher-Level Node Functions
#

recvOneDataFT <- function(cl,type,time) UseMethod("recvOneDataFT")

#stopCluster
stopClusterFT <- function(cl) {
    for (n in cl) {
      if (isOpen(n$con))
        stopNode(n)
    }
}    

#
#  Cluster Modification
#

addtoCluster <- function(cl, spec, newIPs, ...,options = defaultClusterOptions)
  UseMethod("addtoCluster") 

#repairCluster <- function(cl, nodes, options = defaultClusterOptions)
#  UseMethod("repairCluster")

removefromCluster  <- function(cl, nodes, ft_verbose=FALSE) {
  newcl <- vector("list",length(cl)-length(nodes))
  hostNames <- attr(cl, 'all.hosts')
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
    cat('hostNames before:',hostNames,'\n')
    hostNames <- hostNames[-nodes]
    cat('hostNames after:',hostNames,'\n')
    attr(newcl, 'all.hosts') <- hostNames
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
				ft_verbose=FALSE, ...) {
    if (is.null(type))
        stop("need to specify a cluster type")
    cat('ipList:',ipList,'\n')    
    cl <- switch(type,
        SOCK = makeSOCKclusterFT(ipList, ...),
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
    
clusterExportpart <- local({
    gets <- function(n, v) { assign(n, v, envir = .GlobalEnv); NULL }
    function(cl, nodes, list, envir = .GlobalEnv) {
        ## do this with only one clusterCall--loop on slaves?
        for (name in list) {
            clusterCallpart(cl, nodes, gets, name, get(name, envir = envir))
        }
    }
})


recvOneResultFT <- function(cl,type='b',time=0) {
    v <- recvOneDataFT(cl,type,time)
    if (length(v) <= 0) return (NULL)
    return(list(value = v$value$value, node=v$node))
}

clusterApplyFT <- function(cl, x, fun, initfun = NULL, exitfun=NULL, initlibrary=NULL,
                             printfun=NULL, printargs=NULL,
                             printrepl=max(length(x)/10,1),
                             mngtfiles=c(".clustersize",".proc",".proc_fail"), ipFile=".newips", resizeFile=".resizeFile",
                             ft_verbose=FALSE,...) {

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
      	# check to see if the resizeFile exists and remove it.	
      	if (file.exists(resizeFile))
      		file.remove(resizeFile)
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
   		removeIPs <- c()
      		it<-startit
      		while(fin < (n-length(frep))) {
        		it <- it+1
        		if (it <= n) 
          		  repl<-replvec[it]
        		while ((length(freenodes) <= 0) || ((it > n) && fin < (n-length(frep)))) { # all nodes busy or wait for remaining results
          			d <- recvOneResultFT(clall,'n') # look if there is any result
          			admin <- doAdministration(cl, clall, d, p, it, n, manage, mngtfiles, ipFile, resizeFile, x, frep, freenodes, initfun, initlibrary, ft_verbose, removeIPs=removeIPs, ...)
          			removeIPs <- admin$removeIPs
				cl <- admin$cl
				clall <- admin$clall
				d <- admin$d
				frep <- admin$frep
				freenodes <- admin$freenodes
				p <- admin$p
				newp <- admin$newp
				if (admin$is.free.node) break
				if (!is.list(d$value))
				  stop(paste('Error in received results:\n', paste(d, collapse='\n')))
				val[d$value$index] <- list(d$value$value)
          			node <- GetNodefromReplic(cl,d$value$index)
          			if (node > 0) {
          			  #start reduce cluster
          			  if (cl[[node]]$host %in% removeIPs) {
          			    if (length(cl)-length(node) > 0) {
          			      cat('removing',cl[[node]]$host,' from ', removeIPs,'\n')
          			      which.idx <- which.max(removeIPs == cl[[node]]$host)
                                      removeIPs <- removeIPs[-which.idx]
            			      if (ft_verbose) 
				        cat('\nRemove cluster node', cl[[node]]$host, '\n')
              			      if (!is.null(exitfun))
                		        clusterCallpart(cl,node,exitfun)
              			      clall<-removecl(clall,c(cl[[node]]$replic))
              			      cl <- removefromCluster(cl,node, ft_verbose=ft_verbose)
              			      p <- length(cl)
              			    } else {
              			      cat('NOT reducing cluster size, size must remain positive\n')
              			      freenodes <- c(freenodes,node)
              			      cl[[node]]$replic<-0
              			    }#end reduce cluster
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

performParallel <- function(x, fun, initfun = NULL, exitfun =NULL, initlibrary=NULL,
                            printfun=NULL,printargs=NULL,
                            printrepl=max(length(x)/10,1),
                            cltype = getClusterOption("type"),
                            cluster.args=NULL, ipList=NULL, 
			    mngtfiles=c(".clustersize",".proc",".proc_fail"), ipFile=".newips", resizeFile=".resizeFile",
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

  if (!is.null(initlibrary)) {
    if (ft_verbose) 
	cat("   calling initlibrary ...\n")
    clusterCall(cl, initlibrary)
  }

  if (!is.null(initfun)) {
    if (ft_verbose) 
	cat("   calling initfun ...\n")
    clusterCall(cl, initfun)
  }

  if (ft_verbose) 
     cat("   calling clusterApplyFT ...\n")
 
  res <- clusterApplyFT (cl, x, fun, initfun=initfun, exitfun=exitfun, initlibrary=initlibrary,
                           printfun=printfun, printargs=printargs,
                           printrepl=printrepl, mngtfiles=mngtfiles, ipFile=ipFile, resizeFile=resizeFile,
			   ft_verbose=ft_verbose,cluster.args=cluster.args)

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

manage.replications.and.cluster.size <- function(cl, clall, p, n, manage, mngtfiles, ipFile, resizeFile, freenodes, initfun, initlibrary, ft_verbose=FALSE, removeIPs=removeIPs, ...) {
        addIPs <- NULL
        newp <- NULL
	if (manage['cluster.size']){ 
	  if(file.exists(resizeFile)){
	    tempIPs <- try(scan(file=ipFile, what=character(), quiet=TRUE))
	    if (!inherits(tempIPs,'try-error')){
	      newIPs <- tempIPs
	      currentIPs <- attr(cl, 'all.hosts')
	      cat('currentIPs:',currentIPs,'\n')
	      #find add and remove nodes
              addIPs <- newIPs[!newIPs%in%currentIPs]
              cat('addIPs:',addIPs,'\n')
              removeIPs <- append(removeIPs,currentIPs[!currentIPs%in%newIPs])
              cat('removeIPs:',removeIPs,'\n')
              deleteFile <- try(file.remove(resizeFile))
              if (inherits(deleteFile,'try-error'))
                cat('could not delete resizeFile',resizeFile,'\n')
              newp <- p + length(addIPs)  
	    } else { #fail to read ipFile
	      newIPs <- NULL
	      newp <- p
            }
	  } else { #no resizeFile
	    newp <- p
	  }
        } else { #no manage['cluster.size']
          newp <- p
        }
        
	if (manage['monitor.procs'])
  	   writetomngtfile(cl,mngtfiles[2]) # write the currently processed replications into a file 
  	   
        cluster.increased <- FALSE
        if (length(addIPs) > 0) { # increase the degree of parallelism
           cat('\n resizing cluster \n')
           cat('\n current cluster \n')
           if(ft_verbose) printClusterInfo(cl)
           cl<-addtoCluster(cl, length(addIPs), newIPs=addIPs, ...)
           cat('\n after addtoCluster \n')
           if(ft_verbose) printClusterInfo(cl)
           clusterEvalQpart(cl,(p+1):(p+length(addIPs)),require(NRELsnowFT))
           if(ft_verbose)
             printClusterInfo(cl)
           #if (!is.null(initlibrary)) { 
           #  cat('initlibrary: ',initlibrary,'\n')
           #  clusterEvalQpart(cl,(p+1):(p+length(addIPs)),as.expression(initlibrary))
           #  #clusterExportpart(cl,(p+1):(p+length(addIPs)),initlibrary)
           #  cl
           #}
           if (!is.null(initfun))
             clusterExportpart(cl,(p+1):(p+length(addIPs)),initfun)
           clall<-combinecl(clall,cl[(p+1):(p+length(addIPs))])
           freenodes<-c(freenodes,(p+1):(p+length(addIPs)))
           p <- p + length(addIPs)
           cluster.increased <- TRUE
	}
	return(list(cluster.increased=cluster.increased, cl=cl, clall=clall, freenodes=freenodes, p=p, newp=newp, removeIPs=removeIPs))
}

#
#  Library Initialization
#

#.First.lib <- function(libname, pkgname) {
#	   require(snow)
#}
