# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# clusterEvalQ(cl,library(rjson))
# clusterEvalQ(cl,library(R.utils))
objDim <- length(objfun)

print(paste("objfun:",objfun))
print(paste("objDim:",objDim))
print(paste("normtype:",normtype))
print(paste("ppower:",ppower))
mins <- mins * 1.0
print(paste("min:",mins))
maxes <- maxes * 1.0
print(paste("max:",maxes))
print(paste("failed_f:",failed_f))

# clusterExport(cl,"objDim")
# clusterExport(cl,"normtype")
# clusterExport(cl,"ppower")

# clusterExport(cl,"failed_f")
# clusterExport(cl,"debug_messages")

print(paste("vartypes:",vartypes))
print(paste("varnames:",varnames))

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

# Export local variables for worker nodes
# clusterExport(cl,"ruby_command")
# clusterExport(cl,"rake_command")
# clusterExport(cl,"analysis_dir")
# clusterExport(cl,"varfile")
# clusterExport(cl,"varnames")

# Export some global variables for worker nodes
# clusterExport(cl,"rails_analysis_id")
# clusterExport(cl,"rails_sim_root_path")
# clusterExport(cl,"rails_ruby_bin_dir")
# clusterExport(cl,"rails_mongodb_name")
# clusterExport(cl,"rails_mongodb_ip")
# clusterExport(cl,"rails_run_filename")
# clusterExport(cl,"rails_create_dp_filename")
# clusterExport(cl,"rails_root_path")
# clusterExport(cl,"rails_host")
# clusterExport(cl,"r_scripts_path")
# clusterExport(cl,"rails_exit_guideline_14")
# clusterEvalQ(cl,varfile(varnames))

# Export functions for worker nodes
source(paste(r_scripts_path,'create_and_run_datapoint.R',sep='/'))
# clusterExport(cl,"create_and_run_datapoint")
# clusterExport(cl,"check_run_flag")
# clusterExport(cl,"check_guideline14")

#f <- function(x){
#  tryCatch(create_and_run_datapoint(x),
#            error=function(x){
#              obj <- NULL
#              for (i in 1:objDim) {
#                obj[i] <- failed_f
#              }
#              print("create_and_run_datapoint failed")
#              return(obj)
#            }
#          )
#}
f <- function(x){
  try(create_and_run_datapoint(x), silent=TRUE)
}
#clusterExport(cl,"f")

varMin <- mins
varMax <- maxes
varMean <- (mins+maxes)/2.0
varDomain <- maxes - mins
varEps <- varDomain*epsilongradient
print(paste("varseps:",varseps))
print(paste("varEps:",varEps))
varEps <- ifelse(varseps!=0,varseps,varEps)
print(paste("merged varEps:",varEps))
varDom <- cbind(varMin,varMax)
print(paste("varDom:",varDom))

print("setup gradient")
gn <- f
#clusterExport(cl,"gn")
#clusterExport(cl,"varEps")

vectorGradient <- function(x, ...) { # Now use the cluster
  vectorgrad(func=gn, x=x, method="two", eps=varEps,cl=cl, debug=TRUE, ub=varMax, lb=varMin);
}

print(paste("Lower Bounds set to:",varMin))
print(paste("Upper Bounds set to:",varMax))
print(paste("Initial iterate set to:",varMean))
print(paste("Length of variable domain:",varDomain))
print(paste("run:",run))
print(paste("popSize:",popSize))
print(paste("maxFitness:",maxFitness))
print(paste("maxiter:",maxiter))
print(paste("pcrossover:",pcrossover))
print(paste("pmutation:",pmutation))
print(paste("elitism %:",elitism))
elitism <- max(1, round(popSize*elitism))
print(paste("elitism #:",elitism))
print(paste("numIslands:",numIslands))
print(paste("migrationRate:",migrationRate))
print(paste("migrationInterval:",migrationInterval))
print(paste("numCores:",length(ips)))

fmin <- function(x) - f(x)
results <- NULL
try(results <- gaisl(type = 'real-valued', fitness=fmin, min=varMin, max=varMax, numIslands=numIslands, migrationRate=migrationRate, migrationInterval=migrationInterval, popSize=popSize, pcrossover=pcrossover, pmutation=pmutation, elitism=elitism, maxiter=maxiter, run=run, maxFitness=(-1*maxFitness), names=varnames, monitor=TRUE, numCores=length(ips)), silent=FALSE)
print("summary(results):")
print(summary(results))
# TODO: how to get best result back in docker space? API? What is the server? 
#print(paste("scp command:",scp))
#print(paste("scp command:",scp2))
#system(scp,intern=TRUE)
#system(scp2,intern=TRUE)
#print(paste("ip workers:", ips))
#print(paste("ip master:", master_ips))
#ips2 <- ips[ips!=master_ips]
#print(paste("non server ips:", ips2))
#num_uniq_workers <- length(ips2)
whoami <- system('whoami', intern = TRUE)
print(paste("whoami:", whoami))
#for (i in 1:num_uniq_workers){
#  scp <- paste('scp ',whoami,'@',ips2[i],':#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/best_result.json #{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/', sep="")
#  print(paste("scp command:",scp))
#  system(scp,intern=TRUE)
#  scp2 <- paste('scp ',whoami,'@',ips2[i],':#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/convergence_flag.json #{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/', sep="")
#  print(paste("scp2 command:",scp2))
#  system(scp2,intern=TRUE)
#}

#TODO get results from Rserve.log -- Where does it live??
#Rlog <- readLines('/var/www/rails/openstudio/log/Rserve.log')
#Rlog[grep('vartypes:',Rlog)]
#Rlog[grep('varnames:',Rlog)]
#Rlog[grep('<=',Rlog)]
# print(paste("popsize:",results$pop.size))
# print(paste("peakgeneration:",results$peakgeneration))
# print(paste("generations:",results$generations))
# print(paste("gradients:",results$gradients))
# print(paste("par:",results$par))
# print(paste("value:",results$value))
flush.console()
results_filename <- paste(analysis_dir,'/results.R',sep='')
save(results, file=results_filename)
bestresults_filename <- paste(analysis_dir,'/best_result.json',sep='')
if (!file.exists(bestresults_filename) && !is.null(summary(results)$solution)) {
  #write final params to json file
  answer <- paste('{',paste('"',gsub(".","|",varnames, fixed=TRUE),'"',': ',summary(results)$solution,sep='', collapse=','),'}',sep='')
  write.table(answer, file=bestresults_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
  convergenceflag <- paste('{',paste('"',"exit_on_guideline_14",'"',': ',"false",sep='', collapse=','),'}',sep='')
  write(convergenceflag, file=paste(analysis_dir,"/convergence_flag.json",sep=''))
}
