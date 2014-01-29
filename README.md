# OpenStudio Server

## Description
The preferred development approach for this application is to use Vagrant to provision and test the server.  To see the server instructions go to [OpenStudio Rails Application](./openstudio-server/README.md)

## Instructions

- Install [Vagrant] and [VirtualBox]  
  *Note: There is a [known issue](https://github.com/mitchellh/vagrant/issues/2392) with VirtualBox 4.3.x that prevents the VM from launching correctly; use 4.2.18 instead.*
  
[Vagrant]: http://www.vagrantup.com/ "Vagrant"
[VirtualBox]: https://www.virtualbox.org/ "VirtualBox"

- Check out the git repo: see the instruction on the Wiki.  
  **Make sure to checkout the repo with LF end-of-lines if on windows**

- Initialize and update all Git submodules (see wiki):
```sh
$ git submodule init
$ git submodule update
```

- Install the Vagrant omnibus plugin

```sh
vagrant plugin install vagrant-omnibus
```

- Also install the Vagrant AWS plugin as the vagrant file will fail if not installed 

```sh
vagrant plugin install vagrant-aws
```

- Start VirtualBox (Windows only)

- **NREL ONLY** Set environment variables or bypass SSL proxy
Either login to the SSL Developer VPN or set the environment variables below.
  **Windows**  
```bat
cd \path\to\Vagrantfile
rem for each cmd window set the environment variable (or set globally (for NREL only)
set OMNIBUS_INSTALL_URL=http://www.opscode.com/chef/install.sh

```
  **Mac / Linux**  
```sh
cd /path/to/Vagrantfile
# for each cmd window set the environment variable (or set globally (for NREL only)
OMNIBUS_INSTALL_URL=http://www.opscode.com/chef/install.sh
```

- Start the VM and let it provision:  
```sh
vagrant up
```
  Note, if the Vagrant provision fails, run `vagrant provision` at command line again and see if it gets past the issue.

- **NREL ONLY** Disable HTTPS
If you are inside the NREL firewall then you will need to disable HTTPS on rubygems. 

  - Log into Vagrant VM  
  
```sh
vagrant ssh
```
  
  (Or use [PuTTy](http://stackoverflow.com/questions/9885108/ssh-to-vagrant-box-in-windows) on Windows.)

  - Add http://rubygems.org to gem sources
  
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

- Test the Rails application by pointing your local browser to [http://localhost:8080](http://localhost:8080)

## Deploying to Amazon EC2

### Development/Test AMIs

- Install the Vagrant AWS plug-in 

```sh
vagrant plugin install vagrant-aws
```

- **NREL ONLY** Login to the SSL Developer VPN

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

- Run the create_vms.rb script

```
cd vagrant
ruby create_vms.rb --aws
```

### Official AMI Generation

- Push all code to master
- Update the Server version in ./server/lib/version.rb using semantic versioning.
- Commit/push your code
- Run the `rake release` in the root. 
This will tag the version in git, push the tags, then push the code to ami-build.  Jenkins will take over the generation of the AMIs.


## Old Amazon Image Instructions


- Log into the new system and do some cleanup before creating the AMI

```sh
vagrant ssh
```

### Server Changes

```sh
cd /data/launch-instance
chmod 777 setup-server-changes.sh
sudo ./setup-server-changes.sh
chmod 777 setup-final-changes.sh
sudo ./setup-final-changes.sh
exit
cat /dev/null > ~/.bash_history && history -c
sudo shutdown -r now
```

### Worker Changes

```sh
cd /data/launch-instance
chmod 777 setup-worker-changes.sh
sudo ./setup-worker-changes.sh
chmod 777 setup-final-changes.sh
sudo ./setup-final-changes.sh
exit
cat /dev/null > ~/.bash_history && history -c
sudo shutdown -r now
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
rake db:mongoid:create_indexes
rm -rf /mnt/openstudio
sudo apt-get upgrade -y
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
cat /dev/null > /var/www/rails/openstudio/log/download.log
cat /dev/null > /var/www/rails/openstudio/log/mongo.log
cat /dev/null > /var/www/rails/openstudio/log/development.log
cat /dev/null > /var/www/rails/openstudio/log/production.log
cat /dev/null > /var/www/rails/openstudio/log/delayed_job.log
rm -f /var/www/rails/openstudio/log/test.log
rm -rf /var/www/rails/openstudio/public/assets/*
rm -rf /var/www/rails/openstudio/tmp/*
cat /dev/null > /var/log/auth.log
cat /dev/null > /var/log/lastlog
cat /dev/null > /var/log/kern.log
cat /dev/null > /var/log/boot.log
rm -f /data/launch-instance/*.pem
rm -f /data/launch-instance/*.log
rm -f /data/launch-instance/*.json
rm -f /data/launch-instance/*.yml
rm -f /data/worker-nodes/README.md
rm -f /data/worker-nodes/rails-models/mongoid-vagrant.yml
rm -rf /var/chef
cat /dev/null > ~/.bash_history && history -c
apt-get clean

sudo shutdown -r now
```

- login to AWS and take a snapshot of the image
  + Naming convention is `OpenStudio Worker Cluster OS <version of openstudio>`
  + Increase the size of the root image to 10GB in both

- test the AMI using the script run_ec2
- merge the branch into master
- tag the release 
  + Naming convention is to increment the minor release (e.g. V1.2.0).  Note that this number does not increment the same as openstudio because there may be intermediate patched. 
  + Add a note in the release to which versions of OpenStudio the release supports


