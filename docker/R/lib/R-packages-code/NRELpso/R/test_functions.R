# Part of the hydroPSO package, http://www.rforge.net/hydroPSO/
# Copyright 2008-2012 Mauricio Zambrano-Bigiarini & Rodrigo Rojas
# Distributed under GPL 2 or later

# All these function were started on 2008, with updates on:                    #
# 13-Dec-2010 ; 20-Dec-2010; 21-Dec-2010                                       #
# 24-Jan-2011 ; 02-Feb-2011                                                    #
# 14-Nov-2011 ; 21-Sep-2012 ; 25-Sep-2012 ; 21-Nov-2012 ; 22-Nov-2012          #

# MZB, 21-Jun-2011
# 3D sinc function: f(1,..,1)=1. Maximization
sinc <- function(x) {
    n <- length(x)
    return( prod (sin( pi*(x-seq(1:n)) ) / ( pi*(x-seq(1:n)) ), na.rm=TRUE) )
} # 'sinc' END


# MZB, RR, 21-Jun-2011,  14-Nov-2011 ; 21-Nov-2012
# Rosenbrock function: f(1,..,1)=0. Minimization. In [-30, 30]^n. AcceptableError < 100
# Properties : Unimodal, Non-separable 
# Description: The Rosenbrock function is non-convex, unimodal and non-separable. 
#              It is also known as \emph{Rosenbrock's valley} or \emph{Rosenbrock's banana} function.
#              The global minimum is inside a long, narrow, parabolic shaped flat valley. 
#              To find the valley is trivial. To converge to the global minimum, however, is difficult. 
#              It only has one optimum located at the point \preformatted{o =(1,...,1)}. 
#              It is a quadratic function, and its search range is [−30, 30] for each variable. 
# Ref: http://en.wikipedia.org/wiki/Rosenbrock_function, http://www.it.lut.fi/ip/evo/functions/node5.html
rosenbrock <- function(x) {  
  n <- length(x)
  return( sum( 100*( x[2:n] - x[1:(n-1)]^2 )^2 + ( x[1:(n-1)] - 1 )^2 ) )
} # 'rosenbrock' END


# MZB, RR, 21-Jun-2011; 21-Nov-2012
# Sphere function: f(0,..,0)=0. Minimization. In [-100, 100]^n. AcceptableError < 0.01
# Properties : Unimodal, additively separable
# Description: The Sphere test function is one of the most simple test functions 
#              available in the specialized literature. This unimodal and separable 
#              test function can be scaled up to any number of variables. 
#              It belongs to a family of functions called quadratic functions and 
#              only has one optimum in the point o = (0,...,0). The search range 
#              commonly used for the Sphere function is [−100, 100] for each decision variable.
# Reference  : http://www.it.lut.fi/ip/evo/functions/node2.html
sphere <- function(x) {
  return(sum(x^2))  
} # 'sphere' END


# MZB, RR, 21-Jun-2011,  14-Nov-2011. Keep only for backward compatibility
# Rastrigrin function: f(0,..,0)=0. Minimization. In [-5.12, 5.12]^n. AcceptableError < 100
rastrigrin <- function(x) { 
  n <- length(x) 
  return( 10*n + sum( x^2 - 10*cos(2*pi*x) ) )
} # 'rastrigrin' END

# MZB, RR, 17-Jul-2012. 21-Nov-2012. The correct name of the function is 'Rastrigin' and NOT 'Rastrigrin' !!!
# Rastrigin function: f(0,..,0)=0. Minimization. In [-5.12, 5.12]^n. AcceptableError < 100
# Properties : Multimodal, additively separable 
# Description: The generalized Rastrigin test function is non-convex and multimodal. 
#              It has several local optima arranged in a regular lattice, but it 
#              only has one global optimum located at the point \preformatted{o=(0,...,0)}. 
#              The search range for the Rastrigin function is [-5.12, 5.12] in each variable. 
#              This function is a fairly difficult problem due to its large search 
#              space and its large number of local minima
# Reference  : http://www.it.lut.fi/ip/evo/functions/node6.html, http://en.wikipedia.org/wiki/Rastrigin_function
rastrigin <- function(x) { 
  n <- length(x) 
  return( 10*n + sum( x^2 - 10*cos(2*pi*x) ) )
} # 'rastrigin' END


# MZB, RR, 21-Jun-2011 ; 21-Nov-2012
# Griewank function: f(0,..,0)=0. Minimization. In [-600, 600]^n. AcceptableError < 0.05
# Properties : Multimodal, Non-separable
# Description: The Griewank test function is multimodal and non-separable, with 
#              several local optima within the search region defined by [-600, 600]. 
#              It is similar to the Rastrigin function, but the number of local 
#              optima is larger in this case. It only has one global optimum 
#              located at the point \kbd{o=(0,...,0)}. While this function has 
#              an exponentially increasing number of local minima as its dimension 
#              increases, it turns out that a simple multistart algorithm is able 
#              to detect its global minimum more and more easily as the dimension 
#              increases (Locatelli, 2003)
# Reference  : http://www.geatbx.com/docu/fcnindex-01.html
#              Locatelli, M. 2003. A note on the griewank test function, 
#              Journal of Global Optimization, 25 (2), 169-174, doi:10.1023/A:1021956306041
griewank <- function(x) {  
  n <- length(x)
  return( 1 + (1/4000)*sum( x^2 ) - prod( cos( x/sqrt(seq(1:n)) ) ) )
} # 'griewank' END


# MZB, RR, 21-Jun-2011,  14-Nov-2011,  13-Sep-2012 ; 22-Nov-2012
# Schaffer's f6 function: f(0,..,0)=0. Minimization. In [-100, 100]^n. AcceptableError < 1E-4
# Reference: Xiaohong Qiu, Jun Liu. 2009. A Novel Adaptive PSO Algorithm on Schaffer's F6 Function. 
#            vol. 2, pp.94-98. Ninth International Conference on Hybrid Intelligent Systems
schafferF6 <- function(x) {  
  return( 0.5 + ( ( sin( sqrt( sum( x^2 ) ) ) )^2 - 0.5) / ( ( 1 + 0.001*sum(x^2) )^2 ) )
} # 'schafferF6' END


# MZB, RR, 14-Nov-2011, 21-Nov-2012
# Ackley function: f(0,..,0)=0. Minimization. In [-32.768, 32.768]^n. AcceptableError < 0.01, a=20 ; b=0.2 ; c=2*pi
# Properties : Multimodal, Separable 
# Description: The Ackley test function is multimodal and separable, with several 
#              local optima that, for the search range [-32, 32], look more like noise, 
#              although they are located at regular intervals. The Ackley function 
#              only has one global optimum located at the point o=(0,...,0).
# Reference  : http://www.it.lut.fi/ip/evo/functions/node14.html
ackley <- function(x) {  
  n <- length(x)
  return( -20*exp( -0.2*sqrt((1/n)*sum(x^2)) ) - exp( (1/n)*sum(cos(2*pi*x)) ) + 20 + exp(1) )
} # 'schafferF6' END


# MZB, 25-Sep-2012. Schwefel: f(xi,..,xi)=0, with xi= 420.968746
# Minimization. In [-500, 500]^n. AcceptableError < 0.01
# Properties: Multimodal, Additively separable 
#             This function is deceptive in that the global minimum is geometrically 
#             distant, over the parameter space, from the next best local minima. 
# Ref: http://www.scribd.com/doc/74351406/7/Schwefel%E2%80%99s-function
schwefel <- function(x) { 
  n <- length(x) 
  return( 418.98288727433799*n + sum( -x*sin( sqrt(abs(x)) ) ) )
} # 'schwefel' END


################################################################################
########################### Shifted Functions ##################################
################################################################################

# MZB, 21-Sep-2012. Shifted Sphere (CEC 2005): f(o,..,o)=-450. 
# Minimization. In [-100, 100]^n. AcceptableError < 0.01.
# Properties: Unimodal, Shifted, Separable, Scalable 
ssphere <- function (x, o=-100+200*runif(length(x)), fbias=-450) {
 n <- length(x)
 if (n != length(o)) stop("length(x) != length(o)")
 z <- x - o
 return(sum(z^2) + fbias)
} # 'ssphere'

# MZB, RR, 21-Jun-2011. Properties: Unimodal, Shifted, Separable, Scalable
# Shifted Griewank : f(o,..,o)=-180. Minimization. In [-600, 600]^n. AcceptableError < 0.05
sgriewank <- function (x, o=-600+1200*runif(length(x)), fbias=-180) {
  n <- length(x)
  if (n != length(o)) stop("length(x) != length(o)")
  z <- x - o
  return(1 + (1/4000) * sum(z^2) - prod(cos(z/sqrt(seq(1:n)))) + fbias)
} # 'sgriewank'


# MZB, 21-Sep-2012. # Shifted Rosenbrock (CEC 2005): f(o,..,o)=390. 
# Minimization. In [-100, 100]^n. AcceptableError < 100
# Properties: Multi-modal, Shifted, Non-separable, Scalable, Having a very narrow 
#             valley from local optimum to  global optimum
srosenbrock <- function(x, o=-100+200*runif(length(x)), fbias=390) {  
  n <- length(x)
  if (n != length(o)) stop("length(x) != length(o)")
  z <- x - o
  return( sum( ( 1- z[1:(n-1)] )^2 + 100*( z[2:n] - z[1:(n-1)]^2 )^2 ) + fbias )
} # 'srosenbrock' END


# MZB, 21-Sep-2012. Shifted Ackley: f(o,..,o)=-140. 
# Minimization. In [-32.768, 32.768]^n. AcceptableError < 0.01, a=20 ; b=0.2 ; c=2*pi
sackley <- function (x, o=-32+64*runif(length(x)), fbias=-140) {
  n <- length(x)
  if (n != length(o)) stop("length(x) != length(o)")
  z <- x - o
  return(-20 * exp(-0.2 * sqrt((1/n) * sum(z^2))) - exp((1/n) * sum(cos(2 * pi * z))) + 20 + exp(1) + fbias )
} # 'sackley'


# MZB, 21-Sep-2012. Shifted Rastrigin (CEC 2005): f(o,..,o)=-330. 
# Minimization. In [-5.12, 5.12]^n. AcceptableError < 100
# Properties: Multi-modal, Shifted, Separable, Scalable, Huge number of local optima
srastrigin <- function(x, o=-5+10*runif(length(x)), fbias=-330) { 
  n <- length(x) 
  if (n != length(o)) stop("length(x) != length(o)")
  z <- x - o
  return( 10*n + sum( z^2 - 10*cos(2*pi*z) ) + fbias )
} # 'srastrigin' END


# MZB, 25-Sep-2012. Shifted Schwefel's Problem 1.2 (CEC 2005): f(o,..,o)=-450. 
# Minimization. In [-100, 100]^n. AcceptableError < 100
# Properties: Unimodal, Shifted, Non-separable, Scalable
sschwefel1_2 <- function(x, o=-100+200*runif(length(x)), fbias=-450) { 
  n <- length(x) 
  if (n != length(o)) stop("length(x) != length(o)")
  z <- x - o
  return( sum( (cumsum(z))^2 ) + fbias )
} # 'sschwefel1_2' END


#### TODO: find the definition of the rotation matrix M:
## MZB, 21-Sep-2012. Shifted Rotated Rastrigin (CEC 2005): f(o,..,o)=-330. 
## Minimization. In [-5.12, 5.12]^n. AcceptableError < 100
## Properties: Multi-modal, Shifted, Rotated, Non-separable, Scalable, Huge number of local optima
#srrastrigin <- function(x, o=-5+10*runif(length(x)), fbias=-330) { 
#  n <- length(x) 
#  if (n != length(o)) stop("length(x) != length(o)")
#  z <- x - o
#  return( 10*n + sum( z^2 - 10*cos(2*pi*z) ) + fbias )
#} # 'srrastrigin' END

