
plot_objectives <- function(objectives_save, objDim){ 
   
    if (ncol(objectives_save)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}
      
    plot_length <- ncol(objectives_save)%/%objDim

    xbounds = objectives_save[,1]
    ybounds = objectives_save[,2]  
    for (i in 2:(plot_length)){
        xbounds = rbind(xbounds,objectives_save[,((i-1)*objDim+1)])
        ybounds = rbind(ybounds,objectives_save[,(objDim*i)])
    }
    objectives_plot <- objectives_save[,1:(objDim)]
    plot(objectives_plot, xlim=c(min(na.omit(xbounds)),max(na.omit(xbounds))), ylim=c(min(na.omit(ybounds)),max(na.omit(ybounds))))

    for (i in 2:(plot_length)){
        objectives_plot <- objectives_save[,((i-1)*objDim+1):(objDim*i)]
        points(objectives_plot)
        Sys.sleep(1.0)
    }
}
   
compplot_objectives <- function(obj1, obj2, objDim){ 
   
    if (ncol(obj1)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}
    if (ncol(obj2)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}  
      
    plot_length <- min(ncol(obj1)%/%objDim, ncol(obj2)%/%objDim)

    xbounds = obj1[,1]
    xbounds = rbind(xbounds, obj2[,1])
    ybounds = obj1[,2]
    ybounds = rbind(ybounds, obj2[,2])
    for (i in 2:(plot_length)){
        xbounds = rbind(xbounds,obj1[,((i-1)*objDim+1)])
        xbounds = rbind(xbounds,obj2[,((i-1)*objDim+1)])
        ybounds = rbind(ybounds,obj1[,(objDim*i)])
        ybounds = rbind(ybounds,obj2[,(objDim*i)])
    }
    objectives_plot <- obj1[,1:(objDim)]
    plot(objectives_plot,pch=16,xlim=c(min(na.omit(xbounds)),max(na.omit(xbounds))), ylim=c(min(na.omit(ybounds)),max(na.omit(ybounds))))
    objectives_plot <- obj1[,1:(objDim)]
    points(objectives_plot,col="red",pch=16)
    for (i in 2:(plot_length)){
        objectives_plot <- obj1[,((i-1)*objDim+1):(objDim*i)]
        points(objectives_plot,pch=16)
        objectives_plot <- obj2[,((i-1)*objDim+1):(objDim*i)]
        points(objectives_plot,col="red",pch=16)
        Sys.sleep(1.0)
    }
}   
   
   
plot_parameters <- function(parameters_save, noVars){
   parameters_plot <- parameters_save[,1:(noVars)]
   plot(parameters_plot, xlim=c(min(na.omit(parameters_save[,1])),max(na.omit(parameters_save[,1]))), ylim=c(min(na.omit(parameters_save[,2])),max(na.omit(parameters_save[,2]))))
    
   if (ncol(objectives_save)%%noVars != 0) {
      print("save object not multiple of number of variables")
      stop}
      
   plot_length <- ncol(objectives_save)%/%noVars
    
   for (i in 2:(plot_length)){
     parameters_plot <- parameters_save[,((i-1)*noVars+1):(noVars*i)]
     points(parameters_plot)
     Sys.sleep(1.0)
   }
}   