## This approach uses a single global data structure to record timing
## information. The structure contains functions defined in a shared
## environment to implement mutable state. Workers are identified by
## their rank.  The functions recvData, recvOneData, and sendCall have
## been modified to record timing information in timing is active.
## The overhead of the test for timing should be fairly small compared
## to the data transmissions.  If we had an efficient dynamically
## scoped variable mechanism it would probably be better to use that
## instead of the global variable that is reset via on.exit.
##
## For now, calls to the timing function snow.time() cannot be nested.

.snowTimingData <- local({
    data <- NULL
    
    timerRunning <- function(run) {
        if (! missing(run)) {
            if (run)
                data <<- list(index = integer(0), data = NULL)
            else data <<- NULL
        }
        ! is.null(data)
    }
    
    incrementIndex <- function(rank) {
        n <- length(data$index)
        if (rank > n)
            data$index <<- c(data$index, rep(0L, rank - n))
        data$index[rank] <<- data$index[rank] + 1L
        data$index[rank]
    }

    getIndex <- function(rank) {
        data$index[rank]
    }

    enterSend <- function(rank, start, end) {
        n <- length(data$data)
        if (rank > n)
            data$data <<- c(data$data, vector(mode = "list", rank - n))
        if (is.null(data$data[[rank]])) {
            d <- matrix(NA_real_, 10, 5)
            colnames(d) <- c("send_start", "send_end",
                             "recv_start", "recv_end", "exec")
            data$data[[rank]] <<- d
        }
        i <- incrementIndex(rank)
        nr <- nrow(data$data[[rank]])
        if (nr < i)
            data$data[[rank]] <<- rbind(data$data[[rank]],
                                        matrix(NA_real_, nr, 5))
        data$data[[rank]][i, 1:2] <<- c(start, end)
    }

    enterRecv <- function(rank, start, end, exec) {
        i <- getIndex(rank)
        data$data[[rank]][i, 3:5] <<- c(start, end, exec)
    }

    extractTimingData <- function()
        lapply(seq_along(data$data),
               function(i) {
                   d <- data$data[[i]]
                   n <- data$index[[i]]
                   if (! is.null(d)) {
                       d <- d[1:n,, drop = FALSE]
                       d[, 3] <- pmax(d[, 3], d[, 2] + d[, 5])
                       d
                   }                                 
               })

    list(running = timerRunning,
         enterSend = enterSend,
         enterRecv = enterRecv,
         extract = extractTimingData)
})

snow.time <- function(expr) {
    if (.snowTimingData$running())
        stop("nested snow.sime calls are currently not supported")
    .snowTimingData$running(TRUE)
    on.exit(.snowTimingData$running(FALSE))
    start <- proc.time()[3]
    expr
    end <- proc.time()[3]
    data <- lapply(.snowTimingData$extract(),
                   function(d) {
                       if (! is.null(d)) {
                           d[,1:4] <- d[,1:4] - start
                           d
                       }
                       else NULL
                   })
    structure(list(elapsed = end - start, data = data),
              class = "snowTimingData")
}

plot.snowTimingData <- function(x, xlab = "Elapsed Time", ylab = "Node",
                                title = "Cluster Usage", ...) {
    w2 <- 0.05
    data <- x$data
    n <- length(data)
    r <- c(0, x$elapsed)
    plot(r, c(0 - w2, max(n, 1) + w2), xlab = xlab, ylab = ylab,
         type = "n", yaxt = "n", ...)
    axis(2, yaxp = c(0, n, max(n, 1)))
    title(title)

    ## show the information for the workers
    for (i in 0 : n) abline(i, 0, lty = 2)
    for (i in seq_along(data)) {
        d <- data[[i]]
        nr <- nrow(d)
        segments(d[, 1], rep(0, nr), d[, 2], rep(i, nr), col = "red")
        rect(d[, 2], rep(i - w2, nr), d[, 2] + d[, 5], rep(i + w2, nr),
             col = "green")
        segments(d[, 2] + d[, 5], rep(i, nr), d[, 3], rep(i, nr), col = "blue")
        segments(d[, 3], rep(i, nr), d[, 4], rep(0, nr), col = "red")
    }

    ## compute and draw the intervals where no worker is active
    if (length(data) > 0) {
        d <- do.call(rbind, data)
        times <- c(d[, 1], d[, 4])
        ord <- order(times)
        cs <- cumsum(rep(c(1,-1), each = nrow(d))[ord])
        st <- sort(times)
        left <- c(0, st[cs == 0])
        right <- c(st[c(1, which(cs[-length(cs)] == 0) + 1)], x$elapsed)
    }
    else {
        left <- 0
        right <- x$elapsed
    }
    rect(left, -w2, right, w2, col = "green")
}

print.snowTimingData <- function(x, ...) {
    data <- x$data
    send <- sum(unlist(lapply(data,
                              function(d)
                                  if (is.null(d)) 0
                                  else sum(d[,2] - d[,1]))))
    recv <- sum(unlist(lapply(data,
                              function(d)
                                  if (is.null(d)) 0
                                  else sum(d[,4] - d[,3]))))
    nodes <- sapply(data, function(d) if (is.null(d)) 0 else sum(d[,5]))
    n <- length(data)
    if (n > 0) nodeNames <- paste("node", 1:n)
    else nodeNames <- character(0)
    y <- structure(c(x$elapsed, send, recv, nodes),
                   names = c("elapsed", "send", "receive", nodeNames))
    print(y)
    invisible(x)
}
