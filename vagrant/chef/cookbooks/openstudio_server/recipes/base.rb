#
# Cookbook Name:: openstudio_server
# Recipe:: base
#
# Recipe installs the base software needed for openstudio analysis (both server and worker)


# General useful utilities
include_recipe 'apt'
include_recipe 'ntp'
include_recipe 'cron'


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



include_recipe "rbenv::default"
include_recipe "rbenv::ruby_build"

# needs to be set for openstudio linking to ruby
ENV['RUBY_CONFIGURE_OPTS'] = '--enable-shared'
ENV['CONFIGURE_OPTS'] = '--disable-install-doc'

# TODO: move this to an attribute
version_of_ruby = "2.0.0-p481"
rbenv_ruby version_of_ruby do
  global true
end

%w(bundler ruby-prof).each do |g|
  rbenv_gem g do
    ruby_version version_of_ruby
  end
end
