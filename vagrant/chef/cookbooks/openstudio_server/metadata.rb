name              "openstudio_server"
maintainer        "NREL"
maintainer_email  "nicholas.long@nrel.gov"
license           "LGPL"
description       "Installs and configures OpenStudio web application"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "2.0.0"

#recipe "passenger_apache2", "Installs Passenger as an Apache module"
#recipe "passenger_apache2::mod_rails", "Enables Apache module configuration for passenger module"
#depends "apache2", ">= 1.0.4"

depends 'apt'
depends 'cron'
depends 'ntp'
depends 'man'
depends 'ack'
depends 'vim'
depends 'zip'
depends 'sudo'
depends 'logrotate'
depends 'build-essential'

# Applications
depends 'rbenv'

%w{ redhat centos scientific amazon oracle ubuntu debian arch }.each do |os|
  supports os
end
