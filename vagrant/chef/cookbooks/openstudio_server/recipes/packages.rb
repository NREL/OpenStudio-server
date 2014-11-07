#
# Cookbook Name:: openstudio_server
# Recipe:: packages
#

# Other random packages that need to be installed
%w( expect curl iotop imagemagick unzip zip ).each do |pi|
  package pi do
    action :upgrade
  end
end
