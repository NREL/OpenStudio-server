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

-- Enable password logins on the systems

```sh
sudo vi /etc/ssh/sshd_config
```
set PasswordAuthentication to yes
```sh
sudo service ssh restart
```

-- Change owner of Rserved process

```sh
sudo vi /etc/init.d/Rserved
:%s/vagrant/ubuntu/g
```

-- Update all packages and reboot
```sh
sudo apt-get upgrade -y
sudo shutdown -r now
```

-- Remove your authorized key
vi ~/.ssh/authorized_keys
dd
:x

-- Remove extraneous directories
rm -rf /data/prototype/pat
rm -f /data/launch-instance/config.yml
cd /var/www/rails/openstudio
rake db:purge
rm -rf /mnt/openstudio

- login to AWS and take a snapshot of the image



