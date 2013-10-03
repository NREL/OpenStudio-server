#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

include_recipe "passenger_apache2"
include_recipe "cron"


# load the test data (eventaully make this a separate recipe - or just remove)
bash "load default data" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle exec rake db:seed
  EOH
end

web_app "openstudio-server" do
  docroot "#{node[:openstudio_server][:server_path]}/public"
  server_name "openstudio-server"
  rails_env "development"
end

# restart (or start) delayed_job
bash "restart delayed job" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    chmod 774 script/delayed_job
    script/delayed_job restart
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

