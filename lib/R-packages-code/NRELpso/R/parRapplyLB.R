splitIndicies <- function(nx, ncl) {
    i <- seq_len(nx)
    if (ncl == 0L) list()
    else if (ncl == 1L || nx == 1L) list(i)
    else {
        fuzz <- min((nx - 1L) / 1000, 0.4 * nx / ncl)
        breaks <- seq(1 - fuzz, nx + fuzz, length = ncl + 1L)
        structure(split(i, cut(i, breaks)), names = NULL)
    }
}

#internal
splitRow <- function(x, ncl)
    lapply(splitIndicies(nrow(x), ncl), function(i) x[i, , drop=FALSE])

parRapplyLB <- function(cl = NULL, x, FUN, ...)
{
    #cl <- defaultCluster(cl)
    do.call(c,
            parallel::clusterApplyLB(cl = cl, x = splitRow(x,nrow(x)),
                         fun = apply, MARGIN = 1L, FUN = FUN, ...),
            quote = TRUE)
}