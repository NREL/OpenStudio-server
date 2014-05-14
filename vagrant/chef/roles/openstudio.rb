name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :installer => {
            :version => "1.3.3",
            :version_revision => "efd0d991e7",
            :platform => "Linux-Ruby2.0"
        }
    }
)
