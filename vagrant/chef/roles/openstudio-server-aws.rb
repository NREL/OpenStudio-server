name "openstudio-server"
description "Install and configure OpenStudio for use with Ruby on Rails"

run_list([
             # Default iptables setup on all servers.
             "role[base]",
             "role[ruby]",
             "role[r-project]",
             "recipe[mongodb::server]",
             "recipe[openstudio]",
             "recipe[energyplus]",
             "role[web_base]",
             "recipe[openstudio_server::bundle]", #install the bundle first to get rails for apache passenger
             "role[passenger_apache]",
             "recipe[openstudio_server]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.1.0.4382d437dc",
        #:checksum => "9180659c77a7fc710cb9826d40ae67c65db0d26bb4bce1a93b64d7e63f4a1f2c"
    },
    :energyplus => {
        :version => "800008",
        #:checksum => "c1ec1499f964bad8638d3c732c9bd10793dd4052a188cd06bb49288d3d962e09"
    },
    :openstudio_server => {
        :ruby_path => "/usr/local/rbenv", # this is needed for the delayed_job service
        :server_path => "/var/www/rails/openstudio",
        :rails_environment => "development"
    }
)

override_attributes(
    :R => {
        :rserve_start_on_boot => true,
        :rserve_user => "ubuntu",
        :rserve_log_path => "/var/www/rails/openstudio/log/Rserve.log"
    }
)
