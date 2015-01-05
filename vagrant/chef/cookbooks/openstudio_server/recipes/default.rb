#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

include_recipe 'passenger_apache2'

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

bash 'fix permissions on log files'  do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}/log
    find . -type d -print0 | xargs -0 chmod 777
    find . -type f -print0 | xargs -0 chmod 777
  EOH
end

bash 'fix permissions on assets files'  do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}/public
    find . -type d -print0 | xargs -0 chmod 777
    find . -type f -print0 | xargs -0 chmod 666
  EOH
end

bash 'fix permissions on tmp files'  do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}/tmp
    find . -type d -print0 | xargs -0 chmod 777
    find . -type f -print0 | xargs -0 chmod 666
  EOH
end

template '/etc/init.d/delayed_job' do
  source 'delayed_job.erb'
  owner 'root'
  mode '0755'
end

# go ahead and kick it off now because we aren't going to reboot
bash 'configure delayed_job daemon' do
  code <<-EOH
    cd /etc/init.d/
    update-rc.d -f delayed_job remove
    update-rc.d delayed_job defaults 99
  EOH
end

service 'apache2' do
  action :restart
end

service 'delayed_job' do
  action :restart
end
