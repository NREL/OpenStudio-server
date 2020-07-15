# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# create_and_run_datapoint_uniquegroups(x) such that x is vector of variable values,
#           create a datapoint from the vector of variable values x and run
#           the new datapoint
# x: vector of variable values
#
# Several of the variables are in the sessions. The list below should abstracted out:
#   rails_host
#   rails_analysis_id
#   ruby_command
#   r_scripts_path
create_and_run_datapoint <- function(x){
  options(warn=-1)
  if (check_run_flag(r_scripts_path, rails_host, rails_analysis_id, debug_messages)==FALSE){
    options(warn=0)
    stop(options("show.error.messages"=FALSE),"run flag set to FALSE")
  }

  print('UrbanOpt')

  # convert the vector to comma separated values
  force(x)
  w <- paste(x, collapse=",") 
  y <- paste('--help',sep='')
  if(debug_messages == 1){
    print(paste('run command: uo ', y))
  }

# Call the system command to submit the simulation to the API / queue
Sys.setenv(RUBYLIB="/usr/local/openstudio-3.0.1/Ruby")
z <- system2("uo",y, stdout = TRUE, stderr = TRUE)
#z <- z[length(z)]
if(debug_messages == 1){
  print(paste("UrbanOpt OUTPUT: ",z))
}

print(paste("TESTING workflow RETURNING: ",failed_f))
obj <- NULL
for (i in 1:objDim) {
  obj[i] <- failed_f
}
options(warn=0)
return(obj)
    
  #THIS PATH DOESNT EXIST on Workers.  THIS IS RUNNING ON RSERVE_1 
#  data_point_directory <- paste('/mnt/openstudio/analysis_',rails_analysis_id,'/data_point_',json$id,sep='')
#  if(debug_messages == 1){
#    print(paste("data_point_directory:",data_point_directory))
#  }
#  if(!dir.exists(data_point_directory)){
#    dir.create(data_point_directory)
#    if(debug_messages == 1){
#      print(paste("data_point_directory created: ",data_point_directory))
#    }
#  }
  ## save off the variables file (can be used later if number of vars gets too long)
#  if (dir.exists(data_point_directory)) {
#    write.table(x, paste(data_point_directory,"/input_variables_from_r.data",sep=""),row.names = FALSE, col.names = FALSE)
#  } else { 
#     print(paste("data_point_directory does not exist! ",data_point_directory))
#  }
}

