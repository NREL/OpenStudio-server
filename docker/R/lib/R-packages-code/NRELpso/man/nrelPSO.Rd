%% File NRELpso.Rd
%% Part of the NRELpso R package, http://www.rforge.net/hydroPSO/ ; 
%%                                 http://cran.r-project.org/web/packages/hydroPSO
%% Copyright 2011-2013 Mauricio Zambrano-Bigiarini & Rodrigo Rojas
%% Distributed under GPL 2 or later

\name{NRELpso}
\alias{NRELpso}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Enhanced Particle Swarm Optimisation algorithm
}
\description{
State-of-the-art version of the Particle Swarm Optimisation (PSO) algorithm (SPSO-2011 and SPSO-2007 capable). NRELpso can be used as a replacement for \code{\link[stats]{optim}}, but its main focus is the calibration of environmental and other real-world model codes. Several fine-tuning options and PSO variants are available to customise the PSO engine to different calibration problems.
}
\usage{
NRELpso(cl=cl, par, fn= fn, ..., 
         method=c("spso2011", "spso2007", "ipso", "fips", "wfips", "canonical"),
         lower=-Inf, upper=Inf, control=list(), 
         model.FUN=NULL, model.FUN.args=list() )
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{cl}{snow cluster}
  \item{par}{
OPTIONAL. numeric with a first guess for the parameters to be optimised, with length equal to the dimension of the solution space \cr
All the particles are randomly initialised according to the value of \code{Xini.type}. If the user provides \env{m} parameter sets for \code{par}, they are used to overwrite the first \env{m} parameter sets randomly defined according to the value of \code{Xini.type}. If some elements in \code{par} are non finite (lower than \code{lower} or larger than \code{upper}) they are ignored
}
  \item{fn}{
function or character with the name of a valid R function to be optimised (minimized or maximized). The character value \sQuote{hydromod} is used to specify that an R-external model code (i.e., an executable file that needs to be run from the system console) will be analised instead of an R function \cr
-) When \code{fn!='hydromod'}, the first argument of \code{fn} has to be a vector of parameters over which optimisation is going to take place. It should return a scalar result. When \code{fn!='hydromod'} the algorithm uses the value(s) returned by \code{fn} as both model output and its corresponding goodness-of-fit measure \cr
-) When \code{fn=='hydromod'} the algorithm will optimise the model defined by \code{model.FUN} and \code{model.args}, which are used to extract the values simulated by the model and to compute its corresponding goodness-of-fit measure
}
\item{\dots}{
OPTIONAL. Only used when \code{fn!='hydromod'}. \cr
further arguments to be passed to \code{fn}.
}
  \item{method}{
character, variant of the PSO algorithm to be used. By default \code{method='spso2011'}, while valid values are \sQuote{spso2011}, \sQuote{spso2007}, \sQuote{ipso}, \sQuote{fips}, \sQuote{wfips}, \sQuote{canonical}:\cr

\kbd{spso2011}: At each iteration particles are attracted to its own best-known \sQuote{personal} and to the best-known position in its \sQuote{local} neighbourhood, which depens on the value of \code{topology}. In addition, values of the PSO engine are set to the values defined in the Standard PSO 2011 (SPSO 2011, see Clerc 2012) \cr

\kbd{spso2007}: As in \code{method='spso2011'}, but with values of the PSO engine set to the values defined in the Standard PSO 2007 (SPSO 2007, see Clerc 2012) \cr

\kbd{ipso}: at each iteration particles in the swarm are rearranged in descending order according to their goodness-of-fit and the best \code{ngbest} particles are used to modify particles' position and velocity (see Zhao, 2006). Each particle is connected to a neighbourhood of particles depending on the \code{topology} value \cr

\kbd{fips}: at each iteration ALL particles contribute to modify the particles' position and velocity (see Mendes et al., 2004). Each particle is connected to a neighbourhood of particles depending on the \code{topology} value \cr

\kbd{wfips}: same implementation as \kbd{fips} method, but the contribution of each particle is weighted according to their goodness-of-fit value (see Mendes et al., 2004) \cr

\kbd{canonical}: It corresponds to the first formulation of the PSO algorithm, and it is included here for educational and comparative purposes only, due to several limitations described in literature (see Kennedy 2006). At each iteration, particles are attracted to its own best-known \sQuote{personal} and to the best-known position in all the swarm (\sQuote{global}). The following \code{control} arguments are set when this method is selected: (i) \code{npart=40}, (ii) \code{topology='gbest'}, (iii) \code{Xini.type='random'}, (iv) \code{Vini.type='random2007'}, (v) \code{use.CF=TRUE}, (vi) \code{c1=2.05}, (vii) \code{c2=2.05}, (viii) \code{boundary.wall='absorbing2007'}, (ix) \code{lambda=1.0}
}
  \item{lower}{
numeric, lower boundary for each parameter \cr
Note for \code{\link[stats]{optim}} users: in \kbd{NRELpso} the length of \code{lower} and \code{upper} are used to defined the dimension of the solution space
}
  \item{upper}{
numeric, upper boundary for each parameter \cr
Note for \code{\link[stats]{optim}} users: in \kbd{NRELpso} the length of \code{lower} and \code{upper} are used to defined the dimension of the solution space
}
  \item{control}{
a list of control parameters. See \sQuote{Details}
}
  \item{model.FUN}{
OPTIONAL. Used only when \code{fn='hydromod'} \cr
character, valid R function representing the model code to be calibrated/optimised
} 
  \item{model.FUN.args}{
OPTIONAL. Used only when \code{fn='hydromod'} \cr
list with the arguments to be passed to \code{model.FUN}
} 

}
\details{
By default the NRELpso function performs minimization of \code{fn}, but it will maximize \code{fn} if \code{MinMax='max'} \cr

The default control arguments in NRELpso implements the Standard PSO 2011 - SPSO2011 (see Clerc 2012; Clerc et al., 2010). At the same time, NRELpso function provides options for clamping the maximal velocity, regrouping strategy when premature convergence is detected, time-variant acceleration coefficients, time-varying maximum velocity, (non-)linear / random / adaptive / best-ratio inertia weight definitions, random or LHS initialization of positions and velocities, synchronous or asynchronous update, 4 alternative neighbourhood topologies among others

The \code{control} argument is a list that can supply any of the following components:
  \describe{    
    \item{drty.in}{
OPTIONAL. Used only when \code{fn='hydromod'} \cr
character, name of the directory storing the input files required for PSO, i.e. \sQuote{ParamRanges.txt} and \sQuote{ParamFiles.txt}
}
  \item{drty.out}{
character, path to the directory storing the output files generated by NRELpso
}
  \item{param.ranges}{
OPTIONAL. Used only when \code{fn='hydromod'} \cr
character, name of the file defining the minimum and maximum boundary values for each one of the parameters to be calibrated
} 
  \item{digits}{
OPTIONAL. Used only when \code{write2disk=TRUE} \cr
numeric, number of significant digits used for writing the output files with scientific notation
}
  \item{MinMax}{
character, indicates whether a maximization or minimization problem needs to be solved. Valid values are in: \code{c('min', 'max')}. Default value is \kbd{min}
}
  \item{npart}{
numeric, number of particles in the swarm. By default \code{npart=NA}, which means that the swarm size depends on the value of \code{method}: \cr
when \code{method='spso2007'} \code{npart=ceiling(10+2*sqrt(n))}, or \code{npart=40} otherwise
}
  \item{maxit}{
numeric, maximum number of iterations. By default \code{maxit=1000}
}
  \item{maxfn}{
numeric, maximum number of function evaluations. Default value is \code{+Inf}\cr
When \code{fn=='hydromod'}, this stopping criterion uses the number of \emph{effective} function calls, i.e. those function calls with a finite output value
}
  \item{c1}{
numeric, cognitive acceleration coefficient. Encourages the exploitation of the solution space and reflects how much the particle is influenced by its own best-known position \cr
By default \code{c1= 0.5 + log(2)}
}
  \item{c2}{
numeric, social acceleration coefficient. Encourages the exploration of the current global best and reflects how much the particle is influenced by the best-known optimum of the swarm \cr
By default \code{c2= 0.5 + log(2)}
}
  \item{use.IW}{
logical, indicates if an inertia weight (\env{w}) will be used to avoid swarm explosion, i.e. particles flying around their best position without converging into it (see Shi and Eberhart, 1998) \cr
By default \code{use.IW=TRUE}
}
  \item{IW.w}{
OPTIONAL. Used only when \code{use.IW= TRUE \& IW.type!='GLratio'} \cr
numeric, value of the inertia weight(s) (\env{w} or \env{[w.ini, w.fin]}). It can be a single number which is used for all iterations, or it can be a vector of length 2 with the initial and final values (in that order) that \env{w} will take along the iterations \cr
By default \code{IW.w=1/(2*log(2))}
}
  \item{use.CF}{
logical, indicates if the Clerc's Constriction Factor (see Clerc, 1999; Eberhart and Shi, 2000; Clerc and Kennedy, 2002) is used to avoid swarm explosion \cr
By default \code{use.CF=FALSE}
}
  \item{lambda}{
numeric in [0,1], represents a percentage to limit the maximum velocity (Vmax) for each dimension, which is computed as \code{vmax = lambda*(Xmax-Xmin)} \cr
By default \code{lambda=1}
}
  \item{abstol}{
numeric, absolute convergence tolerance. The algorithm stops if \code{gbest <= abstol} (minimisation problems) OR when \code{gbest >= abstol} (maximisation problems) \cr
By default it is set to \code{-Inf} or \code{+Inf} for minimisation or maximisation problems, respectively
}
  \item{reltol}{
numeric, relative convergence tolerance. The algorithm stops if the absolute difference between the best \sQuote{personal best} in the current iteration and the best \sQuote{personal best} in the previous iteration is less or equal to \code{reltol}. Defaults to \code{sqrt(.Machine$double.eps)}, typically, about 1e-8\cr
If \code{reltol} is set to \code{0}, this stopping criterion is not used 
}
  \item{Xini.type}{
character, indicates how to initialise the particles' positions in the swarm within the ranges defined by \code{lower} and \code{upper}. Valid values are: \cr
-) \kbd{lhs}: Latin Hypercube initialisation of positions, using \code{npart} number of strata to divide each parameter range. \bold{It requires the \pkg{lhs} package}  \cr
-) \kbd{random}: random initialisation of positions within \code{lower} and \code{upper} \cr
By default \code{Xini.type='random'}
}
  \item{Vini.type}{
character, indicates how to initialise the particles' velocities in the swarm. Valid values are: \cr
-) \kbd{random2011}: random initialisation of velocities within \code{lower-Xini} and \code{upper-Xini}, as defined in SPSO 2011 (\samp{Vini=U(lower-Xini, upper-Xini)}) (see Clerc, 2012, 2010) \cr
-) \kbd{lhs2011}: same as in \kbd{random2011}, but using a Latin Hypercube initialisation with \code{npart} number of strata instead of a random uniform distribution for each parameter. \bold{It requires the \pkg{lhs} package} \cr
-) \kbd{random2007}: random initialisation of velocities within \code{lower} and \code{upper} using the \sQuote{half-diff} method defined in SPSO 2007 (\samp{Vini=[U(lower, upper)-Xini]/2}) (see Clerc, 2012, 2010) \cr
-) \kbd{lhs2007}: same as in \kbd{random2007}, but using a Latin Hypercube initialisation with \code{npart} number of strata instead of a random uniform distribution for each parameter. \bold{It requires the \pkg{lhs} package} \cr
-) \kbd{zero}: all the particles are initialised with zero velocity \cr
By default \code{Vini.type=NA}, which means that \code{Vini.type} depends on the value of \code{method}: when \kbd{method='spso2007'} \code{Vini.type='random2007'}, or \code{Vini.type='random2011'} otherwise
}
  \item{best.update}{
character, indicates how (when) to update the global/neighbourhood and personal best. Valid values are: \cr
-)\kbd{sync}: the update is made synchronously, i.e. after computing the position and goodness-of-fit for ALL the particles in the swarm. This is the DEFAULT option\cr
-)\kbd{async}: the update is made asynchronously, i.e. after computing the position and goodness-of-fit for EACH individual particle in the swarm
}
  \item{random.update}{
OPTIONAL. Only used when \code{best.update='async'}\cr
logical, if \code{TRUE} the particles are processed in random order to update their personal best and the global/neighbourhood best \cr
By default \code{random.update=TRUE}
}
  \item{boundary.wall}{ 
character, indicates the type of boundary condition to be applied during optimisation. Valid values are: \code{NA}, \sQuote{absorbing2011}, \sQuote{absorbing2007}, \sQuote{reflecting}, \sQuote{damping}, \sQuote{invisible} \cr
By default \code{boundary.wall=NA}, which means that \code{boundary.wall} depends on the value of \code{method}: when \kbd{method='spso2007'} \code{boundary.wall='absorbing2007'}, or \code{boundary.wall='absorbing2011'} otherwise\cr

Experience has shown that Clerc's constriction factor and the inertia weights do not always confine the particles within the solution space. To address this problem, Robinson and Rahmat-Samii (2004) and Huang and Mohan (2005) propose different boundary conditions, namely, \kbd{reflecting}, \kbd{damping}, \kbd{absorbing} and \kbd{invisible} to define how particles are treated when reaching the boundary of the searching space (see Robinson and Rahmat-Samii (2004) and Huang and Mohan (2005) for further details)
}
  \item{topology}{
character, indicates the neighbourhood topology used in NRELpso. Valid values are in \code{c('random', 'gbest', 'lbest', 'vonNeumann')}: \cr
-) \kbd{gbest}: every particle is connected to each other and, hence the global best influences all particles in the swarm. This is also termed \samp{star} topology, and it is generally assumed to have a fast convergence but is more vulnerable to the attraction to sub-optimal solutions (see Kennedy, 1999; Kennedy and Mendes, 2002, Schor et al., 2010) \cr
-) \kbd{lbest}: each particle is connected to its \code{K} immediate neighbours only. This is also termed \samp{circles} or \samp{ring} topology, and generally the swarm will converge slower than the \kbd{gbest} topology but it is less vulnerable to sub-optimal solutions (see Kennedy, 1999; Kennedy and Mendes, 2002) \cr
-) \kbd{vonNeumann}: each particle is connected to its \code{K=4} immediate neighbours only. This topology is more densely connected than \samp{lbest} but less densely than \samp{gbest}, thus, showing some parallelism with \samp{lbest} but benefiting from a bigger neighbourhood (see Kennedy and Mendes, 2003) \cr
-) \kbd{random}: the random topology is a special case of \samp{lbest} where connections among particles are randomly modified after an iteration showing no improvement in the global best (see Clerc, 2005; Clerc, 2010) \cr
By default \code{topology='random'}
}
  \item{K}{
OPTIONAL. Only used when \code{topology} is in \code{c(random, lbest, vonNeumann)} \cr
numeric, neighbourhood size, i.e. the number of informants for each particle (including the particle itself) to be considered in the computation of their personal best \cr
When \code{topology=lbest} \code{K} MUST BE an even number in order to consider the same amount of neighbours to the left and the right of each particle \cr
As special case, \code{K} could be equal to \code{npart}. By default \code{K=3}
}
  \item{iter.ini}{
OPTIONAL. Only used when \code{topology=='lbest'} \cr
numeric, number of iterations for which the \kbd{gbest} topology will be used before using the \kbd{lbest} topology for the computation of the personal best of each particle\cr
This option aims at making faster the identification of the global zone of attraction \cr
By default \code{iter.ini=0}
}
  \item{ngbest}{
OPTIONAL. Only used when \code{method=='ipso'} \cr
numeric, number of particles considered in the computation of the global best \cr
By default \code{ngbest=4} (see Zhao, 2006)
}
 \item{normalise}{
logical, indicates whether the parameter values have to be normalised to the [0,1] interval during the optimisation or not\cr
This option appears in the C and Matlab version of SPSO-2011 (See \url{http://www.particleswarm.info/standard_pso_2011_c.zip}) and there it is recommended to use this option when the search space is not an hypercube. If the search space is an hypercube, it is better not normalise (there is a small difference between the position without any normalisation and the de-normalised one). By default \code{normalise=FALSE}
}
  \item{IW.type}{
OPTIONAL. Used only when \code{use.IW= TRUE} AND \code{length(IW.w)>1}\cr
character, defines how the inertia weight \env{w} will vary along iterations. Valid values are: \cr
-)\kbd{linear}: \env{w} varies linearly between the initial and final values specified in \code{IW.w} (see Shi and Eberhart, 1998; Zheng et al., 2003). This is the DEFAULT option \cr
-)\kbd{non-linear}: \env{w} varies non-linearly between the initial and final values specified in \code{IW.w} with exponential factor \kbd{IW.exp} (see Chatterjee and Siarry, 2006) \cr
-)\kbd{runif}: \env{w} is a uniform random variable in the range \env{[w.min, w.max]} specified in \code{IW.w}. It is a generalisation of the weight proposed in Eberhart and Shi (2001b) \cr
-)\kbd{aiwf}: adaptive inertia weight factor, where the inertia weight is varied adaptively depending on the goodness-of-fit values of the particles (see Liu et al., 2005) \cr
-)\kbd{GLratio}: \env{w} varies according to the ratio between the global best and the average of the particle's local best (see Arumugam and Rao, 2008) \cr
By default \code{IW.type='linear'}
}
  \item{IW.exp}{
OPTIONAL. Used only when \code{use.IW=TRUE} AND \code{IW.type='non-linear'} \cr
numeric, non-linear modulation index (see Chatterjee and Siarry, 2006) \cr
When \code{IW.type='linear'}, \code{IW.exp} is set to 1. By default \code{IW.exp=1}
}
 \item{use.TVc1}{
logical, indicates if the cognitive acceleration coefficient \code{c1} will have a time-varying value instead of a constant one provided by the user (see Ratnaweera et al. 2004). By default \code{use.TVc1=FALSE}
}
  \item{TVc1.type}{
character, required only when \code{use.TVc1 = TRUE}. Valid values are: \cr
-)\kbd{linear}: \env{c1} varies linearly between the initial and final values specified in \code{TVc1.rng} (see Ratnaweera et al., 2004) \cr
-)\kbd{non-linear}: \env{c1} varies non-linearly between the initial and final values specified in \code{TVc1.rng}. Proposed by the authors of NRELpso taking into account the work of Chatterjee and Siarry (2006) for the inertia weight \cr
-)\kbd{GLratio}: \env{c1} varies according to the ratio between the global best and the average of the particle's local best (see Arumugam and Rao, 2008) \cr
By default \code{TVc1.type='linear'}
}
  \item{TVc1.rng}{
OPTIONAL. Used only when \code{use.TVc1=TRUE} AND \code{TVc1.type!='GLratio'} \cr
numeric, initial and final values for the cognitive acceleration coefficient \env{[c1.ini, c1.fin]} (in that order) along the iterations \cr
By default \code{TVc1.rng=c(1.28, 1.05)}
}
  \item{TVc1.exp}{
OPTIONAL. Used only when \code{use.TVc1= TRUE} AND \code{TVc1.type= 'non-linear'} \cr
numeric, non-linear modulation index \cr
When \code{TVc1.exp} is equal to 1, \code{TVc1} corresponds to the improvement proposed by Ratnaweera et al., (2004), whereas when \code{TVc1.exp} is different from one, no reference has been found in literature by the authors, but it was included as an option based on the work of Chatterjee and Siarry (2006) for the inertia weight \cr
When \code{TVc1.type='linear'}, \code{TVc1.exp} is automatically set to 1. By default \code{TVc1.exp=1}
}
 \item{use.TVc2}{
logical, indicates whether the social acceleration coefficient \code{c2} will have a time-varying value or a constant one provided by the user (see Ratnaweera et al. 2004). By default \code{use.TVc2=FALSE}
}
  \item{TVc2.type}{
character, required only when \code{use.TVc2=TRUE}. Valid values are: \cr
-)\kbd{linear}: \env{c2} varies linearly between the initial and final values specified in \code{TVc2.rng} (see Ratnaweera et al. 2004) \cr
-)\kbd{non-linear}: \env{c2} varies non-linearly between the initial and final values specified in \code{TVc2.rng}. Proposed by the authors of NRELpso taking into account the work of Chatterjee and Siarry (2006) for the inertia weight \cr
By default \code{TVc2.type='linear'}
}
  \item{TVc2.rng}{
OPTIONAL. Used only when \code{use.TVc2=TRUE} \cr
numeric, initial and final values for the social acceleration coefficient \env{[c2.ini, c2.fin]} (in that order) along the iterations \cr
By default \code{TVc2.rng=c(1.05, 1.28)}
}
  \item{TVc2.exp}{
OPTIONAL. Used only when \code{use.TVc2= TRUE} AND \code{TVc2.type='non-linear'} \cr
numeric, non-linear modulation index \cr
When \code{TVc2.exp} is equal to 1, \code{TVc2} corresponds to the improvement proposed by Ratnaweera et al., 2004, whereas when \code{TVc2.exp} is different from one, no reference has been found in literature by the authors, but it was included as an option based on the work of Chatterjee and Siarry (2006) for the inertia weight \cr
When \code{TVc2.type= linear}, \code{TVc2.exp} is automatically set to 1. By default \code{TVc2.exp=1}
}
 \item{use.TVlambda}{
logical, indicates whether the percentage to limit the maximum velocity \code{lambda} will have a time-varying value or a constant value provided by the user. Proposed by the authors of NRELpso based on the work of Chatterjee and Siarry (2006) for the inertia weight\cr
By default \code{use.TVlambda=FALSE}
}
  \item{TVlambda.type}{
character, required only when \code{use.TVlambda=TRUE}. Valid values are: \cr
-)\kbd{linear}: \env{TVvmax} varies linearly between the initial and final values specified in \code{TVlambda.rng} \cr
-)\kbd{non-linear}: \env{TVvmax} varies non-linearly between the initial and final values specified in \code{TVlambda.rng} \cr
By default \code{TVlambda.type='linear'}
}
  \item{TVlambda.rng}{
OPTIONAL. Used only when \code{use.TVlambda=TRUE} \cr
numeric, initial and final values for the percentage to limit the maximum velocity \env{[TVlambda.ini, TVlambda.fin]} (in that order) along the iterations \cr
By default \code{TVlambda.rng=c(1, 0.25)}
}
  \item{TVlambda.exp}{
OPTIONAL. only required when \code{use.TVlambda= TRUE} AND \code{TVlambda.type='non-linear'} \cr
numeric, non-linear modulation index \cr
When \code{TVlambda.type='linear'}, \code{TVlambda.exp} is automatically set to 1. By default \code{TVlambda.exp=1}
}
  \item{use.RG}{
logical, indicates if the swarm should be regrouped when premature convergence is detected. By default \code{use.RG=FALSE} \cr
When \code{use.RG=TRUE} the swarm is regrouped in a search space centred around the current global best. This updated search space is hoped to be both small enough for efficient search and large enough to allow the swarm to escape from stagnation (see Evers and Ghalia, 2009)\cr
There are 4 differences wrt Evers and Ghalia 2009: \cr
-) swarm radius: median is used instead of max \cr
-) computation of the new range of parameter space, which corresponds to the boundaries of the whole swarm at a given iteration, instead of the maximum values of \sQuote{abs(x-Gbest)} \cr
-) regrouping factor: \code{RG.r} instead of \sQuote{6/(5*ro)} \cr
-) velocity is re-initialized using \code{Vini.type} instead of using the formula proposed by Evers and Ghalia 2009 
}
  \item{RG.thr}{
ONLY required when \code{use.RG=TRUE} \cr
numeric, positive number representing the \kbd{stagnation threshold} used to decide whether the swarm has to be regrouped or not. See Evers and Galia (2009) for further details \cr
Regrouping occurs when the \emph{normalised swarm radius} is less than \code{RG.thr}. By default \code{RG.thr=1E-5}
}
  \item{RG.r}{
ONLY required when \code{use.RG=TRUE}. \cr
numeric, positive number representing the \kbd{regrouping factor}, which is used to regroup the swarm in a search space centred around the current global best (see Evers and Galia, 2009 for further details). By default \code{RG.thr=2}
}
  \item{RG.miniter}{
ONLY required when \code{use.RG=TRUE} \cr
numeric, minimum number of iterations needed before each new regrouping. By default \code{RG.miniter=100}
}
%%  \item{use.DS}{
%%CPSO
%%}
%%  \item{DS.r}{
%%     ~~Describe \code{DS.r} here~~
%%}
%%  \item{DS.tol}{
%%     ~~Describe \code{DS.tol} here~~
%%}
%%  \item{DS.dmin}{
%%     ~~Describe \code{DS.dmin} here~~
%%}
  \item{plot}{
logical, indicates if a two-dimensional plot with the particles' position will be drawn after each iteration. For high dimensional functions, only the first two dimensions of all the particles are plotted\cr
By default \code{plot=FALSE}
}
  \item{out.with.pbest}{
logical, indicates if the best parameter values for each particle and their goodness-of-fit will be included in the output of the algorithm\cr
By default \code{out.with.pbest=FALSE}
}
  \item{out.with.fit.iter}{
logical, indicates if the goodness-of-fit of each particle for each iteration will be included in the output of the algorithm\cr
By default \code{out.with.fit.iter=FALSE}
}
  \item{write2disk}{
logical, indicates if the output files will be written to the disk. By default \code{write2disk=TRUE}
}
  \item{verbose}{
logical, indicates if progress messages are to be printed. By default \code{verbose=TRUE}
} 
  \item{REPORT}{
OPTIONAL. Used only when \code{verbose=TRUE} \cr
The frequency of report messages printed to the screen. Default to every 100 iterations
} 
  \item{parallel}{
character, indicates how to parallelise \sQuote{NRELpso} (to be precise, only the evaluation of the objective function \code{fn} is parallelised). Valid values are: \cr
-)\kbd{none}: no parallelisation is made (this is the default value)\cr
-)\kbd{multicore}: parallel computations for machines with multiple cores or CPUs. The evaluation of the objective function \code{fn} is done with the \code{\link[parallel]{mclapply}} function of the \pkg{parallel} package. It requires POSIX-compliant OS (essentially anything but Windows) \cr
-)\kbd{parallel}: parallel computations for network clusters or machines with multiple cores or CPUs. A \sQuote{FORK} cluster is created with the \code{\link[parallel]{makeForkCluster}} function.  When \code{fn.name="hydromod"} the evaluation of the objective function \code{fn} is done with the \code{\link[parallel]{clusterApply}} function of the \pkg{parallel} package. When \code{fn.name!="hydromod"} the evaluation of the objective function \code{fn} is done with the \code{\link[parallel]{parRapply}} function of the \pkg{parallel} package.\cr
-)\kbd{parallelWin}: parallel computations for network clusters or machines with multiple cores or CPUs (this is the only parallel implementation that works on Windows machines). A \sQuote{PSOCK} cluster is created with the \code{\link[parallel]{makeCluster}} function. When \code{fn.name="hydromod"} the evaluation of the objective function \code{fn} is done with the \code{\link[parallel]{clusterApply}} function of the \pkg{parallel} package. When \code{fn.name!="hydromod"} the evaluation of the objective function \code{fn} is done with the \code{\link[parallel]{parRapply}} function of the \pkg{parallel} package. 
} 
  \item{par.nnodes}{
OPTIONAL. Used only when \code{parallel!='none'} \cr
numeric, indicates the number of cores/CPUs to be used in the local multi-core machine, or the number of nodes to be used in the network cluster. \cr
By default \code{par.nnodes} is set to the amount of cores detected by the function \code{detectCores()} (\pkg{multicore} or \pkg{parallel} package)
} 
  \item{par.pkgs}{
OPTIONAL. Used only when \code{parallel='parallelWin'} \cr
list of package names (as characters) that need to be loaded on each node for allowing the objective function \code{fn} to be evaluated
} 
}
}

\value{
A list, compatible with the output from \code{\link[stats]{optim}}, with components:
\item{par}{
optimum parameter set found    
}
\item{value}{
value of \code{fn} corresponding to \code{par}
}
\item{counts}{
three-element vector containing the total number of function calls, number of iterations, and number of regroupings
}
\item{convergence}{
integer code where \code{0} indicates that the algorithm terminated by reaching the absolute tolerance, otherwise:
\describe{
 \item{1}{relative tolerance reached}
 \item{2}{maximum number of (effective) function evaluations reached}
 \item{3}{maximum number of iterations reached}
}
}
\item{message}{character string giving human-friendly information about \code{convergence}
}
}
\references{
\cite{Clerc, M. Standard Particle Swarm. 2012. (SPSO-2007, SPSO-2011). \url{clerc.maurice.free.fr/pso/SPSO_descriptions.pdf}. Last visited [24-Sep-2012]}

\cite{Clerc, M. From Theory to Practice in Particle Swarm Optimization, Handbook of Swarm Intelligence, Springer Berlin Heidelberg, 3-36, Eds: Panigrahi, Bijaya Ketan, Shi, Yuhui, Lim, Meng-Hiot, Hiot, Lim Meng, and Ong, Yew Soon, 2010, doi: 10.1007/978-3-642-17390-5_1}

\cite{Clerc, M., Stagnation Analysis in Particle Swarm Optimisation or what happens when nothing happens. Technical Report. 2006. \url{http://hal.archives-ouvertes.fr/hal-00122031}}

\cite{Clerc, M. Particle Swarm Optimization. ISTE, 2005}

\cite{Clerc, M and J Kennedy. The particle swarm - explosion, stability, and convergence in a multidimensional complex space. IEEE Transactions On Evolutionary Computation, 6:58-73, 2002. doi:10.1109/4235.985692}

\cite{Chatterjee, A. and Siarry, P. Nonlinear inertia weight variation for dynamic adaptation in particle swarm optimization, Computers \& Operations Research, Volume 33, Issue 3, March 2006, Pages 859-871, ISSN 0305-0548, DOI: 10.1016/j.cor.2004.08.012}

\cite{Eberhart, R.C.; Shi, Y.; Comparing inertia weights and constriction factors in particle swarm optimization. Evolutionary Computation, 2000. Proceedings of the 2000 Congress on , vol.1, no., pp.84-88 vol.1, 2000. doi: 10.1109/CEC.2000.870279}

\cite{Evers, G.I.; Ben Ghalia, M. Regrouping particle swarm optimization: A new global optimization algorithm with improved performance consistency across benchmarks. Systems, Man and Cybernetics, 2009. SMC 2009. IEEE International Conference on , vol., no., pp.3901-3908, 11-14 Oct. 2009. doi: 10.1109/ICSMC.2009.5346625}

\cite{Huang, T.; Mohan, A.S.; , A hybrid boundary condition for robust particle swarm optimization. Antennas and Wireless Propagation Letters, IEEE , vol.4, no., pp. 112-117, 2005. doi: 10.1109/LAWP.2005.846166}

\cite{Kennedy, J. and R. Eberhart. Particle Swarm Optimization. in proceedings IEEE international conference on Neural networks. pages 1942-1948. 1995. doi: 10.1109/ICNN.1995.488968}
        
\cite{Kennedy, J.; Small worlds and mega-minds: effects of neighborhood topology on particle swarm performance. Evolutionary Computation, 1999. CEC 99. Proceedings of the 1999 Congress on , vol.3, no., pp.3 vol. (xxxvii+2348), 1999. doi: 10.1109/CEC.1999.785509}

\cite{Kennedy, J.; Mendes, R.. Population structure and particle swarm performance. Evolutionary Computation, 2002. CEC '02. Proceedings of the 2002 Congress on , vol.2, no., pp.1671-1676, 2002. doi: 10.1109/CEC.2002.1004493}

\cite{Kennedy, J.; Mendes, R.; , Neighborhood topologies in fully-informed and best-of-neighborhood particle swarms. Soft Computing in Industrial Applications, 2003. SMCia/03. Proceedings of the 2003 IEEE International Workshop on , vol., no., pp. 45- 50, 23-25 June 2003. doi: 10.1109/SMCIA.2003.1231342}

\cite{Kennedy, J. 2006. Swarm intelligence, in Handbook of Nature-Inspired and Innovative Computing, edited by A. Zomaya, pp. 187-219, Springer US, doi:10.1007/0-387-27705-6_6}

\cite{Liu, B. and L. Wang, Y.-H. Jin, F. Tang, and D.-X. Huang. Improved particle swarm optimization combined with chaos. Chaos, Solitons \& Fractals, vol. 25, no. 5, pp.1261-1271, Sep. 2005. doi:10.1016/j.chaos.2004.11.095}

\cite{Mendes, R.; Kennedy, J.; Neves, J. The fully informed particle swarm: simpler, maybe better. Evolutionary Computation, IEEE Transactions on , vol.8, no.3, pp. 204-210, June 2004. doi: 10.1109/TEVC.2004.826074}

\cite{Ratnaweera, A.; Halgamuge, S.K.; Watson, H.C. Self-organizing hierarchical particle swarm optimizer with time-varying acceleration coefficients. Evolutionary Computation, IEEE Transactions on , vol.8, no.3, pp. 240- 255, June 2004. doi: 10.1109/TEVC.2004.826071}

\cite{Robinson, J.; Rahmat-Samii, Y.; Particle swarm optimization in electromagnetics. Antennas and Propagation, IEEE Transactions on , vol.52, no.2, pp. 397-407, Feb. 2004. doi: 10.1109/TAP.2004.823969}

\cite{Shi, Y.; Eberhart, R. A modified particle swarm optimizer. Evolutionary Computation Proceedings, 1998. IEEE World Congress on Computational Intelligence. The 1998 IEEE International Conference on , vol., no., pp.69-73, 4-9 May 1998. doi: 10.1109/ICEC.1998.699146}

\cite{Schor, D.; Kinsner, W.; Anderson, J.; A study of optimal topologies in swarm intelligence. Electrical and Computer Engineering (CCECE), 2010 23rd Canadian Conference on , vol., no., pp.1-8, 2-5 May 2010. doi: 10.1109/CCECE.2010.5575132}

\cite{Yong-Ling Zheng; Long-Hua Ma; Li-Yan Zhang; Ji-Xin Qian. On the convergence analysis and parameter selection in particle swarm optimization. Machine Learning and Cybernetics, 2003 International Conference on , vol.3, no., pp. 1802-1807 Vol.3, 2-5 Nov. 2003. doi: 10.1109/ICMLC.2003.1259789}

\cite{Zambrano-Bigiarini, M., and R. Rojas (2013), A model-independent Particle Swarm Optimisation software for model calibration, Environmental Modelling \& Software, 43, 5-25, doi:10.1016/j.envsoft.2013.01.004}

\cite{Zambrano-Bigiarini, M; M. Clerc; R. Rojas (2013), Standard Particle Swarm Optimisation 2011 at CEC-2013: A baseline for future PSO improvements, In Proceedings of 2013 IEEE Congress  Evolutionary Computation (CEC'2013) (accepted)}

\cite{Zhao, B.  An Improved Particle Swarm Optimization Algorithm for Global Numerical Optimization. In Proceedings of International Conference on Computational Science (1). 2006, 657-664}

\cite{Neighborhood Topologies, \url{http://tracer.uc3m.es/tws/pso/neighborhood.html}. Last visited [15-Feb-2012] }
}
\author{
Mauricio Zambrano-Bigiarini, \email{mzb.devel@gmail.com}
}
\note{
Note for \code{\link[stats]{optim}} users: \cr
1) In \kbd{NRELpso} the length of \code{lower} and \code{upper} are used to define the dimension of the solution space (not the length of \code{par}) \cr
2) In \kbd{NRELpso}, \code{par} may be omitted. If not omitted, the  \env{m} parameter sets provided by the user for \code{par} are used to overwrite the first \env{m} parameter sets randomly defined according to the value of \code{Xini.type} \cr

}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
\code{\link[stats]{optim}}
}
\examples{
# Number of dimensions of the optimisation problem (for all the examples)
D <- 5

# Boundaries of the search space (Rastrigin function)
lower <- rep(-5.12, D)
upper <- rep(5.12, D)

\dontrun{
# Setting the home directory of the user as working directory 
setwd("~")
   
################################ 
# Example 1. Basic use         #
################################ 

# Setting the seed (for reproducible results)         
set.seed(100)

# Basic use 1. Rastrigin function (non-linear and multi-modal with many local minima)
# Results are not saved to the hard disk, for faster execution ('write2disk=FALSE')
NRELpso(fn=rastrigin, lower=lower, upper=upper, control=list(write2disk=FALSE) )

# Basic use 2. Rastrigin function (non-linear and multimodal with many local minima)
# Results are saved to the hard disk. Slower than before but results are kept for
# future inspection
NRELpso(fn=rastrigin, lower=lower, upper=upper )


################################ 
# Example 2. More advanced use #
################################ 

# Defining the relative tolerance ('reltol'), the frequency of report messages 
# printed to the screen ('REPORT'), and no output files ('write2disk')
set.seed(100)
NRELpso( fn=rastrigin, lower=lower, upper=upper,        
          control=list(reltol=1e-20, REPORT=10, write2disk=FALSE) )
        
        
################################### 
# Example 3. von Neumman Topology #
###################################

# Same as Example 2, but using a von Neumann topology ('topology="vonNeumann"')
set.seed(100)
NRELpso(fn=rastrigin,lower=lower,upper=upper,
         control=list(topology="vonNeumann", reltol=1E-20, 
                      REPORT=50, write2disk=FALSE) ) 



################################ 
# Example 4. Regrouping        #
################################ 

# Same as Example 3 ('topology="vonNeumann"') but using regrouping ('use.RG')
set.seed(100)
NRELpso(fn=rastrigin,lower=lower,upper=upper,
         control=list(topology="vonNeumann", reltol=1E-20, 
                      REPORT=50, write2disk=FALSE,
                      use.RG=TRUE,RG.thr=7e-2,RG.r=3,RG.miniter=50) )


################################ 
# Example 5. FIPS              #
################################ 

# Same as Example 3 ('topology="vonNeumann"') but using a fully informed 
# particle swarm (FIPS) variant ('method') with global best topology
set.seed(100)
NRELpso(fn=rastrigin,lower=lower,upper=upper, method="fips",
         control=list(topology="gbest",reltol=1E-9,write2disk=FALSE) )


################################ 
# Example 6. normalisation     #
################################ 

# Same as Example 3 but parameter values are normalised to the [0,1] interval 
# during the optimisation. This option is recommended when the search space is 
# not an hypercube (not useful is this particular example)
set.seed(100)
NRELpso(fn=rastrigin,lower=lower,upper=upper,
         control=list(topology="vonNeumann", reltol=1E-20, normalise=TRUE,
                      REPORT=50, write2disk=FALSE) ) 


################################ 
# Example 7. Asynchronus update#
################################ 

# Same as Example 3, but using asynchronus update of previus and local best 
# ('best.update'). Same global optimum but much slower....
set.seed(100)
NRELpso(fn=rastrigin,lower=lower,upper=upper,
         control=list(topology="vonNeumann", reltol=1E-20, 
                      REPORT=50, write2disk=FALSE, best.update="async") ) 

} # dontrun END

}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{optimize}
\keyword{files}
