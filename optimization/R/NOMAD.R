> f <- function(x){
+     x1<-x[1]
+     x2<-x[2]
+     x3<-x[3]
+     x4<-x[4]
+     x5<-x[5]
+     y <- paste("ruby F.rb",x1,x2,x3,x4,x5)
+     z <- system(y,intern=TRUE)
+     j <- length(z)
+     as.numeric(z[j])}
> x0 <- c(1.0,90,.5,15,15)
> bbin <- bbin(c(1,1,1,1,1))
Error: could not find function "bbin"
> bbin <- c(1,1,1,1,1)
> lb <- c(0.5,0,0.1,1,1)
> ub <- c(2.0,180,0.9,30,30)
> bbout <- c(0,2,1)
> opts <-list("MAX_BB_EVAL"=500,
+             "MIN_MESH_SIZE"=0.001,
+             "INITIAL_MESH_SIZE"=0.1,
+             "MIN_POLL_SIZE"=0.0001)
> snomadr(eval.f=eval.f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, opts=opts)
Error in environment(eval.f) <- snomadr.environment : 
  object 'eval.f' not found
> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, opts=opts)
	  1 (1 90 0 15 15 )279.6100000000
	  2 (0 90 0 15 15 )146.7500000000
	  3 (0 88 0 15 15 )146.7300000000
	  4 (0 82 0 15 15 )146.7000000000
	  9 (0 82 0 17 19 )137.2100000000
	 10 (0 82 0 23 30 )125.6100000000
	 11 (0 82 0 30 30 )123.6000000000


Lost warning messages
> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, opts=opts, nmulti=8)
Error in snomadr(f, n = 5, x0 = x0, bbin = bbin, bbout = bbout, lb = lb,  : 
  
NOMAD has been interrupted ( NOMAD::Exception thrown (Parameters.cpp, 3489) invalid parameter: x0 > UPPER_BOUND  )

> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, nmulti=8,opts=opts)
Error in snomadr(f, n = 5, x0 = x0, bbin = bbin, bbout = bbout, lb = lb,  : 
  
NOMAD has been interrupted ( NOMAD::Exception thrown (Parameters.cpp, 3489) invalid parameter: x0 > UPPER_BOUND  )

> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, nmulti=1,opts=opts)
Error in snomadr(f, n = 5, x0 = x0, bbin = bbin, bbout = bbout, lb = lb,  : 
  
NOMAD has been interrupted ( NOMAD::Exception thrown (Parameters.cpp, 3489) invalid parameter: x0 > UPPER_BOUND  )

> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, nmulti=0,opts=opts)
	  1 (1 90 0 15 15 )279.6100000000

Warning message:
In eval.f(x, ...) : NAs introduced by coercion
> bbin <- c(0,0,0,0,0)
> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, nmulti=2,opts=opts)

starting point # 0: (  1 90 0.5 15 15 )
starting point # 1: ( 0.5000031093 0.0002850056627 0.1000025562 15.50001485 15.5000493 )


> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, nmulti=3,opts=opts)

starting point # 0: (  1 90 0.5 15 15 )
starting point # 1: ( 1.000002494 120.0004422 0.3666668639 20.33333473 10.66671501 )
starting point # 2: ( 0.5000020858 0.0001491839066 0.1000014788 10.66671187 1.000021186 )



Lost warning messages
> snomadr(c(f,f,f),n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, nmulti=3,opts=opts)
Error in checkFunctionArguments(eval.f, arglist, "eval.f") : 
  eval.f must be a function
> fix(f)
> ?snomadr
> snomadr(f,n=5, x0=x0, bbin=bbin, bbout=bbout, lb=lb, ub=ub, nmulti=3,opts=opts)

starting point # 0: (  1 90 0.5 15 15 )
starting point # 1: ( 1.500002284 0.0003916723655 0.1000005749 10.66670748 10.66669641 )
starting point # 2: ( 0.5000026805 120.0001771 0.366667439 20.33334227 20.33339633 )

run # 0: f=195.23
run # 1: f=195.22
run # 2: f=195.23

bb eval : 982
best    : 195.22
worst   : 195.23
solution: x = ( 0.5 165.1003917 0.1 30 30 ) f(x) = 195.22


Call:
snomadr(eval.f = f, n = 5, bbin = bbin, bbout = bbout, x0 = x0, 
    lb = lb, ub = ub, nmulti = 3, opts = opts)


nomad solver status: 8 ( Multiple mads runs - [3] )

Number of blackbox evaluations.....: 982 
Number of iterations...............: 120 
Optimal value of objective function:  195.22 
Optimal value of controls..........: 0.5 165.1004 0.1 30 30