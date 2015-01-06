#
# Cookbook Name:: openstudio_server
# Recipe:: worker
#

# execute bundle install in directory
bash 'bundle install' do
  code <<-EOH
    cd /data/worker-nodes
    bundle install
  EOH
end
