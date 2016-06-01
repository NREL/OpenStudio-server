#g(x) such that x is vector of variable values,
#           create a data_point from the vector of variable values x and return the new datapoint UUID
#           create a UUID for that data_point and put in database
#           call f(u) where u is UUID of data_point
# Several of the variables are in the sessions. The list below should abstracted out:
#   rails_host
#   rails_analysis_id
#   ruby_command
#   r_scripts_path
# x: array of variables
create_and_run_datapoint = function(x){
    # TODO: Replace this with an API call to the server
    if (check_run_flag(r_scripts_path, rails_host, rails_analysis_id)==FALSE){
        stop(options("show.error.messages"=FALSE),"run flag set to FALSE")
    }

    # convert the vector to comma separated values
    force(x) # What does this do?
    w = paste(x, collapse=",")
    y = paste('ruby ',r_scripts_path,'/api_create_datapoint.rb -h ',rails_host,' -a ',rails_analysis_id,' -v ',w,' --submit',sep='')

    # Call the system command to submit the simulation to the API / queue
    print(paste('run command', y))
    z = system(y,intern=TRUE)
    # z will be a json file

    z = z[length(z)]
    print(z)

    datapoint_directory = paste(rails_analysis_id,'/data_point_',z,sep='')
    print(datapoint_directory)

    # TODO: What to do with this?
    # data_point_directory = paste(analysis_dir,'/data_point_',z[j],sep='')
    #
    ## save off the variables file (can be used later if number of vars gets too long)
    # write.table(x, paste(data_point_directory,"/input_variables_from_r.data",sep=""),row.names = FALSE, col.names = FALSE)

    json = try(fromJSON(z), silent=TRUE)
    if (!json$status) {
        NAvalue = 1.0e19
        return(NAvalue)
    } else {
        if (is.null(json)) {
            obj = NULL
            for (i in 1:objDim) {
                obj[i] = 1.0e19
            }
            print(paste(datapoint_directory,"/objectives.json is NULL"))
        } else {
            obj = NULL
            objvalue = NULL
            objtarget = NULL
            sclfactor = NULL
            objgroup = NULL
            group_count = 1
            for (i in 1:objDim){
                objfuntemp = paste("objective_function_",i,sep="")
                if (json$results[objfuntemp] != "NULL"){
                    objvalue[i] = as.numeric(json$results[objfuntemp])
                } else {
                    objvalue[i] = 1.0e19
                    cat(data_point_directory," Missing ", objfuntemp,"\n");
                }
                objfuntargtemp = paste("objective_function_target_",i,sep="")
                if (json$results[objfuntargtemp] != "NULL"){
                    objtarget[i] = as.numeric(json$results[objfuntargtemp])
                } else {
                    objtarget[i] = 0.0
                }
                scalingfactor = paste("scaling_factor_",i,sep="")
                sclfactor[i] = 1.0
                if (json$results[scalingfactor] != "NULL"){
                    sclfactor[i] = as.numeric(json$results[scalingfactor])
                    if (sclfactor[i] == 0.0) {
                        print(paste(scalingfactor," is ZERO, overwriting\n"))
                        sclfactor[i] = 1.0
                    }
                } else {
                    sclfactor[i] = 1.0
                }
                objfungrouptemp = paste("objective_function_group_",i,sep="")
                if (json$results[objfungrouptemp] != "NULL"){
                    objgroup[i] = as.numeric(json$results[objfungrouptemp])
                } else {
                    objgroup[i] = group_count
                    group_count = group_count + 1
                }
            }

            print(paste("Objective function results are:",objvalue))
            print(paste("Objective function targets are:",objtarget))
            print(paste("Objective function scaling factors are:",sclfactor))

            objvalue = objvalue / sclfactor
            objtarget = objtarget / sclfactor

            ug = length(unique(objgroup))
            if (ug != uniquegroups) {
                print(paste("Json unique groups:",ug," not equal to Analysis unique groups",uniquegroups))
                uniq_filename = paste(analysis_dir,'/uniquegroups.err',sep='')
                write.table("unique groups", file=uniq_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)
                stop(options("show.error.messages"=TRUE),"unique groups is not equal")
            }

            for (i in 1:ug){
                obj[i] = force(eval(dist(rbind(objvalue[objgroup==i],objtarget[objgroup==i]),method=normtype,p=ppower)))
            }

            print(paste("Objective function Norm:",obj))

            # Check if exit on guideline 14 is enabled
            if (rails_exit_guideline_14){

                # read in the results from the objective function file
                guideline_file = paste(data_point_directory,"/run/CalibrationReports/guideline.json",sep="")
                json = NULL
                try(json = fromJSON(file=guideline_file), silent=TRUE)
                if (is.null(json)) {
                    print(paste("no guideline file: ",guideline_file))
                } else {
                    guideline = json[[1]]
                    for (i in 2:length(json)) guideline = cbind(guideline,json[[i]])
                    print(paste("guideline: ",guideline))
                    print(paste("isTRUE(guideline): ",isTRUE(guideline)))
                    print(paste("all(guideline): ",all(guideline)))
                    if (length(which(guideline)) == objDim){
                        #write final params to json file
                        write_filename = paste(analysis_dir,'/varnames.json',sep='')
                        varnames = scan(file=write_filename, what=character())

                        answer = paste('{',paste('"',gsub(".","|",varnames, fixed=TRUE),'"',': ',x,sep='', collapse=','),'}',sep='')
                        write_filename = paste(analysis_dir,'/best_result.json',sep='')
                        write.table(answer, file=write_filename, quote=FALSE,row.names=FALSE,col.names=FALSE)

                        convergenceflag = paste('{',paste('"',"exit_on_guideline14",'"',': ',"true",sep='', collapse=','),'}',sep='')
                        write_filename = paste(analysis_dir,'/convergence_flag.json',sep='')
                        write(convergenceflag, file=write_filename)
                        dbDisconnect(mongo)
                        stop(options("show.error.messages"=FALSE),"exit_on_guideline14")
                    }
                }
            }
        }
    }

    return(as.numeric(obj))
}



