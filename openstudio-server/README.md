# This is a bare bones rails installation and there are some quirks due to NREL/vagrant/ruby 2.0 that have yet to be ironed out.

# Also, most of this will get simplified in the near future, this is just the
# basics to get up-and-running.

# Instructions
1. Start the VM and let the provisioning continue until it crashes
1. Update Ruby gems
 `gem update --system`
1. Turn off ssl verification in the .gemrc file
  `sudo -i`
 `echo ":ssl_verify_mode: 0" >> /etc/gemrc`


1. Reinstall with --force the gem that didn't install correctly (most likely rails)
`sudo gem install rails -v "3.2.13" --force --no-rdoc --no-ri`

1. Exit the VM and then reprovision the VM
`vagrant provision`

1. Login to the vagrant box and start the rails server

`vagrant ssh`
`sudo -i`
`cd /var/www/rails/openstudio/`
`rails s`

1. In another terminal start vagrant ssh and run
`sudo -i`
`cd /var/www/rails/openstudio`
`rake db:seed`

