name "mongodb"
description "Install and configure mogno"

run_list([
             # Default iptables setup on all servers.
             "recipe[mongodb]",
         ])


default_attributes(
    :mongodb => {
        :package_version => "2.6.4",
        :install_method => 'mongodb-org',
        :config => {
          :dbpath => "/mnt/mongodb/data"
        }
    }
)

