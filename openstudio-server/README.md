# This is a bare bones rails installation and there are some quirks due to NREL/vagrant/ruby 2.0 that have yet to be ironed out.

# Instructions
1. Start the VM and let the provisioning continue until it crashes
1. Update Ruby gems
 `gem update --system`
1. Turn off ssl verification in the .gemrc file
 `cd /home/vagrant`
 `echo ":ssl_verify_mode: 0" > .gemrc`


1. Exit the VM and then reprovision the VM

`vagrant provision`

1. Login to the vagrant box and start the rails server

`vagrant ssh`
`sudo -i`
`cd /var/www/rails/openstudio/`
`rails s`

