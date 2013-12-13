library(snowFT)

run.rnorm.sock <- function() {
	cat('\nRunning rnorm test with SOCK ...\n')
	nprocs <- 500
	nrns <- 1000
	st <- system.time(res <- performParallel(5, rep(nrns, nprocs), fun=rnorm, cltype='SOCK', ft_verbose=TRUE))
	print(st)
	stopifnot(length(res) == nprocs)
	stopifnot(length(res[[1]]) == nrns)
	stopifnot(length(res[[98]]) == nrns)
	cat('\n OK.\n')
}

run.rnorm.seq <- function() {
	cat('\nRunning rnorm test sequentially ...\n')
	st <- system.time(res <- performParallel(0, rep(1000, 500), fun=rnorm))
	print(st)
	stopifnot(length(res) == 500)
	stopifnot(length(res[[1]]) == 1000)
	stopifnot(length(res[[321]]) == 1000)
	cat('\n OK.\n')
}

run.rnorm.sock.cluster.args <- function(nprocs=50, nrns=1000) {
	cat('\nRunning rnorm test with SOCK and cluster options ...\n')
	fun <- function(i) {
            Sys.sleep(5)
	    return(rnorm(i))
	}
        st <- system.time(res <- performParallel(5, rep(nrns, nprocs), fun=fun, cltype='SOCK', 
				cluster.args=list(names=paste('fal', 11:16, sep='')),
				ft_verbose=TRUE))
        print(st)
        stopifnot(length(res) == nprocs)
        stopifnot(length(res[[1]]) == nrns)
}

run.rnorm.pvm <- function(nprocs=50, nrns=1000) {
        cat('\nRunning rnorm test with PVM ...\n')
        fun <- function(i) {
            Sys.sleep(5)
            return(rnorm(i))
        }
        st <- system.time(res <- performParallel(5, rep(nrns, nprocs), fun=fun, cltype='PVM',
                                ft_verbose=TRUE))
        print(st)
      	stopifnot(length(res) == nprocs)
      	stopifnot(length(res[[1]]) == nrns)
}

run.rnorm.mpi <- function(nprocs=50, nrns=1000) {
        cat('\nRunning rnorm test with MPI ...\n')
        fun <- function(i) {
            Sys.sleep(20)
            return(rnorm(i))
        }
        st <- system.time(res <- performParallel(5, rep(nrns, nprocs), fun=fun, cltype='MPI',
                                ft_verbose=TRUE))
        print(st)
      	stopifnot(length(res) == nprocs)
      	stopifnot(length(res[[1]]) == nrns)
}



check.reproducibility.for.seq.and.par <- function() {
	cat('\nCheck reproducibility for sequential and parallel runs ...')
	seed <- rep(1,6)
	nrep <- c(10,5)
	res.par <- performParallel(2, rep(nrep[1], nrep[2]), fun=rnorm, 
								cltype='SOCK', seed=seed)
	res.seq <- performParallel(0, rep(nrep[1], nrep[2]), fun=rnorm, seed=seed)
	eps <- 1e-10
	for (i in 1:nrep[2]) {
		for(j in 1:nrep[1])
			stopifnot(abs(res.par[[i]][j] - res.seq[[i]][j]) < eps)
	}
	cat(' OK.\n')
	cat('\nCheck non-reproducibility for sequential and parallel runs ...')
	res.seq2 <- performParallel(0, rep(nrep[1], nrep[2]), fun=rnorm) # no seed set
	eps <- 1e-3
	for (i in 1:nrep[2]) {
		for(j in 1:nrep[1])
			stopifnot(abs(res.par[[i]][j] - res.seq2[[i]][j]) > eps)
	}
	cat(' OK.\n')
}

