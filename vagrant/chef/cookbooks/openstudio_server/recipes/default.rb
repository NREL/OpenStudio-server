#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

#include_recipe "rails"
include_recipe "passenger_apache2"

web_app "openstudio-server" do
  docroot "/var/www/rails/openstudio/public"
  server_name "openstudio-server"
  #server_aliases [ "openstudio", node[:hostname] ]
  rails_env "development"
end


# execute bundle install in directory

# start delayed_job