check_run_flag = function(script_path, host_url, analysis_id){
    y = paste('ruby ',script_path,'/api_get_status.rb -h ',host_url,' -a ',analysis_id,sep='')
    print(paste('run command', y))
    z = system(y,intern=TRUE)
    z = z[length(z)] # Get last line of output

    json = try(fromJSON(z), silent=TRUE)
    return(json$result$analysis$run_flag)
}
