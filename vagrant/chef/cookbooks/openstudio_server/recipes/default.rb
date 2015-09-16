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
supervisor_service "delayed_job" do
  command "#{node[:openstudio_server][:server_path]}/script/delayed_job run"
  directory "#{node[:openstudio_server][:server_path]}/script"
  environment(
      {
          RAILS_ENV: node[:openstudio_server][:rails_environment],
          PATH: "#{node[:openstudio_server][:ruby_path]}:#{ENV['PATH']}"
      }
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
