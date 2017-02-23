check_run_flag <- function(script_path, host_url, analysis_id){
    #y <- paste('ruby ',script_path,'/api_get_status.rb -h ',host_url,' -a ',analysis_id,sep='')
    #print(paste('run command', y))
    #z <- system(y,intern=TRUE)
    y <- paste(script_path,'/api_get_status.rb -h ',host_url,' -a ',analysis_id,sep='')
    #print(paste('run command: ruby ', y))
    z <- system2("ruby",y, stdout = TRUE, stderr = TRUE)
    #print(paste("Check Run Flag z:",z))
    #check if return status is NULL (means no errors)
    if(is.null(attr(z, "status"))) {
      z <- z[length(z)] # Get last line of output

      json <- try(fromJSON(z), silent=TRUE)
      #print(paste("run_flag_json:",json))
      #print(paste('is.recursive(run_flag_json):',is.recursive(json)))
      if (is.recursive(json)) {
        return(json$result$analysis$run_flag)
      } else {
        print("API GET STATUS is not json")
        return(TRUE)
      }
    } else {
      print("API GET STATUS failed")
      return(TRUE)
    }
}
