# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

clusterEvalQ(cl,library(rjson))
clusterEvalQ(cl,library(R.utils))
objDim <- length(objfun)

print(paste("objDim:",objDim))
print(paste("UniqueGroups:",uniquegroups))
print(paste("objfun:",objfun))
print(paste("normtype:",normtype))
print(paste("ppower:",ppower))
print(paste("min:",mins))
print(paste("max:",maxes))
print(paste("failed_f:",failed_f))

clusterExport(cl,"objDim")
clusterExport(cl,"normtype")
clusterExport(cl,"ppower")
clusterExport(cl,"uniquegroups")
clusterExport(cl,"failed_f")
clusterExport(cl,"debug_messages")

for (i in 1:ncol(vars)){
  vars[,i] <- sort(vars[,i])
}
print(paste("vartypes:",vartypes))
print(paste("varnames:",varnames))
print(paste("vardisplaynames:",vardisplaynames))
print(paste("objnames:",objnames))

# Setup a bunch of variables for the analysis based on passed variables
# From Ruby
analysis_dir <- paste(rails_sim_root_path,'/analysis_',rails_analysis_id,sep='')
ruby_command <- paste('cd ',analysis_dir,' && ',rails_ruby_bin_dir,'/bundle exec ruby ',sep='')
rake_command <- paste('cd ',rails_root_path,' && ',rails_ruby_bin_dir,'/bundle exec rake ',sep='')
if (debug_messages == 1) {
  print(paste("analysis_dir: ",analysis_dir))
  print(paste("ruby_command: ",ruby_command))
  print(paste("rake_command: ",rake_command))
}

varfile <- function(x){
  var_filename <- paste(analysis_dir,'/varnames.json',sep='')
  if (!file.exists(var_filename)){
    write.table(x, file=var_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
  }
}

vardisplayfile <- function(x){
  var_filename <- paste(analysis_dir,'/vardisplaynames.json',sep='')
  if (!file.exists(var_filename)){
    write.table(x, file=var_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
  }
}

# Export local variables for worker nodes
clusterExport(cl,"ruby_command")
clusterExport(cl,"rake_command")
clusterExport(cl,"analysis_dir")
clusterExport(cl,"varfile")
clusterExport(cl,"varnames")

# Export some global variables for worker nodes
clusterExport(cl,"rails_analysis_id")
clusterExport(cl,"rails_sim_root_path")
clusterExport(cl,"rails_ruby_bin_dir")
clusterExport(cl,"rails_mongodb_name")
clusterExport(cl,"rails_mongodb_ip")
clusterExport(cl,"rails_run_filename")
clusterExport(cl,"rails_create_dp_filename")
clusterExport(cl,"rails_root_path")
clusterExport(cl,"rails_host")
clusterExport(cl,"r_scripts_path")
clusterExport(cl,"rails_exit_guideline_14")
clusterEvalQ(cl,varfile(varnames))
clusterExport(cl,"vardisplayfile")
clusterExport(cl,"vardisplaynames")
clusterEvalQ(cl,vardisplayfile(vardisplaynames))

# Export functions for worker nodes
source(paste(r_scripts_path,'create_and_run_datapoint_uniquegroups.R',sep='/'))
clusterExport(cl,"create_and_run_datapoint_uniquegroups")
clusterExport(cl,"check_run_flag")

#f <- function(x){
#  tryCatch(create_and_run_datapoint_uniquegroups(x),
#            error=function(x){
#              obj <- NULL
#              for (i in 1:objDim) {
#                obj[i] <- failed_f
#              }
#              print("create_and_run_datapoint_uniquegroups failed")
#              return(obj)
#            }
#          )
#}
f <- function(x){
  try(create_and_run_datapoint_uniquegroups(x), silent=TRUE)
}
clusterExport(cl,"f")

print(paste("levels:",levels))
print(paste("r:",r))
print(paste("r2:",r2))
print(paste("grid_jump:",grid_jump))
print(paste("type:",type))
print(paste("check_boundary:",check_boundary))

if (r2 > r) {
  r <- c(r,r2)
}  else {
  print("r2 is <= r so not using the Campolongo space filling improvement")
}
print(paste("r:",r))
  
results <- NULL
m <- morris(model=NULL, factors=ncol(vars), r=r, design = list(type=type, levels=levels, grid.jump=grid_jump), binf = mins, bsup = maxes, scale=TRUE)

m1 <- as.list(data.frame(t(m$X)))
if (debug_messages == 1) {
  print(paste("m1:",m1))
}
if (check_boundary == 1) {
  print("check bounds")
  boundary_check <- logical(ncol(vars))
  for (i in 1:ncol(vars)){
    boundary_check[i] <- all((m$X[,i] <= maxes[i]) && (m$X[,i] >= mins[i]))
  }
  if(!all(boundary_check)){
    print('SOLUTION SPACE OUT OF BOUNDS, CHECK Grid Jump and Level Values and/or re-run')
    stop(options("show.error.messages"=TRUE),"SOLUTION SPACE OUT OF BOUNDS, CHECK Grid Jump and Level Values and/or re-run")
  }
  print("bounds are satisfied, continuing...")
}
try(results <- clusterApplyLB(cl, m1, f),silent=FALSE)
if (debug_messages == 1) {
  print(paste("nrow(results):",nrow(results)))
  print(paste("ncol(results):",ncol(results)))
}
result <- as.data.frame(results)
if (debug_messages == 1) {
  print(paste("length(objnames):",length(objnames)))
  print(paste("nrow(result):",nrow(result)))
  print(paste("ncol(result):",ncol(result)))
}
file_names_jsons <- c("")
file_names_R <- c("")
file_names_png <- c("")
file_names_box_png <- c("")
file_names_box_sorted_png <- c("")
file_names_bar_png <- c("")
file_names_bar_sorted_png <- c("")
total_answer <- '{"Morris":{'
if (nrow(result) > 0) {
  for (j in 1:nrow(result)){
    #print(paste("result[j,]:",unlist(result[j,])))
    #print(paste("result[,j]:",unlist(result[,j])))
    n <- m
    tell(n,as.numeric(unlist(result[j,])))
    print(n)
    #print(paste("is.recursive(n):",is.recursive(n)))
    #print(paste("is.atomic(n):",is.atomic(n)))
    var_mu <- rep(0, ncol(vars))
    var_mu_star <- var_mu
    var_sigma <- var_mu
    for (i in 1:ncol(vars)){
      var_mu[i] <- mean(n$ee[,i])
      var_mu_star[i] <- mean(abs(n$ee[,i]))
      var_sigma[i] <- sd(n$ee[,i])
    }
    answer <- paste('"',gsub(" ","_",objnames[j],fixed=TRUE),'":{',paste('"',gsub(".","|",varnames, fixed=TRUE),'":','{"var_mu": ',var_mu,',"var_mu_star": ',var_mu_star,',"var_sigma": ',var_sigma,'}',sep='', collapse=','),'}',sep='')
    #answer <- paste('{',paste('"',gsub(".","|",varnames, fixed=TRUE),'":','{"var_mu": ',var_mu,',"var_mu_star": ',var_mu_star,',"var_sigma": ',var_sigma,'}',sep='', collapse=','),'}',sep='')
    if (j < nrow(result)) {
      total_answer <- paste(total_answer,answer,',',sep="")
    } else {
      total_answer <- paste(total_answer,answer)
    }
    file_names_jsons[j] <- paste(analysis_dir,"/morris_",gsub(" ","_",objnames[j],fixed=TRUE),".json",sep="")
    write.table(answer, file=file_names_jsons[j], quote=FALSE,row.names=FALSE,col.names=FALSE)
    file_names_R[j] <- paste(analysis_dir,"/m_",gsub(" ","_",objnames[j], fixed=TRUE),".RData",sep="")
    save(n, file=file_names_R[j])
    if (all(is.finite(var_mu_star))) {
      file_names_png[j] <- paste(analysis_dir,"/morris_",gsub(" ","_",objnames[j],fixed=TRUE),"_sigma_mu.png",sep="")
      png(file_names_png[j], width=8, height=8, units="in", pointsize=10, res=200, type="cairo")
      plot(n)
      #axis(1, las=2)
      #axis(2, las=1)
      dev.off()

      file_names_bar_png[j] <- paste(analysis_dir,"/morris_",gsub(" ","_",objnames[j],fixed=TRUE),"_bar.png",sep="")
      png(file_names_bar_png[j], width=8, height=8, units="in", pointsize=10, res=200, type="cairo")
      op <- par(mar = c(14,4,4,2) + 0.1)
      mp <- barplot(height=var_mu_star, ylab="mu.star", main="Mu Star of Elementary Effects", xaxt="n")
      axis(1, at=mp, labels=vardisplaynames, las=2, cex.axis=0.9)
      #axis(2, las=1)
      dev.off()
      #sorted
      file_names_bar_sorted_png[j] <- paste(analysis_dir,"/morris_",gsub(" ","_",objnames[j],fixed=TRUE),"_bar_sorted.png",sep="")
      png(file_names_bar_sorted_png[j], width=8, height=8, units="in", pointsize=10, res=200, type="cairo")
      op <- par(mar = c(14,4,4,2) + 0.1)
      mp <- barplot(height=sort(var_mu_star), ylab="mu.star", main="Mu Star of Elementary Effects", xaxt="n")
      axis(1, at=mp, labels=vardisplaynames[order(var_mu_star)], las=2, cex.axis=0.9)
      #axis(2, las=1)
      dev.off()

      file_names_box_png[j] <- paste(analysis_dir,"/morris_",gsub(" ","_",objnames[j],fixed=TRUE),"_box.png",sep="")
      png(file_names_box_png[j], width=8, height=8, units="in", pointsize=10, res=200, type="cairo")
      bottommar <- max(strwidth(vardisplaynames[which.max(nchar(vardisplaynames))], "inch")+0.1, na.rm = TRUE)
      leftmar <- max(strwidth(nchar(max(n$ee)), "inch")+0.25, na.rm = TRUE)
      par(mai=c(bottommar,leftmar, 0.25,0.25))
      mp <- boxplot(n$ee, las=2, names=vardisplaynames, cex.axis=0.9, main="BoxPlot of Elementary Effects", ylab=paste("EE of",objnames[j]))
      axis(1, at=seq(1,length(vardisplaynames)), labels=vardisplaynames, las=2, cex.axis=0.9)
      dev.off()
      
      file_names_box_sorted_png[j] <- paste(analysis_dir,"/morris_",gsub(" ","_",objnames[j],fixed=TRUE),"_box_sorted.png",sep="")
      png(file_names_box_sorted_png[j], width=8, height=8, units="in", pointsize=10, res=200, type="cairo")
      bottommar <- max(strwidth(vardisplaynames[which.max(nchar(vardisplaynames))], "inch")+0.1, na.rm = TRUE)
      leftmar <- max(strwidth(nchar(max(n$ee)), "inch")+0.25, na.rm = TRUE)
      par(mai=c(bottommar,leftmar, 0.25,0.25))
      mp <- boxplot(n$ee[,order(colMeans(abs(n$ee)))], las=2, names=vardisplaynames[order(var_mu_star)], cex.axis=0.9, main="BoxPlot of Elementary Effects", ylab=paste("EE of",objnames[j]))
      axis(1, at=seq(1,length(vardisplaynames)), labels=vardisplaynames[order(var_mu_star)], las=2, cex.axis=0.9)
      dev.off()
      file_zip <- c(file_names_jsons,file_names_R,file_names_bar_png,file_names_bar_sorted_png,file_names_png,file_names_box_png,file_names_box_sorted_png,paste(analysis_dir,"/vardisplaynames.json",sep=''))

      #file_zip <- c(file_names_jsons,file_names_R,file_names_bar_png,file_names_bar_sorted_png,file_names_png,file_names_box_png,paste(analysis_dir,"/vardisplaynames.json",sep=''))
    } else {
      file_zip <- c(file_names_jsons,file_names_R,paste(analysis_dir,"/vardisplaynames.json",sep=''))
    }
    }# here
    total_answer <- paste(total_answer,'}}')
    bestresults_filename <- paste(analysis_dir,'/best_result.json',sep='')
    print(bestresults_filename)
    print(paste("best json:",total_answer))
    write.table(total_answer, file=bestresults_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
    file_zip <- append(file_zip,bestresults_filename)
    if (debug_messages == 1) {
      print(paste("file_zip:",file_zip))
    }
    if(!dir.exists(paste(analysis_dir,"/downloads",sep=''))){
      dir.create(paste(analysis_dir,"/downloads",sep=''))
      print(paste("created dir:",analysis_dir,"/downloads",sep=''))
    }
    zip(zipfile=paste(analysis_dir,"/downloads/morris_results_",rails_analysis_id,".zip",sep=''),files=file_zip, flags = "-j")
  #} #move this?
} else {
  print("Results is null")
}
