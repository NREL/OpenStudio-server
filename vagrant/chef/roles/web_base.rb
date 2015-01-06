name 'openstudio_server_web_base'
description 'A base role for openstudio web server'

run_list([
  'recipe[apache2]',
  'recipe[apache2::mod_ssl]'
])

override_attributes(
    apache: {
      listen_ports: %w(80 443)
    }
)
