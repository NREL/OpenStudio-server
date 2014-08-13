name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.4.0",
        :installer => {
            :version_revision => "f09ef8475b",
            :platform => "Linux-Ruby2.0"
        }
    }
)
