name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             # Default iptables setup on all servers.
             "recipe[openstudio]",
             "recipe[energyplus]",
         ])


default_attributes(
    :openstudio => {
        :installer => {
            :version => "1.3.0",
            :version_revision => "4ba9a2e48b",
            :platform => "Linux-Ruby2.0"
        }
    },
    :energyplus => {
        :version => "800009",
    }
)
