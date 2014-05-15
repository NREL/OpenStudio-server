name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.3.4",
        :installer => {
            :version_revision => "b1a11998bb",
            :platform => "Linux-Ruby2.0"
        }
    }
)
