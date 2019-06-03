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


print(paste("n:",n))
print(paste("M:",M))

if (n <= (4*M^2+1)) {
  n <- (4*M^2) + 2
  print("n is <= 4*M^2, increasing the value of n")
  print(paste("n:",n))
}

temp_list <- list()
if (length(mins) > 0) {
  for (i in 1:length(mins))
  {
    temp_list[[i]] <- list(min= mins[i], max=maxes[i])
  }
}
  
results <- NULL
# if (length(unique(vardisplaynames)) == length(vardisplaynames)) {
  # m <- fast99(model=NULL, factors=vardisplaynames, n=n, M=M, q.arg = temp_list)
# } else if (length(unique(varnames)) == length(varnames)) {
  # m <- fast99(model=NULL, factors=varnames, n=n, M=M, q.arg = temp_list)
# } else {
  m <- fast99(model=NULL, factors=ncol(vars), n=n, M=M, q.arg = temp_list)
#}
m1 <- as.list(data.frame(t(m$X)))
if (debug_messages == 1) {
  print(paste("m1:",m1))
}
try(results <- clusterApplyLB(cl, m1, f),silent=FALSE)

 result <- as.data.frame(results)
 if (debug_messages == 1) {
  print(paste("length(objnames):",length(objnames)))
  print(paste("nrow(result):",nrow(result)))
  print(paste("ncol(result):",ncol(result)))
 }
 file_names_R <- c("")
 file_names_bar_png <- c("")
 
if (nrow(result) > 0) {
   for (j in 1:nrow(result)){

     n <- m
     tell(n,as.numeric(unlist(result[j,])))
     print(n)
     file_names_R[j] <- paste(analysis_dir,"/m_",gsub(" ","_",objnames[j], fixed=TRUE),".RData",sep="")
     save(n, file=file_names_R[j])

     file_names_bar_png[j] <- paste(analysis_dir,"/fast99_",gsub(" ","_",objnames[j],fixed=TRUE),"_bar.png",sep="")
     png(file_names_bar_png[j], width=12, height=8, units="in", pointsize=10, res=200, type="cairo")
     op <- par(mar = c(14,4,4,2) + 0.1)
     if (! is.null(n$y)) {
      S <- rbind(n$D1 / n$V, 1 - n$Dt / n$V - n$D1 / n$V)
      colnames(S) <- vardisplaynames
      bar.col <- c("white","grey")
      mp <- barplot(S, ylim = c(0,1), col = bar.col, , xaxt="n")
      axis(1, at=mp, labels=vardisplaynames, las=2, cex.axis=0.9)
      legend("topright", c("main effect", "interactions"), fill = bar.col)
     }
     dev.off()

     #file_zip <- c(file_names_jsons,file_names_R,file_names_bar_png,file_names_bar_sorted_png,file_names_png,file_names_box_png,file_names_box_sorted_png,paste(analysis_dir,"/vardisplaynames.json",sep=''))
     file_zip <- c(file_names_R,file_names_bar_png,paste(analysis_dir,"/vardisplaynames.json",sep=''))
     if (debug_messages == 1) {
      print(paste("file_zip:",file_zip))
     }
     if(!dir.exists(paste(analysis_dir,"/downloads",sep=''))){
       dir.create(paste(analysis_dir,"/downloads",sep=''))
       print(paste("created dir:",analysis_dir,"/downloads",sep=''))
     }
     zip(zipfile=paste(analysis_dir,"/downloads/fast99_results_",rails_analysis_id,".zip",sep=''),files=file_zip, flags = "-j")
  
   }
 } else {
   print("Results is null")
 }
