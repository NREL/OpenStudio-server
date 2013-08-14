#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

#include_recipe "rails"
include_recipe "passenger_apache2"

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

# load the test data (eventaully make this a separate recipe)
bash "load default data" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    rake db:seed
  EOH
end

web_app "openstudio-server" do
  docroot "#{node[:openstudio_server][:server_path]}/public"
  server_name "openstudio-server"
  #
  rails_env "development"
end

# restart apache?






