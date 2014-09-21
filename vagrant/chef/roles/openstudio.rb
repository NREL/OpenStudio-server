name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.4.3",
        :installer => {
            :version_revision => "e90c081df3",
            :platform => "Linux-Ruby2.0"
        }
    }
)
