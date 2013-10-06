# OpenStudio Server

## Description
The preferred development approach for this application is to use Vagrant to provision and test the server.  To see the server instructions go to [OpenStudio Rails Application](./openstudio-server/README.md)

## Instructions

- Check out the git repo

See the instruction on the Wiki. ** Make sure to checkout the repo with LF end-of-lines if on windows **

- Install the vagrant omnibus plugin

```sh
vagrant plugin install vagrant-omnibus
```

- Also install the vagrant AWS plugin as the vagrant file will fail if not installed 

```sh
vagrant plugin install vagrant-aws
```

- Start the VM and let it provision

Windows

```sh
# for each cmd window set the environment variable (or set globally (for NREL only)
set OMNIBUS_INSTALL_URL=http://www.opscode.com/chef/install.sh
vagrant up
```

Mac / Linux

```sh
# for each cmd window set the environment variable (or set globally (for NREL only)
OMNIBUS_INSTALL_URL=http://www.opscode.com/chef/install.sh vagrant up
```

Note, if the Vagrant provision fails, run `vagrant provision` at command line again and see if it gets past the issue.

- **NREL ONLY** Disable HTTPS
If you are inside the NREL firewall then you will need to disable HTTPS on rubygems. 

Log into Vagrant VM

```sh
vagrant ssh
```

Add http://rubygems.org to gem sources

```sh
sudo -i
gem sources -r https://rubygems.org/
gem sources -a http://rubygems.org/

```

- Exit the VM and then reprovision the VM

```sh
vagrant provision
```

Note, if provisioning fails continue to call the `vagrant provision` command

- Test the Rails application by pointing your local browser to http://localhost:8080

## Deploying to Amazon EC2

- Install the Vagrant AWS plug-in

```sh
vagrant plugin install vagrant-aws
```

- Install Vagrant Omnibus plug-in to automatically install chef on the destination system

```sh
vagrant plugin install vagrant-omnibus
```

- Create an `.aws_secrets` file in your home directory and include the following

```sh
access_key_id: key
secret_access_key: access_key
keypair_name: key_pair_name
private_key_path: /Users/<user>/.ssh/amazon.pem
```

- Launch vagrant using the

```sh
vagrant up --provider=aws
```

Note, if the Vagrant provision fails, run `vagrant provision` at command line again and see if it gets past the issue. There is a known issue with the dependency order of Rails and Passenger.

- Log into the new system and do some cleanup before creating the AMI

```sh
vagrant ssh
```

### Server Changes
- The script below does several items including
  + Enable password login (for setting up passwordless SSH)
  + Change owner of Rserved and restart Rserve 
  + Update all packages and reboot
  + Remove unneeded directories/files


```sh
sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > .ssh/config
sudo service ssh restart
cd /var/www/rails/openstudio
rake db:purge
rm -rf /mnt/openstudio
sudo apt-get upgrade -y
sudo shutdown -r now
```

### Worker Changes
  + Enable password login (for setting up passwordless SSH)
  + Update all packages and reboot
  + Remove unneeded directories/files


```sh
sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > .ssh/config
sudo service ssh restart
sudo apt-get upgrade -y
sudo shutdown -r now
```

### Final Changes
- Before creating the AMI do these last on both systems
  + Make sure the the default use is unlocked
  + Remove authorized keys (this will prevent you from logging in again, do this last)
  + Clear out the various logs
  + Remove unneeded files that are in the mounted folders

```sh
sudo usermod -U ubuntu
cat /dev/null > ~/.ssh/authorized_keys
cat /dev/null > ~/.bash_history && history -c
sudo -i
cat /dev/null > ~/.bash_history && history -c
cat /dev/null > /var/www/rails/openstudio/log/download.log
cat /dev/null > /var/www/rails/openstudio/log/mongo.log
cat /dev/null > /var/www/rails/openstudio/log/development.log
cat /dev/null > /var/www/rails/openstudio/log/delayed_job.log
cat /dev/null > /var/log/auth.log
cat /dev/null > /var/log/lastlog
cat /dev/null > /var/log/kern.log
cat /dev/null > /var/log/boot.log
rm -rf /var/www/rails/openstudio/public/assets/*
rm -rf /data/launch-instance/integrated
rm -f /data/launch-instance/ec2*.*
rm -f /data/launch-instance/config.yml
rm -rf /data/prototype/example_scripts
rm -rf /data/prototype/R
```

- login to AWS and take a snapshot of the image
  + Increase the size of the root image to 10GB in both



