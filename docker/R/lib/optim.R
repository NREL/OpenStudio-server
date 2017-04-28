clusterEvalQ(cl,library(rjson))
clusterEvalQ(cl,library(R.utils))
objDim <- length(objfun)

print(paste("objfun:",objfun))
print(paste("objDim:",objDim))
print(paste("normtype:",normtype))
print(paste("ppower:",ppower))
print(paste("min:",mins))
print(paste("max:",maxes))
print(paste("failed_f:",failed_f))

clusterExport(cl,"objDim")
clusterExport(cl,"normtype")
clusterExport(cl,"ppower")

clusterExport(cl,"failed_f")
clusterExport(cl,"debug_messages")

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

# Export functions for worker nodes
source(paste(r_scripts_path,'create_and_run_datapoint.R',sep='/'))
clusterExport(cl,"create_and_run_datapoint")
clusterExport(cl,"check_run_flag")
clusterExport(cl,"check_guideline14")

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
clusterExport(cl,"f")

varMin <- mins
varMax <- maxes
varMean <- (mins+maxes)/2.0
varDomain <- maxes - mins
varEps <- varDomain*epsilongradient
print(paste("varseps:",varseps))
print(paste("varEps:",varEps))
varEps <- ifelse(varseps!=0,varseps,varEps)
print(paste("merged varEps:",varEps))

print("setup gradient")
gn <- f
clusterExport(cl,"gn")
clusterExport(cl,"varEps")

vectorGradient <- function(x, ...) { # Now use the cluster
  vectorgrad(func=gn, x=x, method="two", eps=varEps,cl=cl, debug=TRUE, ub=varMax, lb=varMin);
}
print(paste("Lower Bounds set to:",varMin))
print(paste("Upper Bounds set to:",varMax))
print(paste("Initial iterate set to:",varMean))
print(paste("Length of variable domain:",varDomain))
print(paste("factr set to:",factr))
print(paste("pgtol set to:",pgtol))

options(digits=8)
options(scipen=-2)

results <- NULL
try(results <- optim(par=varMean, fn=f, gr=vectorGradient, method='L-BFGS-B',lower=varMin, upper=varMax, control=list(trace=6, factr=factr, maxit=maxit, pgtol=pgtol)), silent = FALSE)
print(paste("results:",results))
#print(paste("ip workers:", ips))
#print(paste("ip master:", master_ips))
#ips2 <- ips[ips!=master_ips]
#print(paste("non server ips:", ips2))
#num_uniq_workers <- length(ips2)
#whoami <- system('whoami', intern = TRUE)
#print(paste("whoami:", whoami))
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
#Iteration <- length(Rlog[grep('Iteration',Rlog)]) - 1
# print(Rlog[grep('L =',Rlog)])
# print(Rlog[grep('X0 =',Rlog)])
# print(Rlog[grep('U =',Rlog)])
# Xlog <- Rlog[grep('X =',Rlog)]
# print("Iteration parameters:")
# print(Xlog[-grep('Cauchy',Xlog)])
# print(Rlog[grep('norm of step',Rlog)])
# print(Rlog[grep('Objective function Norm',Rlog)])
#print(paste("Iterations:",Iteration))
print(paste("message:",results$message))
print(paste("convergence:",results$convergence))
print(paste("counts:",results$counts))
print(paste("par:",results$par))
print(paste("value:",results$value))
flush.console()
results_filename <- paste(analysis_dir,'/results.R',sep='')
save(results, file=results_filename)
