# x is datapoint id
# Several of the variables are in the sessions. The list below should abstracted out:
#   rails_mongodb
#   rails_mongodb_ip
#   rails_rails_analysis_id
#   ruby_command
run_datapoint = function(x){
    mongo = mongoDbConnect(rails_mongodb, host=rails_mongodb_ip, port=27017)
    mongo_query_id = paste('{_id:"',rails_analysis_id,'"}',sep='')
    flag = dbGetQueryForKeys(mongo, "analyses", mongo_query_id, '{run_flag:1}')
    if (flag["run_flag"] == "false" ){
        stop(options("show.error.messages"=FALSE),"run flag is not TRUE")
    }
    dbDisconnect(mongo)

    y = paste(ruby_command,rails_sim_root_path,'/simulate_data_point.rb -a',rails_analysis_id,' -u ',x,' -x ',rails_run_filename,sep='')
    print(paste("R is calling system command as:",y))
    z = system(y,intern=TRUE)
    return(z)
}