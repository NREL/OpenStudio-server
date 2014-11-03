#
# Cookbook Name:: openstudio_server
# Recipe:: bundle
#

# execute bundle install in the server directory to install all the rails dependencies
bash "bundle install" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle install
  EOH
end
