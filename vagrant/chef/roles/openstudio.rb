name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :version => "1.4.0",
        :installer => {
            :version_revision => "60c2e9d96f",
            :platform => "Linux-Ruby2.0"
        }
    }
)
