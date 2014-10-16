#
# Cookbook Name:: openstudio_server
# Recipe:: worker
#

# execute bundle install in directory
execute 'bundle install' do
  cwd '/data/worker-nodes'
end

