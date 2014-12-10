# #
# Cookbook Name:: openstudio_server
# Recipe:: users
#

# Ohai is the right way, but I can't figure it out right now--so install facter
# Lock the version per https://github.com/NREL/OpenStudio-server/issues/18
chef_gem 'facter' do
  version '2.3.0'
end

require 'facter'

# Do I have an EC2 instance ID?
if Facter.fact(:ec2_instance_id)
  Chef::Log.info "Instance is running on EC2"
  # Override the default users of rserve and bash.  This is required because of using vagrant vs ec2
  node.override[:openstudio_server][:bash_profile_user] = 'ubuntu'
  node.override[:r][:rserve_user] = 'ubuntu'
else
  node.override[:openstudio_server][:bash_profile_user] = 'vagrant'
  node.override[:r][:rserve_user] = 'vagrant'
end
