name "mongodb"
description "Install and configure mogno"

run_list([
             # Default iptables setup on all servers.
             "recipe[mongodb::10gen_repo]",
             "recipe[mongodb]",
         ])


default_attributes(
    :mongodb => {
        :package_version => "2.4.6",
        :dbpath => "/mnt/mongodb/data"
    }
)