name 'openstudio_server'
maintainer 'NREL'
maintainer_email 'nicholas.long@nrel.gov'
license 'LGPL'
description 'Installs and configures OpenStudio web application'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '2.0.0'

depends 'apt'
depends 'ntp'
depends 'man'
depends 'ack'
depends 'vim'
depends 'zip'
depends 'sudo'
depends 'logrotate'
depends 'build-essential'

# Applications
depends 'openstudio'
depends 'rbenv'
depends 'mongodb'
depends 'apache2', '~> 3.0.0'
depends 'passenger_apache2'

%w(redhat centos scientific amazon oracle ubuntu debian arch).each do |os|
  supports os
end
