name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.3.5",
        :installer => {
            :version_revision => "91d2d5586b",
            :platform => "Linux-Ruby2.0"
        }
    }
)
