name "openstudio-worker"
description "Install and configure OpenStudio for use with Ruby on Rails"

run_list([
             # Default iptables setup on all servers.
             "role[base]",
             "role[ruby-worker]",
             #"role[web_base]",
             "role[r-project]",
             "recipe[mongodb::server]",
             "recipe[openstudio]",
             "recipe[energyplus]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.1.0.8d33c713a1",
        #:checksum => "9180659c77a7fc710cb9826d40ae67c65db0d26bb4bce1a93b64d7e63f4a1f2c"
    },
    :energyplus => {
        :version => "800008",
        #:checksum => "c1ec1499f964bad8638d3c732c9bd10793dd4052a188cd06bb49288d3d962e09"
    }
)

override_attributes(
    :R => {
        :rserve_start_on_boot => false
    }
)
