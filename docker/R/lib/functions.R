check_run_flag <- function(script_path, host_url, analysis_id){
    y <- paste('ruby ',script_path,'/api_get_status.rb -h ',host_url,' -a ',analysis_id,sep='')
    print(paste('run command', y))
    z <- system(y,intern=TRUE)
    z <- z[length(z)] # Get last line of output

    json = try(fromJSON(z), silent=TRUE)
    print(paste("run_flag_json:",json))
    print(paste('is.recursive(run_flag_json):',is.recursive(json)))
    print(paste('is.atomic(run_flag_json):',is.atomic(json)))
    if (is.atomic(json)) {
      return(json$result$analysis$run_flag)
    } else {
      print("API GET STATUS is empty")
      return(TRUE)
    }
}
