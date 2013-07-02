# OpenStudio Server

## Description
This is a bare bones rails installation and there are some quirks due to NREL/vagrant/ruby 2.0 that have yet to be ironed out. Also, most of this will get simplified in the near future, this is just the basics to get up-and-running.

## Instructions
- Start the VM and let the provisioning continue until it crashes
- Update Ruby gems

```sh
$ gem update --system
```

- Turn off ssl verification in the .gemrc file

```sh
# Right now this is using sudo. This will be fixed later.
$ sudo -i
$ echo ":ssl_verify_mode: 0" >> /etc/gemrc`
```

- Reinstall with --force the gem that didn't install correctly (most likely rails)

```sh 
$ sudo gem install rails -v "3.2.13" --force --no-rdoc --no-ri
```

- Exit the VM and then reprovision the VM

```sh 
$ vagrant provision
```

- Login to the vagrant box and start the rails server

```sh
vagrant ssh
sudo -i
cd /var/www/rails/openstudio/
rails s
```

- In another terminal start vagrant ssh and run

```sh
sudo -i
cd /var/www/rails/openstudio
rake db:seed
```
