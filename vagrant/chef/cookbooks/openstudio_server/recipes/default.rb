#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
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
#*******************************************************************************

#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

include_recipe 'passenger_apache2'
include_recipe 'supervisor'

web_app 'openstudio-server' do
  docroot "#{node[:openstudio_server][:server_path]}/public"
  server_name "openstudio-server.#{node[:domain]}"
  rails_env "#{node[:openstudio_server][:rails_environment]}"
end

# load any seed data that needs to be in the database by default
bash 'load default data' do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle exec rake db:seed
  EOH
end

bash 'create database indexes' do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle exec rake db:mongoid:create_indexes
  EOH
end

bash 'fix delayed job permissions' do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    chmod 775 script/delayed_job
  EOH
end

bash 'fix permissions on log files' do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}/log
    find . -type d -print0 | xargs -0 chmod 777
    find . -type f -print0 | xargs -0 chmod 777
  EOH
end

bash 'fix permissions on assets files' do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}/public
    find . -type d -print0 | xargs -0 chmod 777
    find . -type f -print0 | xargs -0 chmod 666
  EOH
end

bash 'fix permissions on tmp files' do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}/tmp
    find . -type d -print0 | xargs -0 chmod 777
    find . -type f -print0 | xargs -0 chmod 666
  EOH
end

# supervisor tasks
supervisor_service 'delayed_job' do
  command "#{node[:openstudio_server][:server_path]}/script/delayed_job run"
  directory "#{node[:openstudio_server][:server_path]}/script"
  environment(
    RAILS_ENV: node[:openstudio_server][:rails_environment],
    PATH: "#{node[:openstudio_server][:ruby_path]}:#{ENV['PATH']}"
  )
  stdout_logfile "#{node[:openstudio_server][:server_path]}/log/delayed_job.log"
  stderr_logfile "#{node[:openstudio_server][:server_path]}/log/delayed_job.log"
  action :enable
  autostart true
  user 'root'
end

service 'apache2' do
  action :restart
end
