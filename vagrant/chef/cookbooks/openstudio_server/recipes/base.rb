#
# Cookbook Name:: openstudio_server
# Recipe:: base
#
# Recipe installs the base software needed for openstudio analysis (both server and worker)


# General useful utilities
include_recipe 'apt'
include_recipe 'ntp'
include_recipe 'cron'
include_recipe 'man'
include_recipe 'vim'

# A much nicer replacement for grep.
include_recipe 'ack'

# Zip/Unzip
include_recipe 'zip'

# Sudo - careful installing this as you can easily prevent yourself from using sudo
node.default['authorization']['sudo']['users'] = ["vagrant", "ubuntu"]
node.default['authorization']['sudo']['sudoers_defaults'] = [
    'env_reset',
    'secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
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

# Other random packages that need to be installed
%w( expect curl iotop imagemagick ).each do |pi|
  package pi
end

include_recipe "rbenv::default"
include_recipe "rbenv::ruby_build"


# Install rbenv and Ruby

# Set env variables as they are needed for openstudio linking to ruby
ENV['RUBY_CONFIGURE_OPTS'] = '--enable-shared'
ENV['CONFIGURE_OPTS'] = '--disable-install-doc'

rbenv_ruby node[:openstudio_server][:ruby_version] do
  global true
end

%w(bundler ruby-prof).each do |g|
  rbenv_gem g do
    ruby_version node[:openstudio_server][:ruby_version]
  end
end
