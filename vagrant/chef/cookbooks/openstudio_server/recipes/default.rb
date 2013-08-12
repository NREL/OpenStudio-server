#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

#include_recipe "rails"
include_recipe "passenger_apache2"

web_app "openstudio-server" do
  docroot "#{node[:openstudio_server][:server_path]}/public"
  server_name "openstudio-server"
  #server_aliases [ "openstudio", node[:hostname] ]
  rails_env "development"
end


# execute bundle install in directory
bash "bundle install" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle install
  EOH
end

# restart (or start) delayed_job
bash "restart delayed job" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    script/delayed_job restart
  EOH
end
