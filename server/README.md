# OpenStudio Rails Application

## Description
This is a bare bones rails installation and there are some quirks due to NREL/vagrant/ruby 2.0 that have yet to be ironed out. Also, most of this will get simplified in the near future, this is just the basics to get up-and-running.

## Instructions
- Login to the vagrant box and start the rails server.  You also need to start delayed job for handing the R calls

```sh
cd /var/www/rails/openstudio
bundle install
```

```sh
vagrant ssh
sudo -i
cd /var/www/rails/openstudio/
script/delayed_job start

```

## Initializing the database
```sh
sudo -i
cd /var/www/rails/openstudio
rake db:seed
```

# WEBbrick
- If you want to run the server through webbrick do the following

```sh
sudo -i
cd /var/www/rails/openstudio/
rails s
```


