name "openstudio-worker"
description "Install and configure OpenStudio for use with Ruby on Rails"

run_list([
             # Default iptables setup on all servers.
             "role[base]",
             "role[ruby-worker]",
             "role[mongodb]",
             "role[radiance]",
             "role[r-project]",
             "role[openstudio]",
             "recipe[openstudio_server::bashprofile]",
         ])

default_attributes(
    :openstudio_server => {
        :bash_profile_user => "vagrant"
    }
)

override_attributes(
    :r => {
        :rserve_start_on_boot => false,
    }
)
