## ----setup, include=FALSE------------------------------------------------
library(knitr)
opts_chunk$set(fig.align="center",
               fig.width=5, fig.height=4,
               dev.args=list(pointsize=8),
               par=TRUE)

knit_hooks$set(par = function(before, options, envir)
  { if(before && options$fig.show != "none") 
       par(mar=c(4.1,4.1,1.1,1.1), mgp=c(3,1,0), tcl=-0.5)
})

## ---- message=FALSE, results='asis'--------------------------------------
library(GA)

## ------------------------------------------------------------------------
f <- function(x)  (x^2+x)*cos(x)
min <- -10; max <- 10
curve(f, min, max, n = 1000)

GA <- ga(type = "real-valued", fitness = f, min = min, max = max, 
         monitor = FALSE)
summary(GA)
plot(GA)

curve(f, min, max, n = 1000)
points(GA@solution, GA@fitnessValue, col = 2, pch = 19)

## ------------------------------------------------------------------------
Rastrigin <- function(x1, x2)
{
  20 + x1^2 + x2^2 - 10*(cos(2*pi*x1) + cos(2*pi*x2))
}

x1 <- x2 <- seq(-5.12, 5.12, by = 0.1)
f <- outer(x1, x2, Rastrigin)
persp3D(x1, x2, f, theta = 50, phi = 20, color.palette = bl2gr.colors)
filled.contour(x1, x2, f, color.palette = bl2gr.colors)

## ---- eval=FALSE, echo=FALSE---------------------------------------------
#  # Define a monitoring function of the space searched at each GA iteration:
#  monitor <- function(obj)
#  {
#    contour(x1, x2, f, drawlabels = FALSE, col = grey(0.5))
#    title(paste("iteration =", obj@iter), font.main = 1)
#    points(obj@population, pch = 20, col = 2)
#    Sys.sleep(0.2)
#  }
#  
#  GA <- ga(type = "real-valued",
#           fitness =  function(x) -Rastrigin(x[1], x[2]),
#           min = c(-5.12, -5.12), max = c(5.12, 5.12),
#           popSize = 50, maxiter = 100,
#           monitor = monitor)

## ------------------------------------------------------------------------
GA <- ga(type = "real-valued", 
         fitness =  function(x) -Rastrigin(x[1], x[2]),
         min = c(-5.12, -5.12), max = c(5.12, 5.12), 
         popSize = 50, maxiter = 1000, run = 100)
summary(GA)
plot(GA)

## ------------------------------------------------------------------------
filled.contour(x1, x2, f, color.palette = bl2gr.colors, 
  plot.axes = { axis(1); axis(2); 
                points(GA@solution[,1], GA@solution[,2], 
                       pch = 3, cex = 2, col = "white", lwd = 2) }
)

## ------------------------------------------------------------------------
f <- function(x)
  { 100 * (x[1]^2 - x[2])^2 + (1 - x[1])^2 }

c1 <- function(x) 
  { x[1]*x[2] + x[1] - x[2] + 1.5 }

c2 <- function(x) 
  { 10 - x[1]*x[2] }

## ------------------------------------------------------------------------
ngrid = 250
x1 = seq(0, 1, length = ngrid)
x2 = seq(0, 13, length = ngrid)
x12 = expand.grid(x1, x2)
col = adjustcolor(bl2gr.colors(4)[2:3], alpha = 0.2)
plot(x1, x2, type = "n", xaxs = "i", yaxs = "i")
image(x1, x2, matrix(ifelse(apply(x12, 1, c1) <= 0, 0, NA), ngrid, ngrid), 
      col = col[1], add = TRUE)
image(x1, x2, matrix(ifelse(apply(x12, 1, c2) <= 0, 0, NA), ngrid, ngrid), 
      col = col[2], add = TRUE)
contour(x1, x2, matrix(apply(x12, 1, f), ngrid, ngrid), 
        nlevels = 21, add = TRUE)

## ------------------------------------------------------------------------
x = c(0.8122, 12.3104)
f(x)

## ------------------------------------------------------------------------
c1(x)
c2(x)

## ------------------------------------------------------------------------
fitness <- function(x) 
{ 
  f <- -f(x)                         # we need to maximise -f(x)
  pen <- sqrt(.Machine$double.xmax)  # penalty term
  penalty1 <- max(c1(x),0)*pen       # penalisation for 1st inequality constraint
  penalty2 <- max(c2(x),0)*pen       # penalisation for 2nd inequality constraint
  f - penalty1 - penalty2            # fitness function value
}

## ------------------------------------------------------------------------
GA = ga("real-valued", fitness = fitness, 
        min = c(0,0), max = c(1,13), 
        maxiter = 5000, run = 1000, seed = 123)
summary(GA)

fitness(GA@solution)
f(GA@solution)
c1(GA@solution)
c2(GA@solution)

## ------------------------------------------------------------------------
plot(x1, x2, type = "n", xaxs = "i", yaxs = "i")
image(x1, x2, matrix(ifelse(apply(x12, 1, c1) <= 0, 0, NA), ngrid, ngrid), 
      col = col[1], add = TRUE)
image(x1, x2, matrix(ifelse(apply(x12, 1, c2) <= 0, 0, NA), ngrid, ngrid), 
      col = col[2], add = TRUE)
contour(x1, x2, matrix(apply(x12, 1, f), ngrid, ngrid), 
        nlevels = 21, add = TRUE)
points(GA@solution[1], GA@solution[2], col = "dodgerblue3", pch = 3)  # GA solution

## ------------------------------------------------------------------------
GA <- ga(type = "real-valued", 
         fitness =  function(x) -Rastrigin(x[1], x[2]),
         min = c(-5.12, -5.12), max = c(5.12, 5.12), 
         popSize = 50, maxiter = 1000, run = 100,
         optim = TRUE)
summary(GA)
plot(GA)

## ---- eval=FALSE---------------------------------------------------------
#  library(GA)
#  fitness <- function(x)
#  {
#    Sys.sleep(0.01)
#    x*runif(1)
#  }
#  
#  library(rbenchmark)
#  out <- benchmark(GA1 = ga(type = "real-valued",
#                            fitness = fitness, min = 0, max = 1,
#                            popSize = 50, maxiter = 100, monitor = FALSE,
#                            seed = 12345),
#                   GA2 = ga(type = "real-valued",
#                            fitness = fitness, min = 0, max = 1,
#                            popSize = 50, maxiter = 100, monitor = FALSE,
#                            seed = 12345, parallel = TRUE),
#                   GA3 = ga(type = "real-valued",
#                            fitness = fitness, min = 0, max = 1,
#                            popSize = 50, maxiter = 100, monitor = FALSE,
#                            seed = 12345, parallel = 2),
#                   GA4 = ga(type = "real-valued",
#                            fitness = fitness, min = 0, max = 1,
#                            popSize = 50, maxiter = 100, monitor = FALSE,
#                            seed = 12345, parallel = "snow"),
#                   columns = c("test", "replications", "elapsed", "relative"),
#                   order = "test",
#                   replications = 10)
#  out$average <- with(out, average <- elapsed/replications)
#  out[,c(1:3,5,4)]

## ---- eval=FALSE---------------------------------------------------------
#  library(doParallel)
#  workers <- rep(c("141.250.100.1", "141.250.105.3"), each = 8)
#  cl <- makeCluster(workers, type = "PSOCK")
#  registerDoParallel(cl)

## ---- eval=FALSE---------------------------------------------------------
#  clusterExport(cl, varlist = c("x", "fun"))
#  clusterCall(cl, library, package = "mclust", character.only = TRUE)

## ---- echo=FALSE---------------------------------------------------------
# run not in parallel because it is not allowed in CRAN checks
GA <- gaisl(type = "real-valued", 
            fitness =  function(x) -Rastrigin(x[1], x[2]),
            min = c(-5.12, -5.12), max = c(5.12, 5.12), 
            popSize = 100, 
            maxiter = 1000, run = 100, 
            numIslands = 4, 
            migrationRate = 0.2, 
            migrationInterval = 50,
            parallel = FALSE)

## ---- eval=FALSE---------------------------------------------------------
#  GA <- gaisl(type = "real-valued",
#              fitness =  function(x) -Rastrigin(x[1], x[2]),
#              min = c(-5.12, -5.12), max = c(5.12, 5.12),
#              popSize = 100,
#              maxiter = 1000, run = 100,
#              numIslands = 4,
#              migrationRate = 0.2,
#              migrationInterval = 50)

## ------------------------------------------------------------------------
summary(GA)
plot(GA, log = "x")

## ---- eval = FALSE-------------------------------------------------------
#  data(fat, package = "UsingR")
#  mod <- lm(body.fat.siri ~ age + weight + height + neck + chest + abdomen +
#            hip + thigh + knee + ankle + bicep + forearm + wrist, data = fat)
#  summary(mod)
#  x <- model.matrix(mod)[,-1]
#  y <- model.response(mod$model)
#  
#  fitness <- function(string)
#  {
#    inc <- which(string==1)
#    X <- cbind(1, x[,inc])
#    mod <- lm.fit(X, y)
#    class(mod) <- "lm"
#    -BIC(mod)
#  }
#  
#  library(memoise)
#  mfitness <- memoise(fitness)
#  
#  is.memoised(fitness)

## ---- eval = FALSE-------------------------------------------------------
#  is.memoised(mfitness)

## ---- eval = FALSE-------------------------------------------------------
#  library(rbenchmark)
#  tab = benchmark(GA1 = ga("binary", fitness = fitness, nBits = ncol(x),
#                           popSize = 100, maxiter = 100, seed = 1, monitor = FALSE),
#                  GA2 = ga("binary", fitness = mfitness, nBits = ncol(x),
#                           popSize = 100, maxiter = 100, seed = 1, monitor = FALSE),
#                  columns = c("test", "replications", "elapsed", "relative"),
#                  replications = 10)
#  tab$average = with(tab, elapsed/replications)
#  tab

## ---- eval=FALSE---------------------------------------------------------
#  # To clear cache use
#  forget(mfitness)

## ------------------------------------------------------------------------
sessionInfo()

