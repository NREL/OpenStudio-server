#
# Cookbook Name:: openstudio_server
# Recipe:: default
#

#include_recipe "rails"
include_recipe "passenger_apache2"

web_app "openstudio-server" do
  docroot "/var/www/rails/openstudio"
  server_name "openstudio.#{node[:domain]}"
  server_aliases [ "openstudio", node[:hostname] ]
  rails_env "development"
end
