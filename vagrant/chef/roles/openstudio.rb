name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.4.0",
        :installer => {
            :version_revision => "4cd6ad08de",
            :platform => "Linux-Ruby2.0"
        }
    }
)
