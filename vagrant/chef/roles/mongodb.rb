name 'mongodb'
description 'Install and configure mongo'

run_list([
  # Default iptables setup on all servers.
  'recipe[mongodb]'
])

default_attributes(
  mongodb: {
    # These first 4 are per this pull request: https://github.com/edelight/chef-mongodb/pull/262
    # They should be fixed soon, at which point the defaults will work again.
    dbconfig_file: '/etc/mongod.conf',
    sysconfig_file: '/var/lib/mongo',
    default_init_name: 'mongod',
    instance_name: 'mongod',
    install_method: 'mongodb-org',
    config: {
      dbpath: '/mnt/mongodb/data',
      logpath: '/var/log/mongo/mongod.log'
    }
  }
)
