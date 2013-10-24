name "openstudio-worker"
description "Install and configure OpenStudio for use with Ruby on Rails"

run_list([
             # Default iptables setup on all servers.
             "role[base]",
             "role[ruby-worker]",
             "role[mongodb]",
             #"role[web_base]",
             "role[r-project]",
             "role[openstudio]",
         ])

override_attributes(
    :R => {
        :rserve_start_on_boot => false,
        :build_from_source => true
    }
)
