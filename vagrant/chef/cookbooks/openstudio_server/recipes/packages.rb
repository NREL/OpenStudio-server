#
# Cookbook Name:: openstudio_server
# Recipe:: packages
#

# install curl here, because there isn't a cookbook and i don't
# want to make one right now.
package "curl" do
  action :upgrade
end
