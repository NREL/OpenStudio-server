# File PSO_v2012.R
# Part of the hydroPSO package, http://www.rforge.net/hydroPSO/
# Copyright 2008-2014 Mauricio Zambrano-Bigiarini
# Distributed under GPL 2 or later

################################################################################
##                          Random.Bounded.Matrix                             ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                        ##
################################################################################
# Created: 2008                                                               ##
# Updates: 23-Nov-2010                                                        ##
#          20-Sep-2012 ; 29-Oct-2012                                          ##
################################################################################
# Purpose  : To create a matrix randomly generated, with a bounded uniform distribution

# 'npart'   : number of particles in the swarm
# 'X.MinMax': Matrix of 'n' rows and 2 columns, 
#             the first column has the minimum values for each dimension, and
#             the second column has the maximum values for each dimension
Random.Bounded.Matrix <- function(npart, x.MinMax) {

  # dimension of the solution space (number of parameters )
  n <- nrow(x.MinMax)
	
  lower <- matrix( rep(x.MinMax[,1], npart), nrow=npart, byrow=TRUE)
  upper <- matrix( rep(x.MinMax[,2], npart), nrow=npart, byrow=TRUE)
	
  # random initialization for all the particles, with a value in [0,1]
  X <- matrix(runif(n*npart, min=0, max=1), nrow=npart, ncol=n)

  # Transforming X into the real range defined by the user
  #X <- t( lower +  (upper - lower )*t(X) ) # when using vector instead of matrixes
  X <- lower + (upper-lower)*X  
	
} # 'Random.Bounded.Matrix' end
#set.seed(1)
#Random.Bounded.Matrix(10, x.MinMax)


################################################################################
##                        random Latin-Hypercube Sampling                     ##
################################################################################
# Author: Mauricio Zambrano-Bigiarini                                         ##
# Created: 17-Dec-2010                                                        ##
# Updates: 20-Sep-2012  ; 29-Oct-2012                                         ##
#          07-Feb-2014                                                        ##
################################################################################
# Purpose  : Draws a Latin Hypercube Sample from a set of uniform distributions
#            for use in creating a Latin Hypercube Design
################################################################################
# Output   : An n by ndim Latin Hypercube Sample matrix with values uniformly 
#            distributed on 'ranges'
################################################################################

# 'n'      : number of strata used to divide each parameter range. 
#            For NRELpso: 'n=npart'
# 'ranges' : Matrix of 'N' rows and 2 columns, (N is the number of parameters)
#            the first column has the minimum values for each dimension, and
#            the second column has the maximum values for each dimension
rLHS <- function(n, ranges) {

  # dimension of the solution space (number of parameters )
  ndim <- nrow(ranges)
  
  # number of particles
  npart <- n
  
  lower <- matrix( rep(ranges[,1], npart), nrow=npart, byrow=TRUE)
  upper <- matrix( rep(ranges[,2], npart), nrow=npart, byrow=TRUE)
	
  # LHS initialization for all the particles, with a value in [0,1]
  X <- randomLHS(n, ndim) # lhs::randomLHS

  # Transforming X into the real range defined by the user
  #X <- t( lower +  (upper - lower )*t(X) ) # when using vector instead of matrixes
  X <- lower + (upper-lower)*X  
	
} # 'rLHS' end


################################################################################
#                                    enorm                                     #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Created: 19-Sep-2012                                                         #
# Updates:                                                                     #
################################################################################
# Purpose  : Computes the Euclidean norm of a vector                           #
################################################################################
# Output   : single numeric value with the euclidean norm of 'x'               #
################################################################################
enorm <- function(x) sqrt( sum(x*x) )


################################################################################
#                                alea.normal                                   #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
#          Based on the Matlab function developed by Maurice Clerc (May 2011), #
#          and available on:                                                   #
#          http://www.particleswarm.info/SPSO2011_matlab.zip                   #
################################################################################
# Created: 19-Sep-2012                                                         #
# Updates: 29-Oct-2012                                                         #
################################################################################
# Purpose  : It uses the polar form of the Box-Muller transformation to obtain #
#            a pseudo-random number from a Gaussian distribution               #
################################################################################
# Output   : single numeric value with a pseudo-random number from a Gaussian  #
#            distribution with mean='mean' and standard deviation ='sd'        #
################################################################################
alea.normal <- function(mean=0, sd=1) {

  w <- 2  
  while (w >= 1) {
     x1 <- 2 * runif(1) - 1
     x2 <- 2 * runif(1) - 1
     w  <- x1*x1 + x2*x2   
  } # 'WHILE' end   
  w  <- sqrt( -2*log(w) / w )
  y1 <- x1*w  
  if ( runif(1) < 0.5 ) y1 <- -y1  
  y1 <- y1 * sd + mean 

} # 'alea.normal' end


################################################################################
#                                alea.sphere                                   #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
#          Based on the Matlab function developed by Maurice Clerc (May 2011), #
#          and available on:                                                   #
#          http://www.particleswarm.info/SPSO2011_matlab.zip                   #
################################################################################
# Created: 19-Sep-2012                                                         #
# Updates:                                                                     #
################################################################################
# Purpose  : It generates a random point inside the hypersphere centered       #
#            around G with radius = r                                          #
################################################################################
# Output   : numeric vector with the location of a random point inside the     #
#            hypersphere around G with radius = r                              #
################################################################################
alea.sphere <- function(G, radius) {

  # dimension of 'G' (number of parameters)
  n <- length(G)
  
  # Step 1. Direction
  l <- 0
  #x <- replicate( n, alea.normal(mean=0, sd=1) )
  x <- rnorm(n, mean=0, sd=1)
  l <- sqrt( sum(x*x) )
  
  # Step 2. Random Radius
  r <- runif(1)
  
  x <- r * radius * x / l
  
  # Centering the random point at 'G'
  return( x + G)

} # 'alea.sphere' end


################################################################################
#                               compute.CF Function                            #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Created: 2008                                                                #
# Updates:                                                                     #
################################################################################
# Computes the Clerc's Constriction Factor
# Clerc, M.; Kennedy, J.; , "The particle swarm - explosion, stability, and 
# convergence in a multidimensional complex space," Evolutionary Computation, 
# IEEE Transactions on , vol.6, no.1, pp.58-73, Feb 2002
# doi: 10.1109/4235.985692

compute.CF <- function(c1, c2) {
    psi <- c1 + c2  # psi >= 4
    CF <- 2 / abs( 2 - psi - sqrt(psi^2 - 4*psi) )
} # 'compute.CF' end


   
# 'x' 	      : vector of 'n' parameters, corresponding to one particle
# 'v'         : vector of 'n' velocities of each parameter, corresponding to the current particle
# 'vmax.perc' : percentage of the range of each dimension that is allowed as 
#               maximum velocity in that dimension
# 'Pbest'     : matrix with the current best parameter values for all the particles
# 'gbest'     : vector with the best parameter values in the swarm
# 'w'	      : Inertial factor.
# 'c1'        : constant that encourages the exploration of the solution space
# 'c2'	      : constant that encourages the exploitation of the current global best
# 'CF'        : constant representing the Clerk's Constriction Factor,to insure convergence of the PSO algorithm
# 'x.MinMax'  : Matrix with the valid range for each parameter of 'X'.
#               Rows = 'n' (number of parameter
#               Columns = 2, 
#               First column has the minimum possible value for each parameter
#               Second column has the maximum possible value for each parameter
# 'topology'  : character, with the topology to be used in PSO. Valid values
#               are in c('gbest', 'lbest')
# 'method'    : character, with the method to be used as PSO algorithm. Valid values
#               are in c('spso2007', 'spso2011', 'ipso', 'fips', 'wfips')

# Result      : vector of 'n' velocities, one for each parameter, corresponding to the current particle
################################################################################
##                        compute.veloc Function                              ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Created: 2008                                                                #
# Updates: Oct-2011 ; Nov-2011                                                 #
#          19-Sep-2012 ; 20-Sep-2012 ; 28-Oct-2012 ; 31-Oct-2012               #
################################################################################
compute.veloc <- function(x, v, w, c1, c2, CF, Pbest, part.index, gbest, 
                          topology, method, MinMax, neighs.index, 
                          localBest, localBest.pos, 
                          ngbest.fit, ngbest, lpbest.fit) {

  pbest <- Pbest[part.index, ]
  
  # dimension of 'x' (number of parameters)
  n <- length(gbest)

  r1 <- runif(n, min=0, max=1)
  r2 <- runif(n, min=0, max=1)
  
  if ( method=="spso2011" ) {

       p <- x + r1*c1 * ( pbest - x )
       l <- x + r2*c2 * ( localBest - x )

      if ( part.index != localBest.pos) {
        Gr <- (x + p + l) / 3
      } else  Gr <- (x + p) / 2
     
      vn <- CF * (w*v + alea.sphere( G=Gr, radius= enorm(Gr-x) ) - x )
  
  } else if ( method == "spso2007" ) {
  
           if( part.index != localBest.pos) {
                  vn <- CF * ( w*v + r1*c1*(pbest-x) + r2*c2*(localBest-x) )
           } else vn <- CF * ( w*v + r1*c1*(pbest-x) ) 
    
         } else if ( method=="ipso" ) {
  
               # number of best particles that have to be considered      
               nngbest <- length(ngbest.fit)
  
               R2 <-  matrix(rep(r2,nngbest), nrow=nngbest, byrow=TRUE)
        
               # computing the c2 values for each one of the best particles,
               # weighted according to their fitness value
               if(MinMax == "min") {
                 c2i <- c2 * ( (1/ngbest.fit)/sum(1/ngbest.fit) )
               } else c2i <- c2 * ( ngbest.fit/sum(ngbest.fit) )
               
               nan.index <- which(is.nan(c2i))
               if (length(nan.index) > 0) c2i[nan.index] <- c2

               # transforming 'x' into a matrix, with the same values in each row, in 
               # order to be able to substract 'x' from 'ngest'
               X <- matrix(rep(x, nngbest), ncol=n, byrow=TRUE)
        
               # computing the velocity
               vn <- CF * ( w*v + r1*c1*(pbest-x) + colSums(R2*c2i*(ngbest-X) ) )      
           
           } else if ( method=="fips" ) {
              
                     neighs.index <- neighs.index[!is.na(neighs.index)] # only for topology=='random' 
                     N   <- length(neighs.index)              
                     X   <- matrix(rep(x,N), nrow=N, byrow=TRUE)
                     P   <- Pbest[neighs.index, ]
                     phi <- c1 + c2
                     r   <- runif(N, min=0, max=phi)
                 
                     vn  <-  CF * ( w*v + (1/N)*colSums( r*(P-X) ) )
              
               
                   } else if ( method=="wfips" ) {
            
                       neighs.index <- neighs.index[!is.na(neighs.index)] # only for topology=='random' 
                       N    <- length(neighs.index)              
                       X    <- matrix(rep(x,N), nrow=N, byrow=TRUE)
                       P    <- Pbest[neighs.index, ]
                       pfit <- lpbest.fit[neighs.index]
                       phi  <- c1 + c2
                       r    <- runif(N, min=0, max=phi)
                       if(MinMax == "min") {
                         wght <- (1/lpbest.fit)/sum(1/lpbest.fit)
                       } else wght <- lpbest.fit/sum(lpbest.fit) 
                   
                       vn  <-  CF * ( w*v + (1/N) * colSums( wght*r*(P-X) ) )	
                         
                     }  else if ( method == "canonical")    
                                       
                           vn <- CF * ( w*v + r1*c1*(pbest-x) + r2*c2*(localBest-x) )
                       
  
  return(vn)
  
} # 'compute.veloc' end


################################################################################
##                             roll.vector Function                           ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Created: 2009                                                                #
# Updates:                                                                     #
################################################################################
# 'old.vector': vector of length 'L' that will be rolled
# 'new.value' : real that will be put at the end of 'old.vector'

# Result: a vector with elements x.new[i] = x.old[i+1], i=1,L-1, x.new[L]= 'new.value'
roll.vector <- function(old.vector, new.value) {
  tmp	<- old.vector
  L		<- length(old.vector)  
  tmp[1:(L-1)]	<- old.vector[2:L]
  tmp[L]        <- new.value
  
  return(tmp)

} # 'roll.vector' end


################################################################################
##                       compute.value.with.iter Function                     ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Created: 2008                                                                #
# Updates: 29-Oct-2012                                                         #
################################################################################
# 'iter'    : the current iteration number
# 'niter'   : maximum number of iteration that can be done within a single run
# 'nexp'    : nonlinear modulation index
# 'val.ini' : initial inertial weight at the start of a given run
# 'val.fin' : fiinal inertial weight at the end of a given run

# Result    : Nonlinear modulated inertial weight
compute.value.with.iter <- function(iter, niter, nexp, val.ini, val.fin) {

  w <- ( ( (niter - iter) / niter )^nexp ) * ( val.ini - val.fin) + val.fin

} # 'compute.value.with.iter' end


################################################################################
##                         compute.w.aiwf Function                            ##
##                 Adaptive inertial weight factor (AIWF)                     ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                        ##
################################################################################
# Started: 2008                                                               ##
# Updates: 24-Nov-2011                                                        ##
#          22-Oct-2012 ; 28-Oct-2012                                          ##
################################################################################
# Reference:
# According to Liu et al., 2005 ("Improved Particle Swarm Combined with Caos")
# B. Liu, et al., "An improved particle swarm optimization combined with chaos," 
# Chaos, Solitons and Fractals, vol. 25, pp. 1261-1271, 2005.

# 'iter.fit'    : vector with 'n.particles' values corresponding to the fitness
#                 obtained in the current iteration for each one of the particles
# 'particle.pos': position of the particle, for identifying it
# 'gbest.fit'   : number with the best fitness found so far, considering all the particles
# 'w.max'       : initial inertial weight at the start of a given run (maximum value)
# 'w.min'       : final inertial weight at the end of a given run (minimum value)
# 'MinMax'      : string indicating if PSO have to find a minimum or a maximum for the fitness function.
#                 valid values are: "min", "max"

# Result        : Adaptive inertial weight factor (AIWF)
  
compute.w.aiwf <- function(iter.fit, particle.pos, gbest.fit, w.max, w.min, MinMax) {
  # 'f' : fitness value of the particle in the current iteration
  f <- iter.fit[particle.pos]
  
  # 'f.avg': mean fitness value of all the particles in the current iteration
  f.avg <- mean(iter.fit, na.rm=TRUE) 
  
  # 'f.min': best fitness value of all the particles in the current iteration
  if(MinMax == "min") {
    f.min <- min(iter.fit, na.rm=TRUE)
   } else f.min <- max(iter.fit, na.rm=TRUE)
  
  if(MinMax == "min") {
    to.apply <- f <= f.avg
  } else to.apply <- f >= f.avg
  
  if ( (to.apply) & (abs(f.avg - f.min)!=0) ) {
    w <- w.min + ( ( (w.max - w.min) * abs(f - f.min) ) / abs(f.avg - f.min) )
  } else w <- w.max
  
  return(w)

} # 'compute.w.aiwf' end



################################################################################
##                      compute.w.with.GLratio Function                       ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Started: 23-Dec-2010                                                         #
# Updates: 28-Oct-2012                                                         #
################################################################################
compute.w.with.GLratio <- function(MinMax, gbest.fit, pbest.fit) {
  
  # If we are Minimizing, the ratio 'gbest/pbest' have to be less than 1,
  # and the closer to 1, the closer the particle to 'gbest'
  if(MinMax == "min") { 
    w <- 1.1 - ( gbest.fit / mean(pbest.fit) )
  } else w <- 1.1 - ( mean(pbest.fit) / gbest.fit )
  
  return(w)

} # 'compute.w.with.GLratio' END


################################################################################
##                       compute.c1.with.GLratio Function                     ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Started: 27-Dec-2010                                                         #
# Updates: 28-Oct-2012                                                         #
################################################################################
# Based on M. Senthil Arumugam and M.V.C. Rao; 2008. Applied Soft Computing
# "On the improved Performances of the particle swarm optimization algorithms
#  with adaptive parameters, cross-over operators and root mean square (RMS) 
#  variants for computing optimal control of a class of hybrid systems"

# 'gbest.fit': global best objective function
# 'pbest.fit': best objective function of the current particle
compute.c1.with.GLratio <- function(MinMax, gbest.fit, pbest.fit) {
  
  # If we are Minimizing, the ratio 'gbest/pbest' have to be less than 1,
  # and the closer to 1, the closer the particle to 'gbest'
  if(MinMax == "min") { 
     c1 <- 1.0 + ( gbest.fit / pbest.fit )
  } else c1 <- 1.0 + ( pbest.fit / gbest.fit )
  
  return(c1)

} # 'compute.c1.with.GLratio' END


################################################################################
##                    velocity.boundary.treatment Function                    ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Started: 2008                                                                #
# Updates:                                                                     #
################################################################################
# 'x' 		  : vector of 'n' parameters, corresponding to one particle
# 'n'             : dimension of the solution space (number of parameters)
# 'X.MinMax'      : string indicating if PSO have to find a minimum or a maximum 
#                   for the fitness function.
#                   valid values are: "min", "max"
# 'v'             : vector of 'n' velocities of each parameter, corresponding to 
#                   the current particle
# 'boundary.wall' : boundary treatment that is used to limit the sea
#                   the limits given by 'X.MinMax'.
#                   Valid values are: 'absorbing', 'reflecting' and 'invisible'

# Result          : vector of 'n' velocities, one for each parameter, 
#                   corresponding to the current particle
velocity.boundary.treatment <- function(v, vmax ) {	
  
  byd.vmax.pos <- which( abs(v) > vmax )
  if ( length(byd.vmax.pos) > 0 ) 
       v[byd.vmax.pos] <- sign(v[byd.vmax.pos])*abs(vmax[byd.vmax.pos])
  
  return(v)
	
} # 'velocity.boundary.treatment' end


################################################################################
##                  position.update.and.boundary.treatment Function           ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Started: 2008                                                                #
# Updates: Nov-2011                                                            #
#          23-Sep-2012 ; 29-Oct-2012                                           #
################################################################################
# 'x'             : vector of 'n' parameters, corresponding to one particle
# 'X.MinMax'      : string indicating if PSO have to find a minimum or a maximum 
#                   for the fitness function.
#                   valid values are: "min", "max"
# 'v'             : vector of 'n' velocities of each parameter, corresponding to 
#                   the current particle
# 'boundary.wall' : boundary treatment that is used to limit the sea
#                   the limits given by 'X.MinMax'.
#                   Valid values are: 'absorbing', 'reflecting', 'invisible', 'damping'

# Result          : vector of 'n' velocities, one for each parameter, 
#                   corresponding to the current particle

# References:
# Robinson, J.; Rahmat-Samii, Y.; Particle swarm optimization in electromagnetics. 
# Antennas and Propagation, IEEE Transactions on , vol.52, no.2, pp. 397-407, 
# Feb. 2004. doi: 10.1109/TAP.2004.823969

# Huang, T.; Mohan, A.S.; , A hybrid boundary condition for robust particle
# swarm optimization. Antennas and Wireless Propagation Letters, IEEE , vol.4, 
# no., pp. 112-117, 2005. doi: 10.1109/LAWP.2005.846166
position.update.and.boundary.treatment <- function(x, v, x.MinMax, boundary.wall) {
 
 # Vector with the new positions of the current particle
 x.new <- x + v
 
 # By default the new velocity is assumed not to be limited
 v.new <- v
 
 # Minimum and maximum values for each dimension
 x.min <- x.MinMax[,1]
 x.max <- x.MinMax[,2]
 
 byd.min.pos <- which(x.new < x.min)
 if ( length(byd.min.pos) > 0) { 
    if ( boundary.wall == "absorbing2011") {     
       x.new[byd.min.pos] <- x.min[byd.min.pos]
       v.new[byd.min.pos] <- -0.5*v[byd.min.pos]      
    } else if ( boundary.wall == "absorbing2007") {     
         x.new[byd.min.pos] <- x.min[byd.min.pos]
         v.new[byd.min.pos] <- 0*v[byd.min.pos]      
      } else if ( boundary.wall == "reflecting") {    
           x.new[byd.min.pos] <- 2*x.min[byd.min.pos] - x.new[byd.min.pos] 
           v.new[byd.min.pos] <- -v[byd.min.pos]
      } else if ( boundary.wall == "invisible") {
             x.new[byd.min.pos] <- x[byd.min.pos]
             v.new[byd.min.pos] <- v[byd.min.pos]
        } else if ( boundary.wall == "damping") {
             L                  <- abs( x.min[byd.min.pos] - x.new[byd.min.pos] )
             x.new[byd.min.pos] <- x.min[byd.min.pos] + runif(1)*L
             v.new[byd.min.pos] <- -v[byd.min.pos]
        }# ELSE end
 } # IF end
      
 byd.max.pos <- which( x.new > x.max )
 if ( length(byd.max.pos) > 0 ) {	 
    if ( boundary.wall == "absorbing2011") { 
       x.new[byd.max.pos] <- x.max[byd.max.pos]
       v.new[byd.max.pos] <- -0.5*v[byd.max.pos] 
    } else if ( boundary.wall == "absorbing2007") { 
        x.new[byd.max.pos] <- x.max[byd.max.pos]
        v.new[byd.max.pos] <- 0*v[byd.max.pos] 
      } else if ( boundary.wall == "reflecting") {
           x.new[byd.max.pos] <- 2*x.max[byd.max.pos] - x.new[byd.max.pos] 
           v.new[byd.max.pos] <- -v[byd.max.pos]
        } else if ( boundary.wall == "invisible") {
             x.new[byd.max.pos] <- x[byd.max.pos]
             v.new[byd.max.pos] <- v[byd.max.pos]
          } else if ( boundary.wall == "damping") {
              L                  <- abs( x.new[byd.max.pos] - x.max[byd.max.pos])
              x.new[byd.max.pos] <- x.max[byd.max.pos] - runif(1)*L
              v.new[byd.max.pos] <- -v[byd.max.pos]
            }# ELSE end
 } # IF end
 
 out <- list(x.new=x.new, v.new=v.new)

} # 'position.update.and.boundary.treatment' end


################################################################################
##                    async.update.pgbests Function                           ##
################################################################################
## Author : Mauricio Zambrano-Bigiarini                                       ## 
################################################################################
## Started: 2008                                                              ##
## Updated: 26-Jan-2012 ; 28-Oct-2012                                         ##
################################################################################
# Function for updating the values of 'pbest', 'x.best', 'gbest.fit' and 'gbest.pos'
# for ONLY 1 particle !!

# 'x'           : vector with the 'n' parameters of a single particle
# 'x.pos'       : position of the current particle
# 'xt.fitness'  : particle's fitness
# 'MinMax'      : string indicating if PSO have to find a minimum or a maximum 
#                 for the fitness function.
#                 valid values are: "min", "max"
# 'of.name'     : function that will be used for computing the fitness.
# 'l.pbest.fit' : best fitness value found by the particle so far.
# 'gbest.fit'   : best fitness value found by the swarm so far.
# 'gbest.pos'   : position of the particle corresponding to 'gbest.fit'.
# 'x.best'      : 'n' values corresponding to the parameters of the particle 
#                 that achieve the best fitness value for the particle

# Result        : a list of 4 components (this values are different of the input ones,
#                 only if the new values provide a better fitness value )
#               : 1: pbest      : real with the new best fitness value of the particle
#               : 2: x.best     : vector with the new 'n' best parameters for the particle
#               : 3: gbest.fit  : real with the new best fitness value for the swarm
#               : 4: gbest.pos  : integer with the location of the particle that has
#                                 the best fitness value in the swarm

async.update.pgbests <- function(x, 
                                 x.pos, 
                                 xt.fitness,
                                 MinMax, 
                                 l.pbest.fit, 
                                 gbest.fit, 
                                 gbest.pos, 
                                 x.best
                                 ) {
  
  if(MinMax == "max") {
    l.update <- which(xt.fitness > l.pbest.fit )
  } else l.update <- which(xt.fitness < l.pbest.fit )
  
  # Updating 'pbest.fit', 'gbest.fit', 'gbest.pos' and 'x.best.part'
  if ( length(l.update>0) ) {
  
    # 'pbest.fit': updating the value of the best fit of the particles
    l.pbest.fit <- xt.fitness
    
    # 'X.best' updating
    x.best <- x  
    
    # 'gbest.fit': updating the value of the best global fit
    # 'gbest.pos': updating the position of the particle with the best global fit
    if ( MinMax=="max" ) {
      if ( l.pbest.fit > gbest.fit ) { 
          gbest.fit <- l.pbest.fit 
          gbest.pos <- x.pos 
      } # IF end 
    } else if ( MinMax=="min" ) {
        if ( l.pbest.fit < gbest.fit ) { 
           gbest.fit <- l.pbest.fit
           gbest.pos <- x.pos 
        } # IF end 
      } # ELSE end 
  
  } # IF end  
                
  tmp      <- list(4)
  tmp[[1]] <- l.pbest.fit
  tmp[[2]] <- x.best
  tmp[[3]] <- gbest.fit
  tmp[[4]] <- gbest.pos 
  names(tmp)  <- c("pbest", "x.best", "gbest.fit", "gbest.pos") 
                
  return(tmp)
                 
} # 'async.update.pgbests' end


################################################################################
##                        sync.update.pgbests Function                        ##
################################################################################
## Author : Mauricio Zambrano-Bigiarini                                       ## 
################################################################################
## Started: 2008                                                              ##
## Updated: 27-Jan-2012 ; 28-Oct-2012                                         ##
################################################################################
# Function for updating the values of 'pbest', 'x.best', 'gbest.fit' and 'gbest.pos'
# for the ALL the SWARM !!

# 'x'                : Matrix with the 'n' parameters of all the particles
# 'xt.fitness'       : numeric vector of 'n.particles', with the current fitness 
#                      obtained by all the particles in the swarm
# 'MinMax'           : Character indicating if PSO have to find a minimum or a 
#                      maximum for the fitness function.
#                      Valid values are in: c('min', 'max')
# 'pbest.fit'        : numeric vector with length equal to 'n.particles', with the best 
#                      fitness value found by each particle in the swarm so far.
# 'gbest.fit'        : numeric, with the best fitness value found by the swarm so far.
# 'gbest.pos'        : numeric, with the position of the particle corresponding 
#                      to 'gbest.fit'.
# 'x.best'           : Matrix of 'n*n.particles' values, corresponding to the
#                      'n' parameters of each one of the particles in the swarm 
#                      that achieve the best fitness value for the particle

# Result: a list of 4 components (this values are different of the input ones,
#         only if the new values provide a better fitness value )
#       : 1: pbest.fit  : numeric vector with the new best fitness value of each 
#                         particle
#       : 2: x.best     : matrix with the new 'n' best parameters for each particle
#       : 3: gbest.fit  : numeric (single value) with the new best fitness value 
#                         for the swarm
#       : 4: gbest.pos  : integer with the location of the particle that has the 
#                         best fitness value in the swarm   

sync.update.pgbests <- function(x, 
                                xt.fitness, 
                                MinMax, 
                                pbest.fit, 
                                gbest.fit, 
                                gbest.pos, 
                                x.best
                                ) {
  
  # index of all the particles which current fit is better than their last 'pbest'
  if(MinMax == "max") {
    better.index <- which( xt.fitness > pbest.fit )
  } else better.index <- which( xt.fitness < pbest.fit )
                          
  # if it exists some particles that have a better fitness value
  if (length(better.index) > 0) {
  
    # 'pbest.fit': updating the value of the best fit for each particle
    pbest.fit[ better.index ] <- xt.fitness[better.index ]
    
    # 'X.best.part': updating the value of the best parameters for the particles 
    #                with better fitness
    x.best[better.index, ] <- x[better.index, ]  
    
    # 'gbest.fit': updating the value of the best global fit
    # 'gbest.pos': updating the position of the particle with the best global fit
    if ( MinMax == "max" ) {    
      if ( max(pbest.fit, na.rm=TRUE) > gbest.fit ) { 
          gbest.pos <- which.max(pbest.fit) 
          #gbest.fit <- max(xt.fitness[better.index ])          
          gbest.fit <- pbest.fit[gbest.pos]
      } # IF end          
    } else if ( MinMax == "min" ) {    
          if ( min(pbest.fit, na.rm=TRUE) < gbest.fit ) { 
              gbest.pos <- which.min(pbest.fit) 
              #gbest.fit <- min(xt.fitness[better.index ])
              gbest.fit <- pbest.fit[gbest.pos]
          } # IF end          
      } # ELSE end 
                                                   
  } # IF end   
  
  # Creating the output
  tmp      <- list(4) 
  tmp[[1]] <- pbest.fit
  tmp[[2]] <- x.best
  tmp[[3]] <- gbest.fit
  tmp[[4]] <- gbest.pos 
  names(tmp)  <- c("pbest", "x.best", "gbest.fit", "gbest.pos") 
                
  return(tmp)
  
} # 'sync.update.pgbests' end


################################################################################
#                          computeCurrentXmaxMin                               #
################################################################################
# Author: Mauricio Zambrano-Bigiarini                                          #
# Started: 22-Dec-2010                                                         #
# Updates: 28-Oct-2012                                                         #
################################################################################
# Purpose: To compute the minimum parameter range currently embraced for the best
#          positions found so far in the swarm
################################################################################
# 'x.best.part': matrix with the best parameter values for each particle.
#                nrows = number of particles
#                ncols = number of parameters = n 
computeCurrentXmaxMin <- function(x.best.part) {

  # number of parameters
  n <- ncol(x.best.part)

  x.min <- sapply(1:n, function(i,y) { min(y[,i], na.rm=TRUE) }, y = x.best.part)
  x.max <- sapply(1:n, function(i,y) { max(y[,i], na.rm=TRUE) }, y = x.best.part)
	
  return (cbind(x.min, x.max))
                              
}  # 'computeCurrentXmaxMin' END


################################################################################
#                      decrease.search.space Function                          #
################################################################################
## Author : Mauricio Zambrano-Bigiarini                                       ## 
################################################################################
## Started: 2010                                                              ##
## Updated:                                                                   ##
################################################################################
# Decrease the search space according to the methodology proposed in the CPSO #

# 'Lmin.min'        : vector of 'n' elements, with the minimum value that each dimension
#                     take within the minimum searching space defined by the user
# 'Lmin.max'        : vector of 'n' elements, with the maximum value that each dimension
#                     take within the minimum searching space defined by the user
# 'Lmin'            : vector of 'n' elements, with the minimum length that each dimension
#                     can take in the searching space defined by the user
# 'x.MinMaxCurrent' : Matrix with the minimum and maximum values for each dimension 
#                     during the current iteration
#                     Rows = 'n' (number of parameters)
#                     Columns = 2, 
#                     First column has the minimum possible value for each parameter
#                     Second column has the maximum possible value for each parameter
# 'x.MinMaxRange'   : Matrix with the valid range for each parameter of 'X', as 
#                     defined by the user
#                     Rows = 'n' (number of parameters)
#                     Columns = 2, 
#                     First column has the minimum possible value for each parameter
#                     Second column has the maximum possible value for each parameter
# 'x.best'          : vector of 'n' elements with the parameters of the particle 
#                     with the best fitness value
# 'r'               : real between 0 and 1.  Only required when 'use.CLS' =TRUE
#                     represents the rate that is used for decreasing the 
#                     searching space in the chaotic implementation 

# Result            : vector with the 'n' parameters of only 1 particle
decrease.search.space <- function(Lmin, x.MinMaxCurrent, x.MinMaxRange, x.best, r) {
  
  # name of each parameter  
  param.IDs <- row.names(x.MinMaxRange)
  
  # number of dimensions
  n <- length(param.IDs)

  # Removing possible attributes
  x.best     <- as.numeric( x.best ) 
  x.min.curr <- as.numeric( x.MinMaxCurrent[ ,1] )
  x.max.curr <- as.numeric( x.MinMaxCurrent[ ,2] )
  x.min.rng  <- as.numeric( x.MinMaxRange[ ,1] )
  x.max.rng  <- as.numeric( x.MinMaxRange[ ,2] )

  # Current lenght of the parameter space in each dimension
  Lcurr <- x.max.curr - x.min.curr 

  # New desired lenght of the parameter space in each dimension
  Lnew  <- r*Lcurr  

  # Creating the new minimum and maximum boundaries
  x.min.new <- x.min.curr
  x.max.new <- x.max.curr

  # Updating the boundaries when the new length is larger than Lmin
  for (i in 1:n) {
    if (Lnew[i] >= Lmin[i]) {
      x.min.new[i] <- max( x.min.curr[i], x.best[i] - 0.5*Lnew[i] )
      x.max.new[i] <- min( x.max.curr[i], x.best[i] + 0.5*Lnew[i] )
      #x.min.new[i] <- max( x.min.rng[i], x.best[i] - 0.5*Lnew[i] )
      #x.max.new[i] <- min( x.max.rng[i], x.best[i] + 0.5*Lnew[i] )
    } # IF end      
  } # FOR end

  # New lenght of the parameter space in each dimension
  Lnew  <- x.max.new - x.min.new 

  #x.min.new <- pmax(x.min.rng, x.best - 0.5*Lnew )
  #x.max.new <- pmin(x.max.rng, x.best + 0.5*Lnew )
  
  x.MinMaxCurrent[ ,1] <- x.min.new
  x.MinMaxCurrent[ ,2] <- x.max.new
  
  # Relative change achieved in each dimension
  rel.change        <- (Lnew-Lcurr)/Lcurr
  names(rel.change) <- param.IDs 
  
  return(x.MinMaxCurrent) 

} # 'decrease.search.space' end 
#decrease.search.space(Lmin, x.MinMaxCurrent, x.MinMaxRange, x.best, r)


################################################################################
#                            InitializateX                                     #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
# Started: 23-Dec-2010                                                         #
# Updates: 24-Dec-2010                                                         #
#          28-Oct-2012                                                         #
################################################################################
# Purpose: Function for the initialization of the position and the velocities  # 
# of all the particles in the swarm                                            #
################################################################################
# -) npart     : number of particles
# -) X.MinMax  : Matrix with the minimum and maximum values for each dimension 
#                during the current iteration
#              -) Rows = 'n' (number of parameters)
#              -) Columns = 2, 
#                 First column has the minimum possible value for each parameter
#                 Second column has the maximum possible value for each parameter
# 'init.type' : character, indicating how to carry out the initialization 
#               of the position of all the particles in the swarm
#               valid values are in c('random', 'lhs') 
InitializateX <- function(npart, x.MinMax, x.ini.type) {
 
  # 'X' #
  # Matrix of unknown parameters. 
  # Rows = 'npart'; 
  # Columns = 'n' (Dimension of the Solution Space)
  # Random bounded values are assigned to each dimension
  if ( x.ini.type=="random" ) {
      X <- Random.Bounded.Matrix(npart, x.MinMax)
  } else X <- rLHS(npart, x.MinMax)      

  return(X)

} # InitializateX


################################################################################
#                            InitializateV                                     #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
# Started: 24-Dec-2010                                                         #
# Updates: 24-Nov-2011                                                         #
#          17-Sep-2012 ; 28-Oct-2012                                           #
################################################################################
# Purpose: Function for the initialization of the position and the velocities  #
#          of all the particles in the swarm                                   #
################################################################################
# -) npart     : number of particles
# -) X.MinMax  : Matrix with the minimum and maximum values for each dimension 
#                during the current iteration
#              -) Rows = 'n' (number of parameters)
#              -) Columns = 2, 
#                 First column has the minimum possible value for each parameter
#                 Second column has the maximum possible value for each parameter
# 'v.ini'      : character, indicating how to carry out the initialization 
#                of the velocitites of all the particles in the swarm
#                valid values are in c('zero', 'random2007', 'lhs2007', 'random2011', 'lhs2011') 
InitializateV <- function(npart, x.MinMax, v.ini.type, Xini) {

  # Number of parameters
  n <- nrow(x.MinMax)
 
  # 'V' #
  # Matrix of velocities for each particle and iteration. 
  # Rows    = 'npart'; 
  # Columns = 'n' (Dimension of the solution space)
  # Random bounded values are assigned to each dimension
  
  if (v.ini.type %in% c("random2011", "lhs2011") ) {
    lower <- matrix( rep(x.MinMax[,1], npart), nrow=npart, byrow=TRUE)
    upper <- matrix( rep(x.MinMax[,2], npart), nrow=npart, byrow=TRUE)
    
    if ( v.ini.type=="random2011" ) {
      V <- matrix(runif(n*npart, min=as.vector(lower-Xini), max=as.vector(upper-Xini)), nrow=npart)
    } else if ( v.ini.type=="lhs2011" ) {
        # LHS initialization for all the particles, with a value in [0,1]
        V <- randomLHS(npart, n) 

        # Transforming V into the real range defined by SPSO-2011
        lower <- lower - Xini
        upper <- upper - Xini

        V <- lower + (upper-lower)*V  
      } # ELSE end 
  } else if ( v.ini.type=="random2007" ) {
        V <- ( Random.Bounded.Matrix(npart, x.MinMax) - Xini ) / 2
      } else if ( v.ini.type=="lhs2007" ) {
          V <- ( rLHS(npart, x.MinMax) - Xini ) / 2
        } else if ( v.ini.type=="zero" ) {
            V <- matrix(0, ncol=n, nrow=npart, byrow=TRUE)    
          } # ELSE end

  return(V)

} # InitializateV



################################################################################
##                            UpdateLocalBest                                 ##
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                        ##
# Started: 24-Dec-2010                                                        ##
# Updates: 29-Dec-2010 ;                                                      ##
#          14-Nov-2011 ; 27-Jan-2011                                          ##
#          28-Oct-2012 ; 29-Oct-2012                                          ##
################################################################################
# Purpose: Function for computing the best value in the neighbourhood of each 
#          particle
################################################################################
# pbest.fit    : numeric, with best fitness in the history of each particle
# LocalBest.fit: numeric, best fitness in the history of the neighbourhood of 
#                each particle
# x.neighbours : numeric matrix, with the index/position of the particles that 
#                are considered "informants" of each particle.
#                rows   = number of particles
#                columns= K+1 ; K: nmbr of informants provided by the user
# MinMax       : character, indicating if PSO have to find a minimum or a 
#                maximum for the fitness function.
#                Valid values are in: c('min', 'max')
 
UpdateLocalBest <- function(pbest.fit, localBest.pos, localBest.fit, x.neighbours, MinMax) {

  # Number of particles
  npart <- nrow(x.neighbours)  
  
  for ( i in 1:npart ) {
  
    # index of all the particles that are "neighbours" to the particle 'i'
    neighs.index <- x.neighbours[i,]
    
    # if one or more of the "neighbours" have a better fitness than the current Local Best
    if(MinMax == "max") { 
      best.neigh.index <- which.max( pbest.fit[neighs.index] )
      if (pbest.fit[best.neigh.index] > localBest.fit[i] ) {
        localBest.pos[i] <- neighs.index[best.neigh.index ]
        localBest.fit[i] <- pbest.fit[localBest.pos[i]]
      } # IF end
    } else {
        best.neigh.index <- which.min( pbest.fit[neighs.index] )
        if ( pbest.fit[neighs.index][best.neigh.index] < localBest.fit[i] ) {
          localBest.pos[i] <- neighs.index[best.neigh.index]
          localBest.fit[i] <- pbest.fit[localBest.pos[i]]
        } # IF end
      } # ELSE end
    
  } # FOR end 
  
  out <- list(localBest.pos=localBest.pos, localBest.fit=localBest.fit)

} # UpdateLocalBest


################################################################################
#                            UpdateNgbest                                      #
################################################################################
# Author : Mauricio Zambrano-Bigiarini
# Started: 24-Dec-2010
# Updates: 29-Dec-2010
#          28-Oct-2012
################################################################################
# Purpose: Function for computing the 'n.neighbours' best values in the swarm, 
#          and its positions
################################################################################
# pbest.fit : numeric, with best fitness in the history of each particle
# ngbest    : Number of local best that have to be considered
# MinMax    : character, indicating if PSO have to find a minimum or a 
#             maximum for the fitness function.
#             Valid values are in: c('min', 'max')
 
UpdateNgbest <- function(pbest.fit, ngbest, MinMax) {
  
  if(MinMax=="max") {
    sorted.fit <- sort(pbest.fit, decreasing= TRUE)
  } else sorted.fit <- sort(pbest.fit, decreasing= FALSE)
                            
  # Ordered index of all the particles, 
  # MinMax=="max" => Decreasing order
  # MinMax=="min" => Increasing order
  sorted.index <- pmatch(sorted.fit, pbest.fit)
  
  ngbest.fit <- pbest.fit[sorted.index][1:ngbest]  
  ngbest.pos <- sorted.index[1:ngbest]    

  # Creating the output
  out <- list(2)
  out[[1]] <- ngbest.fit
  out[[2]] <- ngbest.pos
  names(out) <- c("ngbest.fit", "ngbest.pos")
  
  return(out)

} # UpdateNgbest


################################################################################
#                    ComputeSwarmRadiusAndDiameter                             #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
# Started: 12-Jan-2011                                                         #
# Updates: 12-Jan-2011 ; 28-Oct-2011                                           #
#          06-Nov-2012 ; 07-Nov-2012                                           #
################################################################################
# Purpose: Function for computing the swarm radius, for detecting premature    #
#          convergence, in order to avoid stagnation                           #
################################################################################
# X      : matrix, with the current parameter values for all the particles
# gbest  : numeric, with the parameter values for the best particle in the swarm
#          Valid values are in: c('min', 'max')
# Lmax   : vector with the range of the search space in each dimension
 
ComputeSwarmRadiusAndDiameter <- function(x, gbest, Lmax) {
  
  # number of parameters
  n <- ncol(x)
  
  # number of particles
  npart <- nrow(x)
  
  # Euclidean distance, in the n-dimensional space for all the particles
  radius <- numeric(npart)
  
  gbest  <- matrix(rep(gbest, npart), nrow=npart, byrow=TRUE)
  radius <- sqrt( rowSums( (x-gbest)^2, na.rm=TRUE) )
  
  #swarm.radius   <- max(radius, na.rm=TRUE)
  swarm.radius   <- median(radius, na.rm=TRUE)
  swarm.diameter <- sqrt(sum(Lmax^2))

  out        <- list(2)
  out[[1]]   <- swarm.radius
  out[[2]]   <- swarm.diameter
  names(out) <- c("swarm.radius", "swarm.diameter")
  
  return( out )

} # ComputeSwarmRadiusAndDiameter


################################################################################
#                           RegroupingSwarm                                    #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
# Started: 13-Jan-2011                                                         #
# Updates: 18-Nov-2011                                                         #
#          06-Nov-2012 ; 07-Nov-2012 ; 08-Nov-2012                             #
################################################################################
# Purpose: Function for regrouping the swarm in a search space centered around #
#          the global best, which is hoped to be both, small enough for        #
#          efficient search and large enough to allow the swarm to escape from #
#          the current local best.                                             #
#          There are 4 differences wrt Evers and Ghalia 2009:                  #
#          -) swarm radius: median is used instead of max                      #
#          -) computation of the new range of parameter space, which           #
#             corresponds to the maximum boundary of all the swarm, instead of #
#             abs(x-Gbest)                                                     #
#          -) regrouping factor: user-defined instead of 6/(5*ro)              #
#          -) velocity is re-initialized using Vini.type instead of using the  #
#             formula proposed by Evers and Ghalia 2009                        #
################################################################################
# Reference: Evers, G.I.; Ben Ghalia, M. 2009. Regrouping particle swarm       #
#            optimization: A new global optimization algorithm with improved   #
#            performance consistency across benchmarks.                        #
#            Systems, Man and Cybernetics, 2009. SMC 2009.                     #
#            IEEE International Conference on, vol., no., pp.3901-3908,        #
#            DOI: 10.1109/ICSMC.2009.5346625                                   #
################################################################################
RegroupingSwarm <- function(x, 
                            xini.type, 
                            v, 
                            vini.type,
                            gbest, 
                            x.Range,
                            Lmax,
                            RG.thr,
                            RG.r) {

  # number of parameters
  n <- ncol(x)
  
  # number of particles
  npart <- nrow(x)

  # Regrouping factor 
  rf <- RG.r          # user-defined
  #rf <- 6/(5*RG.thr) # Evers & Ghalia
  
  # name of each parameter  
  param.IDs <- row.names(x.Range)

  # Removing possible attributes
  x.min.rng  <- as.numeric( x.Range[ ,1] )
  x.max.rng  <- as.numeric( x.Range[ ,2] )
  
  # Computing current boundaries for the whole swarm
  xmin    <- apply(x, MARGIN=2, FUN=min) 
  xmax    <- apply(x, MARGIN=2, FUN=max) 
  xMinMaxO <- cbind(xmin, xmax)  
  #message("Boundaries0  :")
  #print(xMinMaxO)
  
  # Maximum length of the parameter space in each dimension
  RangeO <- xmax - xmin   
  #message("RangeO  :")
  #print(RangeO)

  # Transforming the 'gbest' into a matrix, in order to make easier some 
  # further computations
  Gbest <- matrix(rep(gbest, npart), nrow=npart, byrow=TRUE)

  # New desired length of the parameter space in each dimension
  # Is equal to the product of the regrouping factor with the maximum distance of 
  # each particle to the global best, for each dimension
  #RangeNew <- rf * apply( abs(x-Gbest), MARGIN=2, FUN=max) ## Evers & Ghalia
  RangeNew <- rf * abs(xmax - xmin)                        ## MZB
  
  # Making sure that the new range for each dimension is no larger than the original one
  RangeNew <- pmin(abs(x.max.rng - x.min.rng), RangeNew)  
  #message("RangeNew:")
  #print(RangeNew)

  # Re-initializing particle's positions around gbest
  for (part in 1:npart) {
    r3        <- runif(n, 0, 1) 
    x[part, ] <- gbest + r3*RangeNew - 0.5*RangeNew
    # If needed, Clamping the particle positions to the maximum value
    x[part, ] <- pmin(x[part,], x.max.rng)
    # If needed, Clamping the particle positions to the minimum value 
    x[part, ] <- pmax(x[part,], x.min.rng)
  } # FOR end
  
  # Defining the new boundaries
  #xmin <- gbest - 0.5*RangeNew           ## Evers & Ghalia
  #xmax <- gbest + 0.5*RangeNew           ## Evers & Ghalia  
  xmin    <- apply(x, MARGIN=2, FUN=min)  ## MZB
  xmax    <- apply(x, MARGIN=2, FUN=max)  ## MZB
  xMinMax <- cbind(xmin, xmax)            ## MZB  
  #message("Gbest:")
  #print(gbest)
  #message("BoundariesNew:")
  #print(xMinMax)   
  
  # Printing old velocities
  #vmin    <- apply(v, MARGIN=2, FUN=min) 
  #vmax    <- apply(v, MARGIN=2, FUN=max) 
  #vMinMax <- cbind(vmin, vmax)
  #message("OldBoundariesV:")
  #print(vMinMax)
  
  # Re-initializing velocities
  v <- InitializateV(npart=npart, x.MinMax=xMinMax, v.ini.type=vini.type, Xini=x)
  
  # Printing new velocities
  #vmin    <- apply(v, MARGIN=2, FUN=min) 
  #vmax    <- apply(v, MARGIN=2, FUN=max) 
  #vMinMax <- cbind(vmin, vmax)  
  #message("NewBoundariesV:")
  #print(vMinMax)
  
  # Relative change achieved in each dimension
  #rel.change        <- (RangeNew-RangeO)/RangeO
  #names(rel.change) <- param.IDs 
  
  out      <- list(3)
  out[[1]] <- x
  out[[2]] <- v
  out[[3]] <- RangeNew
  names(out)  <- c("X", "V", "RangeNew") 
  
  return(out) 
  
} # 'RegroupingSwarm' end


################################################################################
#                      Random.Topology.Generation                              #
################################################################################
# Author : Mauricio Zambrano-Bigiarini
# Started: 23-Nov-2011
# Updates: 
################################################################################
# Purpose: Function for creating a random topology, as implemented on the 
#          Standard PSO 2007
################################################################################
Random.Topology.Generation <- function(npart, K, 
                                       psoout.drty, iter # only needed during testing phase
                                       ) { 

  p.avg <- 1 - (1 - 1/npart)^K
  tmp   <- matrix(runif(npart*npart, 0, 1) <= p.avg, nrow=npart, ncol=npart)
  diag(tmp) <- TRUE
  X.neighbours <- matrix(rep(NA, npart*npart), ncol=npart, nrow=npart, byrow=TRUE)
  for (i in 1:npart) {
       l <- length(which(tmp[,i]))
       X.neighbours[i, 1:l] <- which(tmp[,i])
  } # FOR end
  
  return(X.neighbours)

} # ELSE end


################################################################################
#                                    P.S.O.                                    #
################################################################################
# Author : Mauricio Zambrano-Bigiarini                                         #
################################################################################
# Started: 2008                                                                #
# Updates: Dec-2010                                                            #
#          May-2011    ; 28-Oct-2011 ; 14-Nov-2011 ; 23-Nov-2011 ;             #
#          15-Jan-2012 ; 23-Jan-2012 ; 30-Jan-2012 ; 23-Feb-2012 ; 23-Mar-2012 #
#          14-Jun-2012 ; 15-Jun-2012 ; 03-Jul-2012 ; 06-Jul-2012               #
#          11-Jul-2012 ; 17-Jul-2012 ; 18-Jul-2012 ; 13-Sep-2012 ; 14-Sep-2012 #
#          17-Sep-2012 ; 23-Sep-2012 ; 15-Oct-2012 ; 25-Oct-2012 ; 28-Oct-2012 #
#          08-Nov-2012 ; 26-Nov-2012 ; 27-Nov-2012 ; 28-Nov-2012 ; 29-Nov-2012 #
#          19-Dec-2012                                                         #
#          07-May-2013 ; 10-May-2013 ; 28-May-2013 ; 29-May-2013               #
#          07-Feb-2014 ; 09-Abr-2014                                           #
################################################################################
# 'lower'           : minimum possible value for each parameter
# 'upper'           : maximum possible value for each parameter
# 'of.name'         : String with the test function that will be used for computing the fitness.
#                     Valid values are in: c('sinc', 'rosenbrock', 'sphere', 
#                     'rastrigin', 'griewank', 'schafferF6', 'hydromod')
# 'MinMax'          : character, indicating if PSO have to find a minimum or a 
#                     maximum for the fitness function.
#                     Valid values are in: c('min', 'max')
# 'npart'           : number of particles that makes the swarm. 
#                     Must be divisible by 5 (requirement for the chaotic part)
# 'maxit'           : numeric, with the maximum number of iterations
# 'c1'              : numeric, representing the cognition constant. 
#                     Encourages the exploitation of the solution space.
#                     How much the particle is influenced by the memory of his best location
# 'c2'              : numeric, representing the social constant. 
#                     Encourages the exploration of the current global best
#                     How much the particle is influenced by the rest of the swarm	
# 'use.CF'          : logical, indicating if the Clerc's Constriction Factor have to be used
#                     to ensure the convergence of the PSO algorithm
# 'lambda'          : numeric in [0,1] representing a percentage to limit
#                     the maximum velocity for each dimension, which is computed
#                     as 'vmax = Vmax.perc*(Xmax-Xmin)'
# 'par'             : OPTIONAL. numeric of length 'n' (number of parameters), 
#                     providing a first guess for the parameters to be optimised. 
#                     If it is not present, all the particles are randomly initialized,
#                     according to the value of \code{Xini.type}
# 'Xini.type'       : character, indicating how to initialise the position of all
#                     the particles in the swarm, within the ranges defined by 
#                     \code{X.Boundaries}. Valid values are: \cr
#                     -) "random": random initialisation
#                     -) "lhs"   : Latin Hypercube initialisation. \bold{it 
#                                  requires the \pkg{lhs} package}
# 'Vini.type        : character, indicating how to initialise the velocity of all
#                     the particles in the swarm, within the ranges defined by 
#                     \code{X.Boundaries}. Valid values are: \cr
#                     -) 0       : all the particles are initialised with zero velocity
#                     -) "random": random initialisation
#                     -) "lhs"   : Latin Hypercube initialisation. \bold{it 
#                                  requires the \pkg{lhs} package}
# 'best.update'     : character, indicating when to update the global and local best
#                     Valid values are: \cr
#                     -) "sync" : the update is made in a synchronous way, i.e., 
#                                 after computing the position and fitness of 
#                                 ALL the particles in the swarm
#                     -) "async": the update is made in an asynchronous way, i.e., 
#                                 after computing the position and fitness of 
#                                 EACH particle in the swarm
# 'boundary.wall'   : Boundary treatment that is used to limit the sea
#                     the limits given by 'X.Boundaries'.
#                     Valid values are: 'absorbing', 'reflecting' and 'invisible'
#                     See  \citet{RobinsonRahmatSamii2004}
# 'topology'        : character, with the neighbourhood topology to be used in PSO. 
#                     Valid values are in \code{c('gbest', 'lbest', 'ipso')}:
#                      \kbd{gbest}: every particle is connected to every other individual,
#                                   and in particular to the best one. This is 
#                                   also termed \textit{star} topology, and it is 
#                                   generally assumed to have a fast convergence. 
#                                   However, if the global optimum is not close 
#                                   to the attraction zone of the best particle, 
#                                   the swarm can get trapped into local optima.
#                                   see Kennedy 1999; Kennedy and Mendes 2002
#                      \kbd{lbest}: each particle is connected to its \textit{K} 
#                                   immediate neighbours only. This is also termed 
#                                   \textit{circles} or \textit{ring} topology, 
#                                   and generally the swarm will converge slower 
#                                   than with the \kbd{gbest} topology,
#                                   but it has a greater chance to locate the
#                                   global optimum. see Kennedy 1999; Kennedy and Mendes 2002
#                      \kbd{ipso}:  At each iteration, al the particles in the swarm
#                                   are rearranged in descending order according 
#                                   to  their fitness value and the best \kbd{ngbest}
#                                   particles to modify particle's position and velocity. 
#                                   See Zhao 2006.
# 'K'               : OPTIONAL. Only used when \code{topology=='lbest'}
#                     numeric, with the total amount of neighbours of each particle
#                     to be considered in the computation of their personal best.
#                     It MUST BE an even number, in order to consider the same 
#                     amount of neighbours to the left and the right of each particle.
#                     By default \code{K=3}. 
# 'iter.ini'        : OPTIONAL. Only used when \code{topology=='lbest'}
#                     numeric, with the amount of iterations in which the topology 
#                     \kbd{gbest} will be used before starting to use the \kbd{lbest}
#                     topology for the computation of the personal best of each particle.
#                     This argument has not been found in literature, and it aims at
#                     making faster the localization of the global zone of attraction. 
#                     By default \code{iter.ini=0}.
# 'ngbest'          : OPTIONAL. Only used when \code{topology=='ipso'}
#                     numeric, with the amount of particles that will be considered 
#                     in the computation of the global best. \cr
#                     By default \code{ngbest=4}. See Zhao 2006.
# 'use.IW'          : logical, indicating if an inertia weight (\env{w}) will be used
#                     to avoid particles fly around their best position without 
#                     converging into it. See Shi and Eberhart 1998 and Zheng et al. 2003.
# 'IW.type'         : OPTIONAL, only required when \code{use.IW= TRUE}.
#                     character, that defined how to vary the inertia weight 
#                     \env{w} along the iterations. Valid values are: \cr
#                     Valid values are: \cr
#                     -) "linear"    : \env{w} varies linearly between the initial 
#                                       and final values specified by the user 
#                                       in \code{IW.w}. 
#                                       See Shi and Eberhart, 1998. and Zheng et al., 2003
#                     -) "non-linear": \env{w} varies non-linearly between the initial 
#                                       and final values specified by the user 
#                                       in \code{IW.w}. 
#                                       See Chatterjee and Siarry, 2006. \cr
#                     -) "runif"     : \env{w} is a uniform random variable in
#                                       the range [w.min, w.max] specified by the user 
#                                       in \code{IW.w}. It is a generalization of 
#                                       the variation proposed in Eberhart and Shi, 2001b
#                     -) "aiwf"      : Adaptive inertia weight factor, where the 
#                                      inertia weight is varied adaptively 
#                                      depending of the objective values of the particles \cr
#                                      See Liu et al., 2005 \cr
#                     -) "GLratio"   : \env{w} varies according to the ration between 
#                                      the global best and the average of the particle's 
#                                      local best. See Arumugam and Rao, 2008 \cr
# 'IW.w'            : OPTIONAL, only required when \code{use.IW= TRUE & IW.type!='GLratio'}
#                     numeric with the inertia weight(s) (\env{w} or \env{[w.ini, w.fin]}). 
#                     It can be one single number which is then used during all the algorithm, 
#                     or it can be a vector of length 2, with the initial and final values 
#                     (in that order) that \env{w} will take along the iterations
# 'IW.exp'          : OPTIONAL, only required when \code{use.IW= TRUE} AND \code{IW.type= 'non-linear'}
#                     non-linear modulation index. See Chatterjee and Siarry, 2006. \cr
#                     When \code{IW.type='nparamsetslinear'}, \code{IW.exp} is set to 1.
# 'use.TVc1'        : logical, indicating if the cognitive constant (c1) will have
#                     a time-varying value instead of a constant one provided by the user.
#                     See Ratnaweera et al., 2004
# 'TVc1.type'       : character, required only when \code{use.TVc1 = TRUE}.
#                     Valid values are in: \code{c('linear', 'non-linear', 'GLratio')}
# 'TVc1.rng'        : OPTIONAL, only required when \code{use.TVc1= TRUE & TVc1.type!='GLratio'}
#                     numeric with the initial and final values for the cognitive 
#                     constant \env{[c1.ini, c1.fin]} (in that order) along the iterations
# 'TVc1.exp'        : OPTIONAL, only required when \code{use.TVc1= TRUE} AND ('TVc1.type'= "non-linear"). \cr
#                     non-linear modulation index. When  \code{TVc1.type= 'linear} 
#                     \code{TVc1.exp} is set to 1.   
#                     When \code{TVc1.exp} is equal to 1, \code{TVc1} corresponds 
#                     to the improvement proposed by Ratnaweera et al., 2004,
#                     whereas when \code{TVc1.exp} is different from one, no reference 
#                     has been found in literature by the authors, but it was included 
#                     as an option taking into account the work of Chatterjee and 
#                     Siarry 2006 for the inertia weight.\cr                      
# 'use.TVc2'        : logical, indicating if the social constant (c2) will have
#                     a time-varying value instead of a constant one provided by the user.
#                     See Ratnaweera et al., 2004
# 'TVc2.type'       : character, required only when \code{use.TVc2 = TRUE}.
#                     Valid values are in: \code{c('linear', 'non-linear')}
# 'TVc2.rng'        : OPTIONAL, only required when \code{use.TVc2= TRUE}
#                     numeric with the initial and final values for the social 
#                     constant \env{[c2.ini, c2.fin]} (in that order) 
#                     for \env{c1} along the iterations
# 'TVc2.exp'        : OPTIONAL, only required when \code{use.TVc1= TRUE} AND ('TVc1.type'= "non-linear"). \cr
#                     non-linear modulation index. When  \code{TVc1.type= 'linear} 
#                     \code{TVc1.exp} is set to 1. 
#                     When \code{TVc2.exp} is equal to 1, \code{TVc2} corresponds 
#                     to the improvement proposed by Ratnaweera et al., 2004,
#                     whereas when \code{TVc2.exp} is different from one, no reference 
#                     has been found in literature by the authors, but it was included 
#                     as an option taking into account the work of Chatterjee and 
#                     Siarry 2006 for the inertia weight.\cr  
# 'use.RG'          : logical, indicating if the swarm should be regrouped when 
#                     premature convergence is detected. When \code{use.RG=TRUE} 
#                     the swarm is regrouped in a search space centred about gbest,
#                     which is hoped to be both small enough for efficient search 
#                     and large enough to allow the swarm to escape from stagnation. 
#                     See Evers and Ghalia 2009
# 'RG.thr'          : ONLY required when \code{use.RG=TRUE}. \cr
#                     numeric with a positive value representing the 
#                     \kbd{stagnation threshold}, which is used to decide if the 
#                     swarm has to be regrouped or not. See Evers and Galia 2009 
#                     for further details \cr
#                     Regrouping occurs when the \kbd{normalised swarm radius} 
#                     is less than \code{RG.thr}.                   
# 'RG.r'            : ONLY required when \code{use.RG=TRUE}. \cr
#                     numeric with a positive value representing the 
#                     \kbd{regrouping factor}, which is used to regroup the swarm 
#                     in a search space centred about the global best, which is 
#                     hoped to be both small enough for efficient search and 
#                     large enough to allow the swarm escape from the current well. 
#                     See Evers and Galia 2009 for further details 
# 'RG.miniter'      : ONLY required when \code{use.RG=TRUE}. \cr
#                     numeric with the minimum number of iterations needed before 
#                     regrouping
# 'psoout.drty'     : character, with the name of the directory where the output 
#                     files will be written
# 'use.DS'          : Boolean. It indicates if the solution space will be decreased 
#                     when the particles are stagned around gbest
# 'DS.dmin'         : Real between 0 and 1, indicating the minimum length of 
#                     each dimension accepted by the user. 
#                     Only required when 'use.DS' = TRUE 
# 'DS.tol'          : Real. Tolerance that will be used for deciding when
#                     to decrease the solution space 
#                     It starts when 'gbest.fit.rate' < DS.tol, 
#                     gbest.fit.rate = abs( [gbest.fit(n)-gbest.fit(n-1)/gbest.fit(n) )
#                     Only required when 'use.DS' = TRUE 
# 'DS.r'            : Real between 0 and 1. 
#                     represents the rate that is used for decreasing the 
#                     searching space 
#                     Only required when 'use.DS' = TRUE 
# 'out.with.pbest'  : Logical, indicating if the best parameter values for each 
#                     particle and their fitness has to be included in the output 
#                     of the algorithm 
# 'out.with.fit.iter: Logical,indicating if the fitness of each particle and in 
#                     each iteration has to be included in the output of the algorithm
# 'write2disk'      : Logical, indicating if output files have to be written to
#                     the disk or not  
# 'param.ranges'    : character, with the name of the file that stores the desired 
#                     range of variation for each
# 'verbose'         : logical, should progress messages be printed ?
# 'REPORT'          : OPTIONAL, only used when \code{verbose=TRUE}.
#                     The frequency of report messages printed to the screen. Default
#                     to every 10 iterations

NRELpso <- function(cl=cl,
                    par, 
                    fn=fn,  
                    ...,
                    method=c("spso2011", "spso2007", "ipso", "fips", "wfips", "canonical"),
                    lower=-Inf,
                    upper=Inf,                
                    control=list(),
                    model.FUN=NULL,
                    model.FUN.args=list()
                    ) {

    ########################################################################
    # 0) Checkings and Basic computations - Start                          #
    ########################################################################
    cat("check cluster\n")
    if (is.null(cl)) {print("cluster not initialized");stop}
    
    if (!missing(par)) { 
      if (class(par)=="numeric") {
	n <- length(par)
      } else if ( (class(par)=="matrix") | (class(par)=="data.frame") ) {
	  n <- ncol(par)
	} # ELSE IF end
    } else n <- NULL

    if (missing(fn)) {
      stop("Missing argument: 'fn' must be provided")
    } else 
        if ( is.character(fn) | is.function(fn) )  {
          if (is.character(fn)) {
            fn.name <- fn
	    fn      <- match.fun(fn)
	  } else if (is.function(fn)) {
	      fn.name <- as.character(substitute(fn))
	      fn      <- fn
	    } # ELSE end
        } else stop("Missing argument: 'class(fn)' must be in c('function', 'character')")

    method <- match.arg(method)       

    if (length(lower) != length(upper) )
      stop( "Invalid argument: 'length(lower) != length(upper) (", length(lower), "!=", length(upper), ")'" )

    if (!is.null(n)) {
       if (length(lower) != n)
	 stop( "Invalid argument: 'length(lower) != nparam (", length(lower), "!=", n, ")'" )             
       if (length(upper) != n)
	 stop( "Invalid argument: 'length(upper) != nparam (", length(lower), "!=", n, ")'" )
    } else n <- length(lower)      

    ############################################################################

    con <- list(
	    drty.in="PSO.in",
	    drty.out="PSO.out",
	    param.ranges="ParamRanges.txt",    
	    digits=7,

	    MinMax=c("min", "max"), 
	    npart=NA, 
	    maxit=1000, 
	    maxfn=Inf,
	    c1= 0.5+log(2), 
	    c2= 0.5+log(2), 
	    use.IW= TRUE, IW.w=1/(2*log(2)), IW.type=c("linear", "non-linear", "runif", "aiwf", "GLratio"), IW.exp= 1, 
	    use.CF= FALSE, 
	    lambda= 1,

	    abstol= NULL,    
	    reltol=sqrt(.Machine$double.eps),             
	    Xini.type=c("random", "lhs"),  
	    Vini.type=c(NA, "random2011", "lhs2011", "random2007", "lhs2007",  "zero"), 
	    best.update=c("sync", "async"),
	    random.update=TRUE,
	    boundary.wall=c(NA, "absorbing2011", "absorbing2007", "reflecting", "damping", "invisible"),
	    topology=c("random", "gbest", "lbest", "vonNeumann"), K=3, 
	    iter.ini=0, # only used when 'topology=lbest'   
	    ngbest=4,   # only used when 'method=ipso'   
	    
	    normalise=FALSE,

	    use.TVc1= FALSE, TVc1.rng= c(1.28, 1.05), TVc1.type=c("linear", "non-linear", "GLratio"), TVc1.exp= 1, 
	    use.TVc2= FALSE, TVc2.rng= c(1.05, 1.28), TVc2.type=c("linear", "non-linear"), TVc2.exp= 1, 
	    use.TVlambda=FALSE, TVlambda.rng= c(1, 0.25), TVlambda.type=c("linear", "non-linear"), TVlambda.exp= 1, 
	    use.RG = FALSE, RG.thr= 1.1e-4, RG.r= 0.8, RG.miniter= 5, # RG.r not used in reagrouping
	    
	    plot=FALSE,                
	    out.with.pbest=FALSE,
	    out.with.fit.iter=FALSE,
	    write2disk=TRUE,

	    verbose=TRUE,
	    REPORT=100, 
	    parallel=c("none", "true")
	       )

    MinMax        <- match.arg(control[["MinMax"]], con[["MinMax"]])    
    Xini.type     <- match.arg(control[["Xini.type"]], con[["Xini.type"]])     
    Vini.type     <- match.arg(control[["Vini.type"]], con[["Vini.type"]])     
    Vini.type     <- if (is.na(Vini.type)) { 
                            ifelse(method=="spso2007", "random2007", "random2011")
                     } else Vini.type
    best.update   <- match.arg(control[["best.update"]], con[["best.update"]]) 
    boundary.wall <- match.arg(control[["boundary.wall"]], con[["boundary.wall"]]) 
    boundary.wall <- ifelse(is.na(boundary.wall), 
                            ifelse(method %in% c("spso2007", "canonical"), 
                                   "absorbing2007", "absorbing2011"),
                            boundary.wall)
    topology      <- match.arg(control[["topology"]], con[["topology"]]) 
    IW.type       <- match.arg(control[["IW.type"]], con[["IW.type"]])
    TVc1.type     <- match.arg(control[["TVc1.type"]], con[["TVc1.type"]]) 
    TVc2.type     <- match.arg(control[["TVc2.type"]], con[["TVc2.type"]]) 
    TVlambda.type <- match.arg(control[["TVlambda.type"]], con[["TVlambda.type"]])
    parallel      <- match.arg(control[["parallel"]], con[["parallel"]])    
        	       
    nmsC <- names(con)
    con[(namc <- names(control))] <- control
    if (length(noNms <- namc[!namc %in% nmsC])) 
      warning("[Unknown names in control: ", paste(noNms, collapse = ", "), " (not used) !]")	       

    drty.in           <- con[["drty.in"]]
    drty.out          <- con[["drty.out"]]
    param.ranges      <- con[["param.ranges"]]         
    digits            <- con[["digits"]]                    
    npart             <- ifelse(is.na(con[["npart"]]), 
                                ifelse(method=="spso2007", floor(10+2*sqrt(n)), 40),
                                con[["npart"]] )                                 
    maxit             <- con[["maxit"]] 
    maxfn             <- con[["maxfn"]] 
    c1                <- ifelse(method=="canonical", 2.05, con[["c1"]])
    c2                <- ifelse(method=="canonical", 2.05, con[["c2"]])
    use.IW            <- ifelse(method=="canonical", FALSE, as.logical(con[["use.IW"]]))
    IW.w              <- con[["IW.w"]]
    IW.exp            <- con[["IW.exp"]]
    use.CF            <- ifelse(method=="canonical", TRUE, as.logical(con[["use.CF"]]))
    lambda            <- con[["lambda"]]  
    abstol            <- con[["abstol"]]     
    reltol            <- con[["reltol"]]             
    random.update     <- as.logical(con[["random.update"]])
    K                 <- con[["K"]]      
    iter.ini          <- con[["iter.ini"]]
    ngbest            <- con[["ngbest"]]
    normalise         <- as.logical(con[["normalise"]])             
    use.TVc1          <- as.logical(con[["use.TVc1"]])
    TVc1.rng          <- con[["TVc1.rng"]]
    TVc1.exp          <- con[["TVc1.exp"]]
    use.TVc2          <- as.logical(con[["use.TVc2"]])
    TVc2.rng          <- con[["TVc2.rng"]]
    TVc2.exp          <- con[["TVc2.exp"]]
    use.TVlambda      <- as.logical(con[["use.TVlambda"]])
    TVlambda.rng      <- con[["TVlambda.rng"]]
    TVlambda.exp      <- con[["TVlambda.exp"]]
    use.RG            <- as.logical(con[["use.RG"]])
    RG.thr            <- con[["RG.thr"]]
    RG.r              <- con[["RG.r"]]
    RG.miniter        <- con[["RG.miniter"]]
    plot              <- as.logical(con[["plot"]])            
    out.with.pbest    <- as.logical(con[["out.with.pbest"]])
    out.with.fit.iter <- as.logical(con[["out.with.fit.iter"]])
    write2disk        <- as.logical(con[["write2disk"]])
    verbose           <- as.logical(con[["verbose"]])
    REPORT            <- con[["REPORT"]] 

    ############################################################################
    ######################### Dummy checkings ##################################

    if (maxit < REPORT) {
      REPORT <- maxit
      warning("[ 'REPORT' is greater than 'maxit' => 'REPORT=maxit' ]")
    } # IF end

    if ( (lambda < 0) | (lambda >1) )
      stop("Invalid argument: 'lambda' has to be in [0, 1] !!")

    if ( K > npart ) {
      K <- npart
      warning("[ 'K' is greater than 'npart' => 'K=npart' ]")
    } # IF end

    if ( (K < 1) | (floor(K) != K) ) {
      K <- npart
      stop("'K' must be a positive integer (> 0) !!'")
    } # IF end
    
    if ( ("gof.Ini" %in% names(model.FUN.args)) ) {
      gof.Ini.exists <- TRUE
    } else gof.Ini.exists <- FALSE
    if ( ("gof.Fin" %in% names(model.FUN.args)) ) {
      gof.Fin.exists <- TRUE 
    } else gof.Fin.exists <- FALSE
    if ( ("date.fmt" %in% names(model.FUN.args)) ) {
      date.fmt.exists <- TRUE
    } else date.fmt.exists <- FALSE

    ############################################################################  
    # 1)                              Initialisation                           #
    ###################################################$$$$#####################  
    if (verbose) message("                                                                                ")          
    if (verbose) message("================================================================================")
    if (verbose) message("[                                Initialising  ...                             ]")
    if (verbose) message("================================================================================")
    if (verbose) message("                                                                                ")        

    tmp.stg <- c("npart", "maxit", "method", "topology", "boundary.wall")
    tmp.val <- c(npart, maxit, method, topology, boundary.wall)
    message("[", paste(tmp.stg, tmp.val, collapse = " ; ", sep="="), "]")

    if (length(yesNms <- namc[namc %in% nmsC])) {          
      yesVals <- con[pmatch(namc[namc %in% nmsC], nmsC)][c(yesNms)]
      message("         ")
      message("[ user-definitions in control: ", paste(yesNms, yesVals, collapse = " ; ", sep="="), " ]")
      message("         ")          
    } # IF end

    # checking 'X.Boundaries' 

        if ( (lower[1L] == -Inf) || (upper[1L] == Inf) ) {
          stop( "Invalid argument: 'lower' and 'upper' boundaries must be finite !!'" )
        } else X.Boundaries <- cbind(lower, upper)              


    n <- nrow(X.Boundaries)
    
    if (is.null(rownames(X.Boundaries))) {
      param.IDs <- paste("Param", 1:n, sep="")
    } else param.IDs <- rownames(X.Boundaries)
    
    if (normalise) {
      # Backing up the original boundaries
      lower.ini <- lower
      upper.ini <- upper
      X.Boundaries.ini <- X.Boundaries
      LOWER.ini <- matrix( rep(lower.ini, npart), nrow=npart, byrow=TRUE)
      UPPER.ini <- matrix( rep(upper.ini, npart), nrow=npart, byrow=TRUE)
      
      # normalising
      lower <- rep(0, n)
      upper <- rep(1, n)
      X.Boundaries <- cbind(lower, upper)
      rownames(X.Boundaries) <- param.IDs
    } # IF end

    if (drty.out == basename(drty.out) )
      drty.out <- paste( getwd(), "/", drty.out, sep="")

    if (!file.exists(file.path(drty.out))) {
      if (write2disk) {
	dir.create(file.path(drty.out))
	if (verbose) message("                                            ")
	if (verbose) message("[ Output directory '", basename(drty.out), "' was created on: '", dirname(drty.out), "' ]") 
	if (verbose) message("                                            ")
      } # IF end
    } # IF end  

    if (is.null(abstol)) 
      if (MinMax == "max") {
        abstol <- +Inf
      } else abstol <- -Inf

    if (Xini.type=="lhs") { 
	if ( is.na( match("lhs", installed.packages()[,"Package"] ) ) ) {
	    warning("[ Package 'lhs' is not installed =>  Xini.type='random' ]")
	    Xini.type <- "random"
	}  # IF end  
    } # IF end

    if (Vini.type %in% c("lhs2011", "lhs2007")) { 
	if ( is.na( match("lhs", installed.packages()[,"Package"] ) ) ) {
	    warning("[ Package 'lhs' is not installed =>  Vini.type='random2011' ]")
	    Vini.type <- "random2011"
	}  # IF end  
    } # IF end

    if (use.IW) {
       w <- IW.w   

       if (length(w) == 2) {    
	   w.ini <- w[1] #initial inertial weight at the start of a given run
	   w.fin <- w[2] #final inertial weight at the end of a given run
       } else if (length(w) == 1) {
	      w.ini <- w
	      w.fin <- w
	 } else stop("Invalid argument: 'length(w)' must be 1 or 2 !!")

       if  (IW.type == "linear") {
	   if (IW.exp != 1) {
	     warning("[ IW.type == 'linear' => 'IW.exp=1' ]")
	     IW.exp= 1 
	   } # IF end
       } # IF end                
    } # IF end

    if (use.CF) {
      if (c1+c2 < 4) stop("Invalid argument: 'c1+c2' must be >= 4 when 'use.CF=TRUE'")
      CF <- compute.CF(c1, c2)

      if ( use.TVc1 ) stop("Invalid argument: You can not use 'TVc1' when 'use.CF=TRUE'")
      if ( use.TVc2 ) stop("Invalid argument: You can not use 'TVc2' when 'use.CF=TRUE'")
    } else CF <- 1  

    if ( use.IW & use.CF ) 
      stop("Invalid argument: Inertia Weight and Constriction Factor can not be used simultaneously !!")       

    if (use.TVc1) {         
       c1.ini <- TVc1.rng[1]
       c1.fin <- TVc1.rng[2]                
       if  (TVc1.type == "linear") {
	   if (TVc1.exp != 1) {
	     warning("[ TVc1.type == 'linear' => 'TVc1.exp=1' ]")
	     TVc1.exp= 1 
	   } # IF end
       } # IF end              
    } # IF end

    if (use.TVc2) {      
       c2.ini <- TVc2.rng[1]
       c2.fin <- TVc2.rng[2]                  
       if  (TVc2.type == "linear") {
	   if (TVc2.exp != 1) {
	     warning("[ TVc2.type == 'linear' => 'TVc2.exp=1' ]")
	     TVc2.exp= 1 
	   } # IF end
       } # IF end             
    } # IF end

    if (use.TVlambda) {            
       # Computing ('vmax.ini', 'vmax.fin') 
       vmax.ini <- TVlambda.rng[1]
       vmax.fin <- TVlambda.rng[2]                  
       if  (TVlambda.type == "linear") {
	   if (TVlambda.exp != 1) {
	     warning("[ TVlambda.type == 'linear' => 'TVlambda.exp=1' ]")
	     TVlambda.exp= 1 
	   } # IF end
       } # IF end             
    } # IF end

    if ( (topology == "lbest") | (topology == "random") ) {

       if (topology == "lbest") {
	 if (K != npart) {
	   if ( (trunc((K-1)/2) -(K-1)/2) != 0 )
	       stop("Invalid argument: 'K' must be odd" )
	 } # IF end
       } # IF end
    } else if (topology=="vonNeumann") {
	   topology <- "lbest"
	   if (npart < 5) stop("Invalid argument: for 'vonNeumann' topology 'npart' should be >= 5 !!")
	   if (K != 5) K <- 5
	   } else if (topology == "gbest") {
	       K <- npart  
	     } # ELSE end

    if ( method == "ipso" ) {
       if ( (ngbest < 1) | (ngbest > npart) )
	 stop("Invalid argument: 'ngbest' must be in [1, 'npart]'" )

       if ( topology!="gbest") {
	 if (verbose) warning("[ Note: 'method=ipso' => 'topology' was changed to 'gbest' !]" )
	 topology <- "gbest"
       } # IF end
    } # IF end

    Lmax <- (X.Boundaries[ ,2] - X.Boundaries[ ,1])        
  
    ########################################################################     

    ########################################################################
    # 2) Initialization of Swarm location and velocities                   #
    ########################################################################

    X.Boundaries.current <- X.Boundaries

    Vmax  <- lambda*Lmax

    X <- InitializateX(npart=npart, x.MinMax=X.Boundaries, x.ini.type=Xini.type)
    V <- InitializateV(npart=npart, x.MinMax=X.Boundaries, v.ini.type=Vini.type, 
                       Xini=X)
    V <- t(apply(V, MARGIN=1, FUN=velocity.boundary.treatment, vmax=Vmax))

    if (!missing(par)) {
      if (!any(is.na(par)) && all(par>=lower) && all(par<=upper)) { 
	if (class(par)=="numeric") {
	  X[1,] <- par 
	} else if ( (class(par)=="matrix") | (class(par)=="data.frame") ) {
	  tmp <- ncol(par)
	  if ( tmp != n )
	    stop( "Invalid argument: 'ncol(par) != n' (",tmp, "!=", n, ")" )
	  tmp <- nrow(par)
	  X[1:tmp,] <- par 
	} # ELSE end
      } # IF end  
    } # IF end

    X.best.part <- X

    # Worst possible value defined for the objective function
    if(MinMax == "max") { 
      fn.worst.value <- -.Machine$double.xmax/2
    } else fn.worst.value <- +.Machine$double.xmax/2
                            
    pbest.fit            <- rep(fn.worst.value, npart)     
    pbest.fit.iter       <- fn.worst.value
    pbest.fit.iter.prior <- fn.worst.value*2
			    
    gbest.fit       <- fn.worst.value
    gbest.fit.iter  <- rep(gbest.fit, maxit)
    gbest.fit.prior <- gbest.fit
    gbest.pos       <- 1

    Xt.fitness <- matrix(rep(NA, maxit*npart), ncol=npart, nrow=maxit, byrow=TRUE)       

    if (topology != "random") {
      nc <- K  
      if (trunc(K/2) != ceiling(K/2)) {
        N   <- (K-1)/2
      } else N  <- K/2
      if (trunc(K/2) != ceiling(K/2)) {
        NN  <- 1
      } else NN  <- 0

      X.neighbours <- matrix(rep(-NA, nc*npart), ncol=nc, nrow=npart, byrow=TRUE)
      for ( i in 1:npart) {
	for ( j in -N:N ) {
	  neigh.index <- i + j
	  if ( neigh.index  < 1 )           neigh.index <- npart + neigh.index
	  if ( neigh.index  > npart ) neigh.index <- neigh.index - npart

	  X.neighbours[i,j+N+NN] <- neigh.index
	} # FOR end
      } # FOR end                      
    } # IF end 

    LocalBest.fit <- rep(fn.worst.value, npart)

    LocalBest.pos <- 1:npart

    if ( topology == "ipso") { 
      ngbest.fit <- rep(fn.worst.value, ngbest)

      ngbest.pos <- rep(1, ngbest)
    } else {
	ngbest.fit <- NA           
	ngbest.pos <- NA
      } # ELSE end

    ############################################################################  
    #                          Text Files initialization                       #
    ############################################################################  
    if (write2disk) {

      if (verbose) message("                                                                                ")
      if (verbose) message("================================================================================")
      if (verbose) message("[ Writing the 'PSO_logfile.txt' file ...                                       ]")
      if (verbose) message("================================================================================") 


      PSOparam.fname <- paste(file.path(drty.out), "/", "PSO_logfile.txt", sep="")
      PSOparam.TextFile  <- file(PSOparam.fname , "w+")
      
      writeLines("================================================================================", PSOparam.TextFile)  
      writeLines(c("NRELpso version  :", sessionInfo()$otherPkgs$NRELpso$Version), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines(c("NRELpso Built    :", sessionInfo()$otherPkgs$NRELpso$Built), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines(c("R version         :", sessionInfo()[[1]]$version.string), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Platform          :", sessionInfo()[[1]]$platform), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines("================================================================================", PSOparam.TextFile)  
      Time.Ini <- Sys.time()
      writeLines(c("Starting Time     :", date()), PSOparam.TextFile, sep=" ")
      writeLines("", PSOparam.TextFile) 
      writeLines("================================================================================", PSOparam.TextFile)  
      writeLines(c("Objective Function:", fn.name), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("MinMax            :", MinMax), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Dimension         :", n), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Nmbr of Particles :", npart), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Max Iterations    :", maxit), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Method            :", method), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      if ( method == "ipso" ) {
	writeLines(c("ngbest           :", ngbest), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile)  
      } # IF end
      writeLines(c("Topology          :", topology), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile)  
      if ( (topology == "lbest") | (topology == "random") ) {
	writeLines(c("K                 :", K), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile)  
	writeLines(c("iter.ini          :", iter.ini), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile)  
      } # IF end
      writeLines(c("Boundary wall     :", boundary.wall), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("normalise         :", normalise), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Xini.type         :", Xini.type), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Vini.type         :", Vini.type), PSOparam.TextFile, sep=" ")
      writeLines("", PSOparam.TextFile)  
      writeLines(c("Best update method:", best.update), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Random update     :", random.update), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      if (use.TVc1) {
	writeLines(c("use.TVc1          :", use.TVc1), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVc1.rng          :", TVc1.rng), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVc1.type         :", TVc1.type), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVc1.exp          :", TVc1.exp), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
      } else {
        writeLines(c("c1                :", c1), PSOparam.TextFile, sep=" ") 
        writeLines("", PSOparam.TextFile) 
      } # ELSE end
      if (use.TVc2) {
	writeLines(c("use.TVc2          :", use.TVc2), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVc2.rng          :", TVc2.rng), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVc2.type         :", TVc2.type), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVc2.exp          :", TVc2.exp), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
      } else {
        writeLines(c("c2                :", c2), PSOparam.TextFile, sep=" ") 
        writeLines("", PSOparam.TextFile) 
      } # ELSE end 
      writeLines(c("use.IW            :", use.IW), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      if (use.IW) {
	writeLines(c("IW.w              :", IW.w), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	if ( length(IW.w) > 1 ) {
  	  writeLines(c("IW.type           :", IW.type), PSOparam.TextFile, sep=" ") 
	  writeLines("", PSOparam.TextFile) 
	  writeLines(c("IW.exp            :", IW.exp), PSOparam.TextFile, sep=" ") 
	  writeLines("", PSOparam.TextFile) 
	} # IF end
      }  # IF end
      if (use.TVlambda) {
	writeLines(c("use.TVlambda      :", use.TVlambda), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVlambda.rng      :", TVlambda.rng), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVlambda.type     :", TVlambda.type), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("TVlambda.exp      :", TVlambda.exp), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
      } else {
        writeLines(c("lambda            :", lambda), PSOparam.TextFile, sep=" ") 
        writeLines("", PSOparam.TextFile)   
      }  # ELSE end
      writeLines(c("use.RG            :", use.RG), PSOparam.TextFile, sep=" ") 
      writeLines("", PSOparam.TextFile) 
      if (use.RG) {
        writeLines(c("RG.thr            :", RG.thr), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("RG.r              :", RG.r), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 
	writeLines(c("RG.miniter        :", RG.miniter), PSOparam.TextFile, sep=" ") 
	writeLines("", PSOparam.TextFile) 	
      }  # IF end
      writeLines(c("maxfn             :", maxfn), PSOparam.TextFile, sep=" ")  
      writeLines("", PSOparam.TextFile) 
      writeLines(c("abstol            :", abstol), PSOparam.TextFile, sep=" ")  
      writeLines("", PSOparam.TextFile) 
      writeLines(c("reltol            :", reltol), PSOparam.TextFile, sep=" ")  
      writeLines("", PSOparam.TextFile)       
      writeLines(c("parallel          :", parallel), PSOparam.TextFile, sep=" ")  
      writeLines("", PSOparam.TextFile)  
      close(PSOparam.TextFile) 

      # File 'Model_out.txt' #
      OFout.Text.fname <- paste(file.path(drty.out), "/", "Model_out.txt", sep="")
      OFout.Text.file  <- file(OFout.Text.fname, "w+")
      
      writeLines(c("Iter", "Part", "GoF", "Model_Output"), OFout.Text.file, sep="  ") 
      writeLines("", OFout.Text.file) 
      close(OFout.Text.file) 

      # File 'Particles.txt' #
      Particles.Textfname <- paste(file.path(drty.out), "/", "Particles.txt", sep="")
      Particles.TextFile  <- file(Particles.Textfname, "w+")
      
      writeLines(c("Iter", "Part", "GoF", param.IDs), Particles.TextFile, sep=" ") 
      writeLines("", Particles.TextFile) 
      close(Particles.TextFile) 

      # File 'Velocities.txt' #
      Velocities.Textfname <- paste(file.path(drty.out), "/", "Velocities.txt", sep="")
      Velocities.TextFile  <- file(Velocities.Textfname, "w+")
      
      writeLines(c("Iter", "Part", "GoF", param.IDs), Velocities.TextFile, sep=" ") 
      writeLines("", Velocities.TextFile) 
      close(Velocities.TextFile) 

      # File 'ConvergenceMeasures.txt' #
      ConvergenceMeasures.Textfname <- paste(file.path(drty.out), "/", "ConvergenceMeasures.txt", sep="")
      ConvergenceMeasures.TextFile  <- file(ConvergenceMeasures.Textfname, "w+")
      
      writeLines(c("Iter", "Gbest", "GbestRate[%]", "IterBestFit", "normSwarmRadius", "|gbest-mean(pbest)|/mean(pbest)[%]"), ConvergenceMeasures.TextFile, sep=" ") 
      writeLines("", ConvergenceMeasures.TextFile) 
      close(ConvergenceMeasures.TextFile)   

      # File 'BestParamPerIter.txt' #
      BestParamPerIter.Textfname <- paste(file.path(drty.out), "/", "BestParamPerIter.txt", sep="")
      BestParamPerIter.TextFile  <- file(BestParamPerIter.Textfname, "w+")
      
      writeLines(c("Iter", "GoF", param.IDs), BestParamPerIter.TextFile, sep="  ") 
      writeLines("", BestParamPerIter.TextFile) 
      close(BestParamPerIter.TextFile) 
      
      # File 'PbestPerIter.txt' #
      PbestPerIter.Textfname <- paste(file.path(drty.out), "/", "PbestPerIter.txt", sep="")
      PbestPerIter.TextFile  <- file(PbestPerIter.Textfname, "w+")
      
      writeLines(c("Iter", paste("Part", 1:npart, sep="") ), PbestPerIter.TextFile, sep="  ") 
      writeLines("", PbestPerIter.TextFile) 
      close(PbestPerIter.TextFile) 
      
      # File 'LocalBestPerIter.txt' #
      LocalBestPerIter.Textfname <- paste(file.path(drty.out), "/", "LocalBestPerIter.txt", sep="")
      LocalBestPerIter.TextFile  <- file(LocalBestPerIter.Textfname, "w+")
      
      writeLines(c("Iter", paste("Part", 1:npart, sep="") ), LocalBestPerIter.TextFile, sep="  ") 
      writeLines("", LocalBestPerIter.TextFile) 
      close(LocalBestPerIter.TextFile) 

      if (use.RG) {
	# File 'Xmin.txt' #
	Xmin.Text.fname <- paste(file.path(drty.out), "/", "Xmin.txt", sep="")
	Xmin.Text.file  <- file(Xmin.Text.fname, "w+")
	
	writeLines(c("Iter", param.IDs), Xmin.Text.file, sep="  ") 
	writeLines("", Xmin.Text.file) 
	writeLines(as.character(c(1, X.Boundaries[,1])), Xmin.Text.file, sep=" ")
	writeLines("", Xmin.Text.file) 
	close(Xmin.Text.file)     

	# File 'Xmax.txt' #
	Xmax.Text.fname <- paste(file.path(drty.out), "/", "Xmax.txt", sep="")
	Xmax.Text.file  <- file(Xmax.Text.fname, "w+")
	
	writeLines(c("Iter", param.IDs ), Xmax.Text.file, sep="  ")
	writeLines("", Xmax.Text.file)  
	writeLines(as.character(c(1, X.Boundaries[,2])), Xmax.Text.file, sep=" ")
	writeLines("", Xmax.Text.file) 
	close(Xmax.Text.file)      
      } # IF end  

    } # IF 'write2disk' end

    ########################################################################
    GPbest.fit.rate <- Inf

    iter     <- 1
    nfn      <- 1
    nfn.eff  <- 1
    iter.rg  <- 1
    nregroup <- 0

    iter.tv  <- iter
    niter.tv <- maxit

    if (write2disk) {
      OFout.Text.file              <- file(OFout.Text.fname, "a")           
      Particles.TextFile           <- file(Particles.Textfname, "a")  
      Velocities.TextFile          <- file(Velocities.Textfname, "a") 
      ConvergenceMeasures.TextFile <- file(ConvergenceMeasures.Textfname, "a")   
      BestParamPerIter.TextFile    <- file(BestParamPerIter.Textfname, "a")
      PbestPerIter.TextFile        <- file(PbestPerIter.Textfname, "a") 
      LocalBestPerIter.TextFile    <- file(LocalBestPerIter.Textfname, "a") 
      if (use.RG) {
	Xmin.Text.file <- file(Xmin.Text.fname, "a")        
	Xmax.Text.file <- file(Xmax.Text.fname, "a")
      } # IF end
    } # IF end      

    ######################### START Main Iteration Loop ########################
    abstol.conv <- FALSE
    reltol.conv <- FALSE
    improvement <- FALSE

    end.type.stg  <- "Unknown"
    end.type.code <- "-999"

    ############################################################################  
    # 3)                              Main Algorithm                           #
    ############################################################################  
    if (verbose) message("                                                                                ")          
    if (verbose) message("================================================================================")
    if (verbose) message("[                                 Running  PSO ...                             ]")
    if (verbose) message("================================================================================")
    if (verbose) message("                                                                                ")        

    while ( (iter <= maxit)  && (!abstol.conv) && (!reltol.conv) && (nfn.eff <= maxfn) ) { 

      if ( (topology=="random") & (!improvement) ) 
	X.neighbours <- Random.Topology.Generation(npart, K, drty.out, iter)
	
      ModelOut <- vector("list", npart)
      
      # IW: linear, non-linear, runif
      if (!use.IW) {
         w <- 1   
      } else {                   
	   if ( (IW.type == "linear") | (IW.type == "non-linear") ) {
	      w <- compute.value.with.iter(iter=iter.tv, niter=niter.tv, 
					   nexp=IW.exp, val.ini=w.ini, 
					   val.fin=w.fin)                   
	   } else if (IW.type == "runif") {
	       w <- runif(1, min=w.ini, max=w.fin)
             } # ELSE end
	} # ELSE end 

        # TVc1: linear, non-linear
	if ( (use.TVc1) & (TVc1.type != "GLratio") ) {
	  if ( (TVc1.type == "linear") | (TVc1.type == "non-linear") )
	     c1 <- compute.value.with.iter(iter=iter.tv, niter=niter.tv, 
					   nexp=TVc1.exp, val.ini=c1.ini, 
					   val.fin=c1.fin)  
	} # If end  

        # TVc2
	if (use.TVc2) 
	  c2 <- compute.value.with.iter(iter=iter.tv, niter=niter.tv, 
					nexp=TVc2.exp, val.ini=c2.ini, 
					val.fin=c2.fin)  
					
        # lambda
	if (use.TVlambda) {
	  lambda <- compute.value.with.iter(iter=iter.tv, niter=niter.tv, 
					    nexp=TVlambda.exp, val.ini=vmax.ini, 
					    val.fin=vmax.fin)  
	  Vmax   <- lambda*Lmax
	} # IF end  

      ##########################################################################  
      
      if (normalise) {
        Xn <- X * (UPPER.ini - LOWER.ini) + LOWER.ini
        Vn <- V * (UPPER.ini - LOWER.ini) + LOWER.ini
      } else {
          Xn <- X
          Vn <- V
        } # ELSE end

      # 3.a) Evaluate the particles fitness
         
         # Evaluating an R Function 
         if (parallel=="none") {
           GoF <- apply(Xn, fn, MARGIN=1, ...)
         } else {
           GoF <- parRapplyLB(cl= cl, x=Xn, FUN=fn, ...)
         } # ELSE end
	 
         Xt.fitness[iter, 1:npart] <- GoF
         ModelOut[1:npart]         <- GoF  ###

	 nfn     <- nfn + npart
	 nfn.eff <- nfn.eff + npart

      if ( best.update == "sync" ) {
	    tmp <- sync.update.pgbests(x=X, 
				       xt.fitness= Xt.fitness[iter, ], 
				       MinMax= MinMax, 
				       pbest.fit= pbest.fit, 
				       gbest.fit= gbest.fit, 
				       gbest.pos= gbest.pos, 
				       x.best= X.best.part
				       )                               

	    pbest.fit   <- tmp[["pbest"]]
	    X.best.part <- tmp[["x.best"]]
	    gbest.fit   <- tmp[["gbest.fit"]]
	    gbest.pos   <- tmp[["gbest.pos"]]
	    
	    tmp <- UpdateLocalBest(pbest.fit=pbest.fit, 
			     localBest.pos=LocalBest.pos,
			     localBest.fit=LocalBest.fit, 
			     x.neighbours=X.neighbours, 
			     MinMax=MinMax) 
            LocalBest.fit <- tmp[["localBest.fit"]]
            LocalBest.pos <- tmp[["localBest.pos"]]

            if ( method == "ipso" ) {
               tmp <- UpdateNgbest(pbest.fit=pbest.fit, 
        	                   ngbest=ngbest, 
        			   MinMax=MinMax) 
               ngbest.fit <- tmp[["ngbest.fit"]]
               ngbest.pos <- tmp[["ngbest.pos"]]
            } # IF end

      } # IF end 
      
      # 'X.bak' is only needed to correctly compute the Normalised Swarm Radius
      # for the current iteration
      X.bak <- X           

      ##########################################################################  
      ###################   Particles Loop (j) - Start  ########################
      ##########################################################################  
      
      if ( (best.update == "async") & random.update) { 
	index.part.upd <- sample(npart)
      } else index.part.upd <- 1:npart
        
      for (j in index.part.upd) {
      
        if (write2disk) {
        
          GoF <- Xt.fitness[iter, j]
        
          # File 'Model_Out.txt'          
          if(is.finite(GoF)) {
             suppressWarnings(
             writeLines(as.character(c(iter, j, 
				       formatC(GoF, format="E", digits=digits, flag=" "), 
				       formatC(ModelOut[[j]], format="E", digits=digits, flag=" ") ) ), 
			OFout.Text.file, sep="  ")
             ) 
          } else writeLines(as.character(c(iter, j, "NA", "NA" ) ), OFout.Text.file, sep="  ")
	  writeLines("", OFout.Text.file) 
	  flush(OFout.Text.file)
          
          # File 'Particles.txt' #
	  if(is.finite(GoF)) {
            suppressWarnings(
	    writeLines(as.character( c(iter, j, 
				     formatC(GoF, format="E", digits=digits, flag=" "), #GoF
				     formatC(Xn[j, ], format="E", digits=digits, flag=" ") 
				      ) ), Particles.TextFile, sep="  ") 
            )
	  } else suppressWarnings( writeLines(as.character( c(iter, j, "NA",
					  formatC(Xn[j, ], format="E", digits=digits, flag=" ") 
				      ) ), Particles.TextFile, sep="  ") 
                                 )
	  writeLines("", Particles.TextFile)
	  flush(Particles.TextFile)
        
	  # File 'Velocities.txt' #
	  if(is.finite(GoF)) {
            suppressWarnings(
	    writeLines( as.character( c(iter, j, 
					formatC(GoF, format="E", digits=digits, flag=" "), # GoF
					formatC(Vn[j, ], format="E", digits=digits, flag=" ")                                            
					) ), Velocities.TextFile, sep="  ") 
            )
	  } else suppressWarnings( writeLines( as.character( c(iter, j, "NA",
					formatC(Vn[j, ], format="E", digits=digits, flag=" ")                                            
					) ), Velocities.TextFile, sep="  ")
                                 )
	  writeLines("", Velocities.TextFile) 
	  flush(Velocities.TextFile)
	  
        } # IF end
	    

	if ( best.update == "async" ) {
	   tmp <- async.update.pgbests(x=X[j,], 
	                               x.pos=j, 
                                       xt.fitness= Xt.fitness[iter, j],
                                       MinMax= MinMax, 
                                       l.pbest.fit= pbest.fit[j], 
                                       gbest.fit= gbest.fit, 
                                       gbest.pos= gbest.pos,
                                       x.best= X.best.part[j, ]
	                               )                                    

	   pbest.fit[j]    <- tmp[["pbest"]]
	   X.best.part[j,] <- tmp[["x.best"]]       
	   gbest.pos       <- tmp[["gbest.pos"]] 
	   gbest.fit       <- tmp[["gbest.fit"]] 
	   
	   tmp <- UpdateLocalBest(pbest.fit=pbest.fit, 
			     localBest.pos=LocalBest.pos,
			     localBest.fit=LocalBest.fit, 
			     x.neighbours=X.neighbours, 
			     MinMax=MinMax) 
           LocalBest.fit <- tmp[["localBest.fit"]]
           LocalBest.pos <- tmp[["localBest.pos"]]

           if ( method == "ipso" ) {
              tmp <- UpdateNgbest(pbest.fit=pbest.fit, 
                                  ngbest=ngbest, 
                                  MinMax=MinMax) 
              ngbest.fit <- tmp[["ngbest.fit"]]
              ngbest.pos <- tmp[["ngbest.pos"]]
           } # IF end

	} # IF end  
	
	### IW, TVc1, Tv2, lambda
	
	# IW: aiwf, GLratio
	if (use.IW) { 
	  if (IW.type == "aiwf") { 
	        w <- compute.w.aiwf(iter.fit= Xt.fitness[iter, ],
                                    particle.pos =j, 
                                    gbest.fit=gbest.fit, 
                                    w.max=max(w.ini, w.fin), 
                                    w.min=min(w.ini, w.fin),
                                    MinMax=MinMax
                                    )   

	  } else if (IW.type == "GLratio") {
		w <- compute.w.with.GLratio(MinMax, gbest.fit, pbest.fit)   
	    }  # ELSE end
	} # IF end
	
	
	# TVc1: GLratio
	if ( (use.TVc1) & (TVc1.type == "GLratio") ) 
           c1 <- compute.c1.with.GLratio(MinMax, gbest.fit, pbest.fit[j])   

	######################################################################## 
	# 3.b) Updating the velocity of all the particles
	if ( (topology=="lbest") & (iter <= iter.ini) ) {
          ltopology <- "gbest"
        } else ltopology <- topology
        
	V[j,] <- compute.veloc( 
				x= X[j, ], 
				v= V[j, ], 
				w= w, 
				c1= c1, 
				c2= c2, 
				CF= CF,
				Pbest= X.best.part,
				part.index=j,
				gbest= X.best.part[gbest.pos, ],
				topology=ltopology,
				method=method,                                    
				MinMax=MinMax,                             # topology="ipso" | method="wfips"
				neighs.index=X.neighbours[j, ],            # method in c("fips", "wfips")
				localBest=X.best.part[LocalBest.pos[j], ], # topology=c("random", "lbest")
				localBest.pos=LocalBest.pos[j],            # topology=c("random", "lbest")
				ngbest.fit=ngbest.fit,                     # topology="ipso"
				ngbest=X.best.part[ngbest.pos, ],          # topology="ipso"
				lpbest.fit= pbest.fit[X.neighbours[j, ]]   # method="wfips"
				)  
        
	V[j,] <- velocity.boundary.treatment(v= V[j,], vmax=Vmax)

        ########################################################################  
	# 4.c) Moving the particles: X[j,] <- X[j,] +  V[j,]
	out <- position.update.and.boundary.treatment(x= X[j,], v=V[j,], x.MinMax=X.Boundaries, boundary.wall=boundary.wall)
	X[j,] <- out[["x.new"]]
	V[j,] <- out[["v.new"]]

      } # FOR j end: Particles Loop
      ##########################################################################  
      ###################   Particles Loop (j) - End  ##########################
      ########################################################################## 
       
      if ( plot ) {
	if (MinMax == "max") {
          lgof <- max(GoF, na.rm=TRUE)
        } else lgof <- min(GoF, na.rm=TRUE)
	colorRamp= colorRampPalette(c("darkred", "red", "orange", "yellow", "green", "darkgreen", "cyan"))
	XX.Boundaries.current <- computeCurrentXmaxMin(X) 
	xlim <- range(XX.Boundaries.current)
	ylim <- range(XX.Boundaries.current)
	if (iter==1) {
	   plot(X[,1], X[,2], xlim=X.Boundaries[1,], ylim=X.Boundaries[2,], 
	        main=paste("Iter= ", iter, ". GoF= ", 
	        format(lgof, scientific=TRUE, digits=digits), sep=""), 
	        col=colorRamp(npart), cex=0.5 )
	} else plot(X[,1], X[,2], xlim=X.Boundaries[1,], ylim=X.Boundaries[2,], 
	            main=paste("Iter= ", iter, ". GoF= ", 
	            format(lgof, scientific=TRUE, digits=digits), sep=""), 
	            col=colorRamp(npart), cex=0.5 )
	#plotParticles2D(X)
      } # IF end 
      
      gbest.fit.iter[iter] <- gbest.fit
      
      suppressWarnings(if (MinMax=="max") {
                           pbest.fit.iter <- max( Xt.fitness[iter, ], na.rm=TRUE )
                       } else pbest.fit.iter <- min( Xt.fitness[iter, ], na.rm=TRUE)
                      )  

      GPbest.fit.rate <- mean(pbest.fit, na.rm=TRUE)
      if ( (is.finite(GPbest.fit.rate) ) & ( GPbest.fit.rate !=0 ) ) { 
	GPbest.fit.rate <- abs( ( gbest.fit - GPbest.fit.rate ) / GPbest.fit.rate )
      } else GPbest.fit.rate <- +Inf

      if ( (gbest.fit.prior != 0) & (is.finite(gbest.fit.prior) ) ) { 
	gbest.fit.rate <- abs( ( gbest.fit - gbest.fit.prior ) / gbest.fit.prior )
      } else gbest.fit.rate <- +Inf

      out <- ComputeSwarmRadiusAndDiameter(x=X.bak, gbest= X.best.part[gbest.pos, ], Lmax=Lmax) 
      swarm.radius    <- out[["swarm.radius"]] 
      swarm.diameter  <- out[["swarm.diameter"]]
      NormSwarmRadius <- swarm.radius/swarm.diameter

      if ( (verbose) & ( iter/REPORT == floor(iter/REPORT) ) ) 
           suppressWarnings(
	   message( "iter:", format(iter, width=nchar(maxit), justify="right"), 
		    "  Gbest:", formatC( gbest.fit, format="E", digits=3, flag=" "), 
		    "  Gbest_rate:", format( round(gbest.fit.rate*100, 2), width=6, nsmall=2, justify="left"), "%",
		    "  Iter_best_fit:", formatC(pbest.fit.iter, format="E", digits=3, flag=" "),               
		    "  nSwarm_Radius:", formatC(NormSwarmRadius, format="E", digits=2, flag=" "),
		    "  |g-mean(p)|/mean(p):", format( round(GPbest.fit.rate*100, 2), width=6, nsmall=2, justify="left"), "%" )
           )

      ##########################################################################  
      # Random Generation around gbest, if requested                           #
      ##########################################################################  
      do.RandomGeneration <- ( use.RG && (NormSwarmRadius < RG.thr)  
				      && (iter.rg >= RG.miniter) )

      if (do.RandomGeneration)  {        

	  if (topology!="ipso") {
	    x.bak         <- X[gbest.pos,]
	    v.bak         <- V[gbest.pos,]
	    gbest.fit.bak <- gbest.fit
	    gbest.pos.bak <- gbest.pos	                    
	  } # IF end

	  if (topology == "ipso") {
	   x.bak         <- X[ngbest.pos,]
	   v.bak         <- V[ngbest.pos,]
	   gbest.fit.bak <- gbest.fit
           gbest.pos.bak <- gbest.pos	
	   ngbest.fit.bak <- ngbest.fit
	   ngbest.pos.bak <- ngbest.pos	  
	  } # IF end

	  if (verbose) message("[ Re-grouping particles in the swarm (iter: ", iter, ") ... ]")

	  tmp <- RegroupingSwarm(x=X, 
				 xini.type=Xini.type, 
                                 v=V, 
                                 vini.type=Vini.type,                            
	                         gbest= X.best.part[gbest.pos, ], 
				 x.Range=X.Boundaries,
				 #x.Range=X.Boundaries.current,
				 Lmax=Lmax,
				 RG.thr=RG.thr,
				 RG.r=RG.r) 

	  X <- tmp[["X"]]
	  V <- tmp[["V"]]
	  
	  Lmax <- tmp[["RangeNew"]]

	  if (topology == "ipso") {
	    X[ngbest.pos,] <- x.bak
	    gbest.fit      <- gbest.fit.bak
	    gbest.pos      <- gbest.pos.bak
	  } # IF end

          pbest.fit            <- rep(fn.worst.value, npart)     
          pbest.fit.iter       <- fn.worst.value
          pbest.fit.iter.prior <- fn.worst.value*2
			    
          gbest.fit       <- fn.worst.value
          gbest.fit.iter  <- rep(gbest.fit, maxit)
          gbest.fit.prior <- gbest.fit
          gbest.pos       <- 1
                  
          gbest.fit     <- gbest.fit.bak
          gbest.pos     <- gbest.pos.bak
          X[gbest.pos,] <- x.bak

	  GPbest.fit.rate <- +Inf              
	  if (MinMax=="max") {
            gbest.fit.prior <- +Inf
          } else gbest.fit.prior <- 0

	  niter.tv <- maxit - iter
	  iter.tv  <- 1   
	  iter.rg  <- 1   
	  nregroup <- nregroup + 1

      } # IF end

      ##########################################################################  
      # Updates required before the next iteration
      ##########################################################################  

      if (MinMax=="max") {
        abstol.conv <- gbest.fit >= abstol
      } else abstol.conv <- gbest.fit <= abstol
                     
      if (reltol==0) {
        reltol.conv <- FALSE
      } else {
        tmp <- abs(pbest.fit.iter.prior - pbest.fit.iter)
        if (tmp==0) {
          reltol.conv <- FALSE
        } else reltol.conv <- tmp <= abs(reltol)
      } # ELSE end
                     
      pbest.fit.iter.prior <- pbest.fit.iter

      # Gbest was improved ?
      if (gbest.fit.prior==gbest.fit) {
        improvement <- FALSE
      } else improvement <- TRUE

      gbest.fit.prior <- gbest.fit
            

      if (abstol.conv ) {
	end.type.stg  <- "Converged ('abstol' criterion)"
	end.type.code <- 0
      } else if (reltol.conv) {
	end.type.stg <- "Converged ('reltol' criterion)"
	end.type.code <- 1
      } else if (nfn.eff >= maxfn) {
	end.type.stg <- "Maximum number of function evaluations reached"
	end.type.code <- 2
      } else if (iter >= maxit) {
	end.type.stg <- "Maximum number of iterations reached"
	end.type.code <- 3
      } # ELSE end

      if (write2disk) {
      
        # File 'ConvergenceMeasures.txt'
        suppressWarnings(
	writeLines(as.character( c(iter, 
				   formatC(gbest.fit, format="E", digits=digits, flag=" "), 
				   format( round(gbest.fit.rate*100, 3), nsmall=3, width=7, justify="right"),
				   formatC(pbest.fit.iter, format="E", digits=digits, flag=" "),
				   formatC(NormSwarmRadius, format="E", digits=digits, flag=" "),
				   format( round(GPbest.fit.rate*100, 3), nsmall=3, width=7, justify="right")
				  ) ), ConvergenceMeasures.TextFile, sep="  ")
        )
	writeLines("", ConvergenceMeasures.TextFile)
	flush(ConvergenceMeasures.TextFile) 
        
        # File 'BestParamPerIter.txt' #
        if (normalise) {
          temp <- X.best.part[gbest.pos, ] * (upper.ini - lower.ini) + lower.ini
        } else temp <- X.best.part[gbest.pos, ]
        GoF <- gbest.fit
	if(is.finite(GoF)) {	                    
	  suppressWarnings( writeLines( as.character( c(iter,
	                              formatC(GoF, format="E", digits=digits, flag=" "), 
	                              formatC(temp, format="E", digits=digits, flag=" ")	                                                            
	                          ) ), BestParamPerIter.TextFile, sep="  ") 
                           )
	} else suppressWarnings( writeLines( as.character( c(iter,
	                                   "NA",
	                                   formatC(temp, format="E", digits=digits, flag=" ")                                                                                  
	                               ) ), BestParamPerIter.TextFile, sep="  ")
                               )
	writeLines("", BestParamPerIter.TextFile)  
	flush(BestParamPerIter.TextFile)
	
	# File 'PbestPerIter.txt' #
        GoF <- pbest.fit
        suppressWarnings(
	writeLines( as.character( c(iter,
	                            formatC(GoF, format="E", digits=digits, flag=" ") 
	                           ) ), PbestPerIter.TextFile, sep="  ")
        )
	writeLines("", PbestPerIter.TextFile)  
	flush(PbestPerIter.TextFile)
	
	# File 'LocalBestPerIter.txt' #
        GoF <- LocalBest.fit
        suppressWarnings(
	writeLines( as.character( c(iter,
	                            formatC(GoF, format="E", digits=digits, flag=" ") 
	                           ) ), LocalBestPerIter.TextFile, sep="  ")
        )
	writeLines("", LocalBestPerIter.TextFile)  
	flush(LocalBestPerIter.TextFile)
	
      } # IF end

      iter    <- iter + 1
      iter.tv <- iter.tv + 1
      iter.rg <- iter.rg + 1

    } # WHILE end
    ########################## END Main Iteration Loop #########################
    
    if (normalise) X.best.part <- X.best.part * (UPPER.ini - LOWER.ini) + LOWER.ini

    if (write2disk) {
      close(OFout.Text.file)        
      close(Particles.TextFile)
      close(Velocities.TextFile)
      close(ConvergenceMeasures.TextFile)
      close(BestParamPerIter.TextFile)
      close(PbestPerIter.TextFile) 
      close(LocalBestPerIter.TextFile)
      if (use.RG) {
	close(Xmin.Text.file)        
	close(Xmax.Text.file)
      } # IF end
    } # IF end

    ############################################################################  
    # Sorting the particles according to their best fit
    ############################################################################  
    if (MinMax=="max") {
      sorted.fit <- sort(pbest.fit, decreasing= TRUE)
    } else sorted.fit <- sort(pbest.fit, decreasing= FALSE)

    sorted.index <- pmatch(sorted.fit, pbest.fit)

    ###################   START WRITING OUTPUT FILES     ###################
    if (write2disk) {

      if (verbose) message("                           ")
      if (verbose) message("[ Writing output files... ]")
      if (verbose) message("                           ")

      niter.real <- iter - 1 

      PSOparam.TextFile <- file(PSOparam.fname, "a")    
      
      writeLines("================================================================================", PSOparam.TextFile) 
      writeLines(c("Total fn calls    :", nfn-1), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Nmbr of Iterations:", iter-1), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines(c("Regroupings       :", nregroup), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines("================================================================================", PSOparam.TextFile) 
      writeLines(c("Ending Time       :", date()), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      Time.Fin <- Sys.time()
      writeLines("================================================================================", PSOparam.TextFile) 
      writeLines(c("Elapsed Time      :", format(round(Time.Fin - Time.Ini, 2))), PSOparam.TextFile, sep="  ")
      writeLines("", PSOparam.TextFile) 
      writeLines("================================================================================", PSOparam.TextFile) 
      close(PSOparam.TextFile)

      # Writing the file 'BestParameterSet.txt'
      tmp.fname <- paste(file.path(drty.out), "/", "BestParameterSet.txt", sep="") 
      tmp.TextFile  <- file(tmp.fname , "w+")
      writeLines(c("BestParticle", "GoF   ", param.IDs), tmp.TextFile, sep="  ") 
      writeLines("", tmp.TextFile)  
      suppressWarnings( tmp <- formatC(c(gbest.fit, X.best.part[gbest.pos,]), format="E", digits=digits, flag=" ") )
      writeLines(as.character(c(gbest.pos, tmp)), tmp.TextFile, sep="  ") 
      writeLines("", tmp.TextFile)  
      close(tmp.TextFile) 

      # Writing the file 'XMinMax.txt' with the parameter ranges used during PSO
      fname <- paste(file.path(drty.out), "/", "XMinMax.txt", sep="") 	
      ifelse(normalise, tmp <- X.Boundaries.ini, tmp <- X.Boundaries)				
      write.table(format(tmp, scientific=TRUE, digits=digits), file=fname, col.names=TRUE, row.names=TRUE, sep="  ", quote=FALSE) 

      # Writing the file 'Particles_GofPerIter.txt', with the GoF for each particle in each iteration
      tmp.fname <- paste(file.path(drty.out), "/", "Particles_GofPerIter.txt", sep="") 
      tmp.TextFile  <- file(tmp.fname , "w+")
      writeLines(paste("Iter", paste("Part", 1:npart, collapse="    ", sep=""), sep="    "), tmp.TextFile, sep="  ") 
      writeLines("", tmp.TextFile)  
      for ( i in (1:niter.real) ) {               
	suppressWarnings( tmp <- formatC(Xt.fitness[i, ], format="E", digits=digits, flag=" ") )
	writeLines(as.character(c(i, tmp)), tmp.TextFile, sep="  ") 
	writeLines("", tmp.TextFile)    
      } # FOR end 
      close(tmp.TextFile) 

      # Writing the file 'BestParamPerParticle.txt', with ...
      fname <- paste(file.path(drty.out), "/", "BestParamPerParticle.txt", sep="") 
      tmp <- cbind(pbest.fit, X.best.part)
      colnames(tmp) <- c("GoF", param.IDs)
      write.table(format(tmp, scientific=TRUE, digits=digits), file=fname, col.names=TRUE, row.names=FALSE, sep="  ", quote=FALSE)

      # Writing the file 'X.neighbours.txt' 
      fname <- paste(file.path(drty.out), "/", "Particles_Neighbours.txt", sep="") 
      ifelse(topology == "lbest", nc <- K, nc <- npart)
      write.table(X.neighbours, file=fname, col.names=paste("Neigh", 1:nc, sep=""), row.names=paste("Part", 1:npart, sep=""), sep="  ", na="", quote=FALSE) 

      # Writing the file 'LocalBest.txt' 
      fname <- paste(file.path(drty.out), "/", "LocalBest.txt", sep="") 	
      write.table(format(LocalBest.fit, scientific=TRUE, digits=digits), file=fname, col.names=TRUE, row.names=FALSE, sep="  ", quote=FALSE)
      
    } # IF end

    #####################     END WRITING OUTPUT FILES     #####################

    ############################################################################
    if (verbose) message("                                    |                                           ")  
    if (verbose) message("================================================================================")
    if (verbose) message("[                          Creating the R output ...                           ]")
    if (verbose) message("================================================================================")

    # Creating the R output
    nelements <- 6 
    out       <- vector("list", nelements)

    out[[1]]        <- X.best.part[gbest.pos,]
    names(out[[1]]) <- param.IDs
    out[[2]] <- gbest.fit
    out[[3]] <- gbest.pos
    out[[4]] <- c("function.calls"=nfn-1, "iterations"=iter-1, "regroupings"=nregroup)
    out[[5]] <- end.type.code
    out[[6]] <- end.type.stg

    names(out)[1:nelements] <- c("par",           # "Best.Parameter.Values", 
				 "value",         # "Global.Best.Value", 
				 "best.particle", # "Global.Best.Position",
				 "counts", 
				 "convergence", 
				 "message") 

    if (out.with.pbest) {            
      out[[nelements+1]] <- X.best.part

      out[[nelements+2]] <- pbest.fit

      names(out)[(nelements+1):(nelements+2)] <- c("pbest.Parameter.Values", "pbest.fit") 

      nelements <- nelements + 2                
    } # IF end

    if (out.with.fit.iter) {  
      Xt.fitness <- Xt.fitness[1:(iter-1), ]
      out[[nelements+1]] <- Xt.fitness          
      names(out)[nelements+1] <- c("part.fit.per.iter")  
    } # IF end

    ############################################################################
    # 7)                                 Output                                #
    ############################################################################

    return(out)
        
} # 'PSO' end    
