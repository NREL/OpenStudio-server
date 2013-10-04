#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

include_recipe "passenger_apache2"

# load any seed data that needs to be in the database by default
bash "load default data" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle exec rake db:seed
  EOH
end

web_app "openstudio-server" do
  docroot "#{node[:openstudio_server][:server_path]}/public"
  server_name "openstudio-server"
  rails_env "#{node[:openstudio_server][:rails_environment]}"
end

bash "fix delayed job permissios" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    chmod 775 script/delayed_job
  EOH
end

template "/etc/init.d/delayed_job" do
  source "delayed_job.erb"
  owner "root"
  mode "0755"
end

# go ahead and kick it off now because we aren't going to reboot
bash "configure delayed_job daemon" do
  code <<-EOH
    cd /etc/init.d/
    update-rc.d -f delayed_job remove
    update-rc.d delayed_job defaults 99
  EOH
end

service "delayed_job" do
  action :restart
end

