name "mongodb"
description "Install and configure mogno"

run_list([
             # Default iptables setup on all servers.
             "recipe[mongodb]",
         ])


default_attributes(
    :mongodb => {
        :install_method => "10gen",
        :package_version => "2.4.9",
        :dbpath => "/mnt/mongodb/data", # being deprecated. use line below
        :config => {
          :dbpath => "/mnt/mongodb/data"
        }
    }
)

