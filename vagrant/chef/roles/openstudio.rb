name "openstudio"
description "Install and configure OpenStudio and EnergyPlus"

run_list([
             "recipe[openstudio]",
         ])


default_attributes(
    :openstudio => {
        :skip_ruby_install => true,
        :version => "1.5.1",
        :installer => {
            :version_revision => "297c509238",
            :platform => "Linux-Ruby2.0"
        }
    }
)
