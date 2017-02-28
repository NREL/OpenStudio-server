check_run_flag <- function(script_path, host_url, analysis_id, debug_messages = 0){
    y <- paste(script_path,'/api_get_status.rb -h ',host_url,' -a ',analysis_id,sep='')
    z <- system2("ruby",y, stdout = TRUE, stderr = TRUE)
    if(debug_messages == 1){
      print(paste('Check Run Flag run command: ruby ', y)) 
      print(paste("Check Run Flag z:",z))
    }
    #check if return status is NULL (means no errors)
    if(is.null(attr(z, "status"))) {
      z <- z[length(z)] # Get last line of output
      json <- try(fromJSON(z), silent=TRUE)
      if(debug_messages == 1){
        print(paste("run_flag_json:",json))
      }
      #print(paste('is.recursive(run_flag_json):',is.recursive(json)))
      if (is.recursive(json)) {
        return(json$result)
      } else {
        print("API GET STATUS is not json")
        return(TRUE)
      }
    } else {
      print("API GET STATUS failed")
      return(TRUE)
    }
}
