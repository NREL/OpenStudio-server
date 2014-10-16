#
# Cookbook Name:: openstudio_server
# Recipe:: worker
#

include_recipe "rbenv"

# execute bundle install in directory
execute 'bundle install' do
  cwd '/data/worker-nodes'
end

