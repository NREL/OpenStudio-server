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


# make sure that the cron has a reboot task for delayed job .
# Note: there seems to be a bug such that this isn't called idempotently and creates a new entry everytime
cron 'start-delayed-job-on-reboot' do
  minute  '@reboot'
  hour    ''
  day     ''
  month   ''
  weekday ''
  command "/bin/bash -l -c 'cd #{node[:openstudio_server][:server_path]} && RAILS_ENV=development script/delayed_job restart'"
  user "root"
end



