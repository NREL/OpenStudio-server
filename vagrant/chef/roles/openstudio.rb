name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.3.3",
        :installer => {
            :version_revision => "74c3859219",
            :platform => "Linux-Ruby2.0"
        }
    }
)
