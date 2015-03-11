name 'openstudio-server'
description 'Install and configure OpenStudio for use with Ruby on Rails'

run_list([
  # Default iptables setup on all servers.
  'recipe[openstudio_server::users]',  # Run this before R and before openstudio bashprofile and base
  'role[base]',
  'role[mongodb]',
  'role[r-project]',
  'role[openstudio]',
  'role[radiance]',
  'role[web_base]',
  'recipe[openstudio_server::bashprofile]',
  'recipe[openstudio_server::bundle]', # install the bundle first to get rails for apache passenger
  'role[passenger_apache]',
  'recipe[openstudio_server]',
  'recipe[openstudio_server::worker_data]'
])

default_attributes(
  openstudio_server: {
    ruby_path: '/opt/rbenv/shims', # this is needed for the delayed_job and R runs service. Where is the ruby binary (in the shims)?
    server_path: '/var/www/rails/openstudio',
    rails_environment: 'development'
  }
)

override_attributes(
  r: {
    rserve_start_on_boot: true,
    rserve_log_path: '/var/www/rails/openstudio/log/Rserve.log'
  }
)
