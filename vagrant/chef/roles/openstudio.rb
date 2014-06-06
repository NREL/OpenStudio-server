name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.3.6",
        :installer => {
            :version_revision => "e5a0143db7",
            :platform => "Linux-Ruby2.0"
        }
    }
)
