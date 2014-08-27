#
# Cookbook Name:: openstudio_server
# Recipe:: base
#
# Recipe installs the base software needed for openstudio analysis (both server and worker)

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
