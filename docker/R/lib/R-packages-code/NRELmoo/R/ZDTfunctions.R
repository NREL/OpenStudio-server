#############################################################
# Evolutionary Multi-Objective Optimizers in R
# Zitzler-Deb-Thiele's Test Functions 27/02/2013
# Author: Prof. Ching-Shih (Vince) Tsou, Ph.D.
# Affiliation: Institute of Information and Decision Sciences
#              National Taipei College of Business
# Email: cstsou@mail.ntcb.edu.tw
#############################################################

ZDT1 <- function(x) {
  varNo <- length(x)
  f1 <- x[1]
  g <- 1+9/(varNo-1)*sum(x[2:varNo])
  h <- 1-(f1/g)^(1/2)
  y <- numeric(2)
  y[1] <- x[1]
  y[2] <- g*h
  return(y)
}

ZDT2 <- function(x) {
  varNo <- length(x)
  f1 <- x[1]
  g <- 1+9/(varNo-1)*sum(x[2:varNo])
  h <- 1-(f1/g)^2
  y <- numeric(2)
  y[1] <- x[1]
  y[2] <- g*h
  return(y)
}

ZDT3 <- function(x) {
  varNo <- length(x)
  f1 <- x[1]
  g <- 1+9/(varNo-1)*sum(x[2:varNo])
  h <- 1-(f1/g)^(1/2)-(f1/g)*sin(10*pi*f1)
  y <- numeric(2)
  y[1] <- x[1]
  y[2] <- g*h
  return(y)
}

ZDT4 <- function(x) {
  varNo <- length(x)
  f1 <- x[1]
  g <- 1+10*(varNo-1)+sum(x[2:varNo]^2-10*cos(4*pi*x[2:varNo]))
  h <- 1-(f1/g)^(1/2)
  y <- numeric(2)
  y[1] <- x[1]
  y[2] <- g*h
  return(y)
}