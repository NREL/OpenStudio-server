#
# Cookbook Name:: openstudio_server
# Recipe:: bundle
#

# execute bundle install in the server directory to install all the rails dependencies
bash 'rails_bundle_install' do
  code <<-EOH
    cd #{node[:openstudio_server][:server_path]}
    bundle update
    bundle install
  EOH
end
