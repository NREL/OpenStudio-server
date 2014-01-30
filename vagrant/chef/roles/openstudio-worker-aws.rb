name "openstudio-worker"
description "Install and configure OpenStudio for use with Ruby on Rails"

run_list([
             # Default iptables setup on all servers.
             "role[base]",
             "role[ruby]",
             "role[mongodb]",
             "role[r-project]",
             "role[openstudio]",
             "recipe[openstudio_server::bashprofile]",
             "role[radiance]",
             "recipe[openstudio_server::worker]",
         ])

default_attributes(
    :openstudio_server => {
        :bash_profile_user => "ubuntu"
    }
)

override_attributes(
    :r => {
        :rserve_start_on_boot => false,
    }
)
