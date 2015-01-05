name 'base'
description 'Base role for servers and worker nodes'

run_list([
  # For checking out our repos.
  'recipe[git]',

  # man pages are handy.
  'recipe[man]',

  # Ensure ntp is used to keep clocks in sync.
  'recipe[ntp]',

  # A much nicer replacement for grep.
  'recipe[ack]',

  # VIM
  'recipe[vim]',

  # base openstudio installation
  'recipe[openstudio_server::base]',

  # OpenStudio Base Packages
  'recipe[openstudio_server::packages]'
])

default_attributes
