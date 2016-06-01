clusterEvalQ(cl,library(RMongo))
clusterEvalQ(cl,library(rjson))
clusterEvalQ(cl,library(R.utils))

print(system('whoami', intern = TRUE))
print(system('which ruby', intern = TRUE))
print(paste("objfun:",objfun))
objDim <- length(objfun)
print(paste("objDim:",objDim))
print(paste("UniqueGroups:",uniquegroups))
print(paste("normtype:",normtype))
print(paste("ppower:",ppower))

print(paste("min:",mins))
print(paste("max:",maxes))

clusterExport(cl,"objDim")
clusterExport(cl,"normtype")
clusterExport(cl,"ppower")
clusterExport(cl,"uniquegroups")

for (i in 1:ncol(vars)){
    vars[,i] <- sort(vars[,i])
}
print(paste("vartypes:",vartypes))
print(paste("varnames:",varnames))

# Setup a bunch of variables for the analysis based on passed variables
# From Ruby
analysis_dir = paste(rails_sim_root_path,'/analysis_',rails_analysis_id,sep='')
ruby_command = paste('cd ',analysis_dir,' && ',rails_ruby_bin_dir,'/bundle exec ruby ',sep='')
rake_command = paste('cd ',rails_root_path,' && ',rails_ruby_bin_dir,'/bundle exec rake ',sep='')

varfile = function(x){
    var_filename = paste(analysis_dir,'/varnames.json',sep='')
    if (!file.exists(var_filename)){
        write.table(x, file=var_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
    }
}

if (uniquegroups == 1) {
    print(paste("unique groups error:",uniquegroups))
    uniq_filename = paste(analysis_dir,'/uniquegroups.err')
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
source(paste(r_scripts_path,'create_and_run_datapoint.R',sep='/'))
clusterExport(cl,"create_and_run_datapoint")
clusterExport(cl,"check_run_flag")

if (nrow(vars) == 1) {
    print("not sure what to do with only one datapoint so adding an NA")
    vars <- rbind(vars, c(NA))
}
if (nrow(vars) == 0) {
    print("not sure what to do with no datapoint so adding an NA")
    vars <- rbind(vars, c(NA))
    vars <- rbind(vars, c(NA))
}

print(nrow(vars))
print(ncol(vars))
if (ncol(vars) == 1) {
    print("NSGA2 needs more than one variable")
    stop(options("show.error.messages"=TRUE),"NSGA2 needs more than one variable")
}

print(paste("Number of generations set to:",gen))
print(uniquegroups)
print(vars[])
print(vartypes)
print(gen)
print(toursize)
print(cprob)
print(xoverdistidx)
print(mudistidx)
print(mprob)

results = NULL
#try(results = nsga2NREL(cl=cl, fn=create_and_run_datapoint, objDim=uniquegroups, variables=vars[], vartype=vartypes, generations=gen, tourSize=toursize, cprob=cprob, XoverDistIdx=xoverdistidx, MuDistIdx=mudistidx, mprob=mprob), silent=FALSE)
results = nsga2NREL(cl=cl, fn=create_and_run_datapoint, objDim=uniquegroups, variables=vars[], vartype=vartypes, generations=gen, tourSize=toursize, cprob=cprob, XoverDistIdx=xoverdistidx, MuDistIdx=mudistidx, mprob=mprob)

# TODO: how to get best result back in docker space? API? What is the server?
#for (i in 1:num_uniq_workers) {
#    scp = paste('scp ',whoami,'@',ips2[i],':',analysis_dir,'/best_result.json ',analysis_dir,'/',sep="")
#print(paste("scp command:",scp))
#system(scp,intern=TRUE)
#scp2 <- paste('scp ',whoami,'@',ips2[i],':',analysis_dir,'/convergence_flag.json ',analysis_dir,'/', sep="")
#print(paste("scp2 command:",scp2))
#system(scp2,intern=TRUE)
#}

results_filename = paste(analysis_dir,'/results.R')
save(results, file=results_filename)
