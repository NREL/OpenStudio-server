name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             # Default iptables setup on all servers.
             "recipe[openstudio]",
             "recipe[energyplus]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.2.3",
        :version_revision => "02346785ab",
        :platform => "Linux-Ruby2.0"
        #:checksum => "9180659c77a7fc710cb9826d40ae67c65db0d26bb4bce1a93b64d7e63f4a1f2c"
    },
    :energyplus => {
        :version => "800009",
        #:checksum => "c1ec1499f964bad8638d3c732c9bd10793dd4052a188cd06bb49288d3d962e09"
    }
)
