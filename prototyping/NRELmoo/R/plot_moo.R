
plot_objectives <- function(objectives_save, objDim, gen){
   objectives_plot <- objectives_save[,1:(objDim)]
   plot(objectives_plot, xlim=c(min(objectives_save[,1]),max(objectives_save[,1])), ylim=c(min(objectives_save[,2]),max(objectives_save[,2])))
   
   for (i in 2:(gen+1)){
     objectives_plot <- objectives_save[,((i-1)*objDim+1):(objDim*i)]
     points(objectives_plot)
     Sys.sleep(1.0)
   }
}
   
plot_parameters <- function(parameters_save, noVars, gen){
   parameters_plot <- parameters_save[,1:(noVars)]
   plot(parameters_plot, xlim=c(min(parameters_save[,1]),max(parameters_save[,1])), ylim=c(min(parameters_save[,2]),max(parameters_save[,2])))

   for (i in 2:(gen+1)){
     parameters_plot <- parameters_save[,((i-1)*noVars+1):(noVars*i)]
     points(parameters_plot)
     Sys.sleep(1.0)
   }
}   