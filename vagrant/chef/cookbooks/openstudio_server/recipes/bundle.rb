#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

include_recipe "rbenv"

# execute bundle install in directory
bash "bundle install" do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle install
  EOH
end

# rehash rbenv
rbenv_rehash "rehashing in case rails was installed"