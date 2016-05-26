#g(x) such that x is vector of variable values,
#           create a data_point from the vector of variable values x and return the new data point UUID
#           create a UUID for that data_point and put in database
#           call f(u) where u is UUID of data_point
# Several of the variables are in the sessions. The list below should abstracted out:
#   rails_rails_analysis_id
#   ruby_command
#   rails_sim_root_path
#   rails_create_dp_filename
#   rails_root_path
create_and_run_datapoints = function(x){
    print(system('whoami', intern = TRUE))
    print(system('which ruby', intern = TRUE))
    print(system('which rake', intern = TRUE))
    print(system('env', intern = TRUE))

    force(x)
    # convert the vector to comma separated values
    w = paste(x, collapse=",")
    # rake datapoints:create_datapoint -- -afa5dcadc-ed5b-4209-b907-777e9e2573c8 -v5,3,alsdfjk
    y = paste('cd ',rails_root_path,' && bundle exec rake datapoints:create_datapoint -- -a',rails_analysis_id,' -v',w,sep='')
#   y = paste(ruby_command,rails_sim_root_path,'/',rails_create_dp_filename,' -a ',rails_analysis_id,' -v ',w,sep='')
    print(y)
    z = system(y,intern=TRUE)
    print("Running in create_and_run_datapoints")
#    j = length(z)
#    z
    return(928734982374)

#    # Run the datapoint and check the results
#    if (as.character(z[j]) == "NA") {
#        cat("UUID is NA \n");
#        NAvalue = 1.0e19
#        return(NAvalue)
#    } else {
#        try(run_datapoint(z[j]), silent = TRUE)
#
#        data_point_directory = paste(analysis_dir,'/data_point_',z[j],sep='')
#
#        # save off the variables file (can be used later if number of vars gets too long)
#        write.table(x, paste(data_point_directory,"/input_variables_from_r.data",sep=""),row.names = FALSE, col.names = FALSE)
#
#        # read in the results from the objective function file
#        object_file <- paste(data_point_directory,"/objectives.json",sep="")
#        json <- NULL
#        try(json <- fromJSON(file=object_file), silent=TRUE)
#
#        if (is.null(json)) {
#            obj <- NULL
#            for (i in 1:objDim){
#                obj[i] <- 1.0e19
#            }
#            print(paste(data_point_directory,"/objectives.json is NULL"))
#        } else {
#            obj <- NULL
#            objvalue <- NULL
#            objtarget <- NULL
#            sclfactor <- NULL
#            objgroup <- NULL
#            group_count <- 1
#            for (i in 1:objDim){
#                objfuntemp <- paste("objective_function_",i,sep="")
#                if (json[objfuntemp] != "NULL"){
#                    objvalue[i] <- as.numeric(json[objfuntemp])
#                } else {
#                    objvalue[i] <- 1.0e19
#                    cat(data_point_directory," Missing ", objfuntemp,"\n");
#                }
#                objfuntargtemp <- paste("objective_function_target_",i,sep="")
#                if (json[objfuntargtemp] != "NULL"){
#                    objtarget[i] <- as.numeric(json[objfuntargtemp])
#                } else {
#                    objtarget[i] <- 0.0
#                }
#                scalingfactor <- paste("scaling_factor_",i,sep="")
#                sclfactor[i] <- 1.0
#                if (json[scalingfactor] != "NULL"){
#                    sclfactor[i] <- as.numeric(json[scalingfactor])
#                    if (sclfactor[i] == 0.0) {
#                        print(paste(scalingfactor," is ZERO, overwriting\n"))
#                        sclfactor[i] = 1.0
#                    }
#                } else {
#                    sclfactor[i] <- 1.0
#                }
#                objfungrouptemp <- paste("objective_function_group_",i,sep="")
#                if (json[objfungrouptemp] != "NULL"){
#                    objgroup[i] <- as.numeric(json[objfungrouptemp])
#                } else {
#                    objgroup[i] <- group_count
#                    group_count <- group_count + 1
#                }
#            }
#            print(paste("Objective function results are:",objvalue))
#            print(paste("Objective function targets are:",objtarget))
#            print(paste("Objective function scaling factors are:",sclfactor))
#
#            objvalue <- objvalue / sclfactor
#            objtarget <- objtarget / sclfactor
#
#            ug <- length(unique(objgroup))
#            if (ug != uniquegroups) {
#                print(paste("Json unique groups:",ug," not equal to Analysis unique groups",uniquegroups))
#                uniq_filename = paste(analysis_dir,'/uniquegroups.err',sep='')
#                write.table("unique groups", file=uniq_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
#                stop(options("show.error.messages"=TRUE),"unique groups is not equal")
#            }
#
#            for (i in 1:ug){
#                obj[i] <- force(eval(dist(rbind(objvalue[objgroup==i],objtarget[objgroup==i]),method=normtype,p=ppower)))
#            }
#
#            print(paste("Objective function Norm:",obj))
#
#            mongo = mongoDbConnect(rails_mongodb, host=rails_mongodb_ip, port=27017)
#            mongo_query_id = paste('{_id:"',rails_analysis_id,'"}',sep='')
#            flag = dbGetQueryForKeys(mongo, "analyses", mongo_query_id, '{exit_on_guideline14:1}')
#            print(paste("exit_on_guideline14: ",flag))
#            if (flag["exit_on_guideline14"] == "true" ){
#                # read in the results from the objective function file
#                guideline_file <- paste(data_point_directory,"/run/CalibrationReports/guideline.json",sep="")
#                json <- NULL
#                try(json <- fromJSON(file=guideline_file), silent=TRUE)
#                if (is.null(json)) {
#                    print(paste("no guideline file: ",guideline_file))
#                } else {
#                    guideline <- json[[1]]
#                    for (i in 2:length(json)) guideline <- cbind(guideline,json[[i]])
#                    print(paste("guideline: ",guideline))
#                    print(paste("isTRUE(guideline): ",isTRUE(guideline)))
#                    print(paste("all(guideline): ",all(guideline)))
#                    if (length(which(guideline)) == objDim){
#                        #write final params to json file
#                        write_filename = paste(analysis_dir,'/varnames.json',sep='')
#                        varnames = scan(file=write_filename, what=character())
#
#                        answer = paste('{',paste('"',gsub(".","|",varnames, fixed=TRUE),'"',': ',x,sep='', collapse=','),'}',sep='')
#                        write_filename = paste(analysis_dir,'/best_result.json',sep='')
#                        write.table(answer, file=write_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
#
#                        convergenceflag = paste('{',paste('"',"exit_on_guideline14",'"',': ',"true",sep='', collapse=','),'}',sep='')
#                        write_filename = paste(analysis_dir,'/convergence_flag.json',sep='')
#                        write(convergenceflag, file=write_filename)
#                        dbDisconnect(mongo)
#                        stop(options("show.error.messages"=FALSE),"exit_on_guideline14")
#                    }
#                }
#            }
#            dbDisconnect(mongo)
#        }
#        return(as.numeric(obj))
#    }
}