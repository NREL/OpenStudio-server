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

print(paste("order:",order))
print(paste("nboot:",nboot))
print(paste("conf:",conf))
print(paste("type:",type))

results <- NULL
if (type == "sobol") {
  m <- sobol(model=NULL, X1=vars, X2=vars2, order=order, nboot=nboot, conf=conf)
} else if (type == "2002") {
  m <- sobol2002(model=NULL, X1=vars, X2=vars2, nboot=nboot, conf=conf)
} else if (type == "2007") {
  m <- sobol2007(model=NULL, X1=vars, X2=vars2, nboot=nboot, conf=conf)
} else if (type == "jansen") {
  m <- soboljansen(model=NULL, X1=vars, X2=vars2, nboot=nboot, conf=conf)
} else if (type == "mara") {
  m <- sobolmara(model=NULL, X1=vars)
} else if (type == "martinez") {
  m <- sobolmartinez(model=NULL, X1=vars, X2=vars2, nboot=nboot, conf=conf)
} else { print("unknown method")}
print(paste("m:", m))
print(paste("m$X:", m$X))
m1 <- as.list(data.frame(t(m$X)))
print(paste("m1:", m1))
results <- clusterApplyLB(cl, m1, f)
print(mode(as.numeric(results)))
print(is.list(results))
print(paste("results:", as.numeric(results)))
tell(m,as.numeric(results))
print(m)

results_filename <- paste(analysis_dir,'/m.R',sep='')
save(m, file=results_filename)
