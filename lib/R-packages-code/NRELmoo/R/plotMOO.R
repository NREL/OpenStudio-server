
plotObjectives <- function(objectivesSave, objDim){ 
   
    if (ncol(objectivesSave)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}
      
    plotLength <- ncol(objectivesSave)%/%objDim

    xbounds = objectivesSave[,1]
    ybounds = objectivesSave[,2]  
    for (i in 2:(plotLength)){
        xbounds = rbind(xbounds,objectivesSave[,((i-1)*objDim+1)])
        ybounds = rbind(ybounds,objectivesSave[,(objDim*i)])
    }
    objPlot <- objectivesSave[,1:(objDim)]
    plot(objPlot, xlim=c(min(na.omit(xbounds)),max(na.omit(xbounds))), ylim=c(min(na.omit(ybounds)),max(na.omit(ybounds))))

    for (i in 2:(plotLength)){
        objPlot <- objectivesSave[,((i-1)*objDim+1):(objDim*i)]
        points(objPlot)
        Sys.sleep(1.0)
    }
}
   
compPlotObjectives <- function(obj1, obj2, objDim){ 
   
    if (ncol(obj1)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}
    if (ncol(obj2)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}  
      
    plotLength <- min(ncol(obj1)%/%objDim, ncol(obj2)%/%objDim)

    xbounds = obj1[,1]
    xbounds = rbind(xbounds, obj2[,1])
    ybounds = obj1[,2]
    ybounds = rbind(ybounds, obj2[,2])
    for (i in 2:(plotLength)){
        xbounds = rbind(xbounds,obj1[,((i-1)*objDim+1)])
        xbounds = rbind(xbounds,obj2[,((i-1)*objDim+1)])
        ybounds = rbind(ybounds,obj1[,(objDim*i)])
        ybounds = rbind(ybounds,obj2[,(objDim*i)])
    }
    objPlot <- obj1[,1:(objDim)]
    plot(objPlot,pch=16,xlim=c(min(na.omit(xbounds)),max(na.omit(xbounds))), ylim=c(min(na.omit(ybounds)),max(na.omit(ybounds))))
    objPlot <- obj1[,1:(objDim)]
    points(objPlot,col="red",pch=16)
    for (i in 2:(plotLength)){
        objPlot <- obj1[,((i-1)*objDim+1):(objDim*i)]
        points(objPlot,pch=16)
        objPlot <- obj2[,((i-1)*objDim+1):(objDim*i)]
        points(objPlot,col="red",pch=16)
        Sys.sleep(1.0)
    }
}   

#saveGIF(plot_obj(results$objectives_save,2,40),video.name="NSGA2.gif",img.name="NSGA",convert="convert",interval=0.25)
compPlotObjectivesGIF <- function(obj1, obj2, objDim){ 
   
    if (ncol(obj1)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}
    if (ncol(obj2)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}  
      
    plotLength <- min(ncol(obj1)%/%objDim, ncol(obj2)%/%objDim)

    xbounds = obj1[,1]
    xbounds = rbind(xbounds, obj2[,1])
    ybounds = obj1[,2]
    ybounds = rbind(ybounds, obj2[,2])
    for (i in 2:(plotLength)){
        xbounds = rbind(xbounds,obj1[,((i-1)*objDim+1)])
        xbounds = rbind(xbounds,obj2[,((i-1)*objDim+1)])
        ybounds = rbind(ybounds,obj1[,(objDim*i)])
        ybounds = rbind(ybounds,obj2[,(objDim*i)])
    }
    for (j in 2:(plotLength)){
      objPlot <- obj1[,1:(objDim)]
      plot(objPlot,pch=16,xlim=c(min(na.omit(xbounds)),max(na.omit(xbounds))), ylim=c(min(na.omit(ybounds)),max(na.omit(ybounds))))
      objPlot <- obj1[,1:(objDim)]
      points(objPlot,col="red",pch=16)
      for (i in 2:j){
          objPlot <- obj1[,((i-1)*objDim+1):(objDim*i)]
          points(objPlot,pch=16)
          objPlot <- obj2[,((i-1)*objDim+1):(objDim*i)]
          points(objPlot,col="red",pch=16)
      }
    }
}    


plotObjectivesGIF <- function(objectivesSave, objDim){ 
   
    if (ncol(objectivesSave)%%objDim != 0) {
      print("save object not multiple of objective dimension")
      stop}
      
    plotLength <- ncol(objectivesSave)%/%objDim

    xbounds = objectivesSave[,1]
    ybounds = objectivesSave[,2]  
    for (i in 2:(plotLength)){
        xbounds = rbind(xbounds,objectivesSave[,((i-1)*objDim+1)])
        ybounds = rbind(ybounds,objectivesSave[,(objDim*i)])
    }
    for (j in 2:(plotLength)){
      objPlot <- objectivesSave[,1:(objDim)]
      plot(objPlot, xlim=c(min(na.omit(xbounds)),max(na.omit(xbounds))), ylim=c(min(na.omit(ybounds)),max(na.omit(ybounds))))

      for (i in 2:j){
          objPlot <- objectivesSave[,((i-1)*objDim+1):(objDim*i)]
          points(objPlot)
      }
    }
}
   
plotParameters <- function(parametersSave, noVars){
   paramPlot <- parametersSave[,1:(noVars)]
   plot(paramPlot, xlim=c(min(na.omit(parametersSave[,1])),max(na.omit(parametersSave[,1]))), ylim=c(min(na.omit(parametersSave[,2])),max(na.omit(parametersSave[,2]))))
    
   if (ncol(objectivesSave)%%noVars != 0) {
      print("save object not multiple of number of variables")
      stop}
      
   plotLength <- ncol(objectivesSave)%/%noVars
    
   for (i in 2:(plotLength)){
     paramPlot <- parametersSave[,((i-1)*noVars+1):(noVars*i)]
     points(paramPlot)
     Sys.sleep(1.0)
   }
}   