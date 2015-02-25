name 'openstudio-worker'
description 'Install and configure OpenStudio for use with Ruby on Rails'

run_list([
  # Default iptables setup on all servers.
  'recipe[openstudio_server::users]',  # Run this before R and before openstudio bashprofile and base
  'role[base]',
  'recipe[openstudio_server::mongoshell]',
  'role[r-project]',
  'role[openstudio]',
  'recipe[openstudio_server::bashprofile]',
  'role[radiance]',
  'recipe[openstudio_server::worker_data]'
])

default_attributes(
    openstudio_server: {
      bash_profile_user: 'vagrant'
    }
)

override_attributes(
    r: {
      rserve_start_on_boot: false
    }
)
