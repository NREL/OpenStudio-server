#
# Cookbook Name:: openstudio_server
# Recipe:: worker_data
#

# execute bundle install in directory. install the gems into a directory which will persist
bash 'bundle_install' do
  code <<-EOH
    cd /data/worker-nodes
    bundle install
  EOH
end
