#
# Cookbook Name:: openstudio_server
# Recipe:: base
#
# Recipe installs the base software needed for openstudio analysis (both server and worker)

# Eventually remove the roles tab and use this for configuring the system.


# General useful utilities
# include_recipe 'apt'
# include_recipe 'ntp'
# include_recipe 'cron'
# include_recipe 'man'
# include_recipe 'vim'

# A much nicer replacement for grep.
# include_recipe 'ack'

# Zip/Unzip
# include_recipe 'zip'

# Sudo - careful installing this as you can easily prevent yourself from using sudo
node.default['authorization']['sudo']['users'] = ["vagrant", "ubuntu"]
# set the sudoers files so that it has access to rbenv
secure_path = "#{node[:rbenv][:root_path]}/shims:#{node[:rbenv][:root_path]}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
node.default['authorization']['sudo']['sudoers_defaults'] = [
    'env_reset',
    "secure_path=\"#{secure_path}\""
]
node.default['authorization']['sudo']['passwordless'] = true
node.default['authorization']['sudo']['include_sudoers_d'] = true
node.default['authorization']['sudo']['agent_forwarding'] = true
include_recipe 'sudo'

node.override['logrotate']['global']['rotate'] = 30
node.override['logrotate']['global']['compress'] = true
%w(monthly weekly yearly).each do |freq|
  node.override['logrotate']['global'][freq] = false
end
node.override['logrotate']['global']['daily'] = true
include_recipe 'logrotate::global'

# logrotate_app 'tomcat-myapp' do
#   cookbook  'logrotate'
#   path      '/var/log/tomcat/myapp.log'
#   options   ['missingok', 'delaycompress']
#   frequency 'daily'
#   rotate    30
#   create    '644 root adm'
# end

include_recipe "rbenv"
include_recipe "rbenv::ruby_build"

# Install rbenv and Ruby

# Set env variables as they are needed for openstudio linking to ruby
ENV['RUBY_CONFIGURE_OPTS'] = '--enable-shared'
ENV['CONFIGURE_OPTS'] = '--disable-install-doc'

rbenv_ruby node[:openstudio_server][:ruby][:version] do
  global true
end

# Add any gems that require compilation here otherwise the workflow gem won't be able to use them
%w(bundler libxml-ruby ruby-prof).each do |g|
  rbenv_gem g do
    ruby_version node[:openstudio_server][:ruby][:version]
  end
end

# Add user to rbenv group
Chef::Log.info "Adding user '#{node[:openstudio_server][:bash_profile_user]}' to '#{node[:rbenv][:group]}' group"
group node[:rbenv][:group] do
  action :modify
  members node[:openstudio_server][:bash_profile_user]
  append true
end

# set the passenger node values to the location of rbenv - languages is not accessible
#Chef::Log.info "Resetting passenger root path to #{languages['ruby']['gems_dir']}/gems/passenger-#{node['passenger']['version']}"
#Chef::Log.info "Resetting passenger ruby bin path to #{languages['ruby']['ruby_bin']}"

Chef::Log.info "Resetting the root_path and ruby_bin for Passenger"
node.override['passenger']['root_path'] = "/opt/rbenv/versions/#{node[:openstudio_server][:ruby][:version]}/lib/ruby/gems/2.0.0/gems/passenger-#{node['passenger']['version']}"
node.override['passenger']['ruby_bin'] = "/opt/rbenv/versions/#{node[:openstudio_server][:ruby][:version]}/bin/ruby"
