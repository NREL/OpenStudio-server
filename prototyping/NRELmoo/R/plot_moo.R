
plot_objectives <- function(objectives_save, objDim){
    objectives_plot <- objectives_save[,1:(objDim)]
    plot(objectives_plot, xlim=c(min(na.omit(objectives_save[,1])),max(na.omit(objectives_save[,1]))), ylim=c(min(na.omit(objectives_save[,2])),max(na.omit(objectives_save[,2]))))
    
    if (ncol(objectives_save)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}
      
    plot_length <- ncol(objectives_save)%/%objDim
    for (i in 2:(plot_length)){
        objectives_plot <- objectives_save[,((i-1)*objDim+1):(objDim*i)]
        points(objectives_plot)
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