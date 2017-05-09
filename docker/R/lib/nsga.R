clusterEvalQ(cl,library(rjson))
clusterEvalQ(cl,library(R.utils))
objDim <- length(objfun)

print(paste("objfun:",objfun))
print(paste("objDim:",objDim))
print(paste("UniqueGroups:",uniquegroups))
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

if (uniquegroups == 1) {
  print(paste("unique groups error:",uniquegroups))
  uniq_filename <- paste(analysis_dir,'/uniquegroups.err',sep='')
  write.table("unique groups", file=uniq_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
  stop(options("show.error.messages"=TRUE),"unique groups is 1")
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
source(paste(r_scripts_path,'create_and_run_datapoint_uniquegroups.R',sep='/'))
clusterExport(cl,"create_and_run_datapoint_uniquegroups")
clusterExport(cl,"check_run_flag")
clusterExport(cl,"check_guideline14")

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

if (nrow(vars) == 1) {
  print("not sure what to do with only one datapoint so adding an NA")
  vars <- rbind(vars, c(NA))
}
if (nrow(vars) == 0) {
  print("not sure what to do with no datapoint so adding an 2 NA's")
  vars <- rbind(vars, c(NA))
  vars <- rbind(vars, c(NA))
}

print(paste("nrow(vars):",nrow(vars)))
print(paste("ncol(vars):",ncol(vars)))

if (ncol(vars) == 1) {
  print("NSGA2 needs more than one variable")
  stop(options("show.error.messages"=TRUE),"NSGA2 needs more than one variable")
}

print(paste("Number of generations set to:",gen))
print(paste("uniquegroups set to:",uniquegroups))
print(paste("vars[] set to:",vars[]))
print(paste("vartypes set to:",vartypes))
print(paste("gen set to:",gen))
print(paste("toursize set to:",toursize))
print(paste("cprob set to:",cprob))
print(paste("xoverdistidx set to:",xoverdistidx))
print(paste("mudistidx set to:",mudistidx))
print(paste("mprob set to:",mprob))

results <- NULL
try(results <- nsga2NREL(cl=cl, fn=f, objDim=uniquegroups, variables=vars[], vartype=vartypes, generations=gen, tourSize=toursize, cprob=cprob, XoverDistIdx=xoverdistidx, MuDistIdx=mudistidx, mprob=mprob), silent=FALSE)

if (debug_messages == 1) {
  whoami <- system('whoami', intern = TRUE)
  print(paste("whoami:", whoami))
}
#for (i in 1:num_uniq_workers) {
#    scp = paste('scp ',whoami,'@',ips2[i],':',analysis_dir,'/best_result.json ',analysis_dir,'/',sep="")
#print(paste("scp command:",scp))
#system(scp,intern=TRUE)
#scp2 <- paste('scp ',whoami,'@',ips2[i],':',analysis_dir,'/convergence_flag.json ',analysis_dir,'/', sep="")
#print(paste("scp2 command:",scp2))
#system(scp2,intern=TRUE)
#}

results_filename <- paste(analysis_dir,'/results.R',sep='')
save(results, file=results_filename)
