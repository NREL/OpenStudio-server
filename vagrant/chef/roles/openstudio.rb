name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.5.0",
        :installer => {
            :version_revision => "d7c6dca9",
            :platform => "Linux-Ruby2.0"
        }
    }
)
