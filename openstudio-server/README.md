# OpenStudio Rails Application

## Description
This is a bare bones rails installation and there are some quirks due to NREL/vagrant/ruby 2.0 that have yet to be ironed out. Also, most of this will get simplified in the near future, this is just the basics to get up-and-running.

## Instructions
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
