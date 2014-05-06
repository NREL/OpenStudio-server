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
            :version => "1.3.3",
            :version_revision => "efd0d991e7",
            :platform => "Linux-Ruby2.0"
        }
    },
    :energyplus => {
        :version => "800009",
    }
)
