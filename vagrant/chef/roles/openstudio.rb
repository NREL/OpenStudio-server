name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :installer => {
            :version => "1.3.2",
            :version_revision => "386caf0e00",
            :platform => "Linux-Ruby2.0"
        }
    }
)
