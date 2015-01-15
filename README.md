# OpenStudio Server

## Description
The preferred development approach for this application is to use Vagrant to provision and test the server.  To see the server instructions go to [OpenStudio Rails Application](./openstudio-server/README.md)

## Instructions

- Install [Vagrant] *1.6.1*, [VirtualBox] *4.3.8*, and [ChefDK]
 
[Vagrant]: http://www.vagrantup.com/ "Vagrant"
[VirtualBox]: https://www.virtualbox.org/ "VirtualBox"
[ChefDK]: https://downloads.chef.io/chef-dk/ "ChefDK"

- Check out this git repo: see the instruction on the Wiki.  

- Install the Vagrant plugins for bootstrapping Chef and Berkshelf

```sh
vagrant plugin install vagrant-omnibus vagrant-berkshelf
```

- Also install the Vagrant AWS plugin as the vagrant file will fail if not installed

```sh
vagrant plugin install vagrant-aws
```

- Virtualbox 4.3+ users may want to install the vagrant-vbguest plugin to update the guest version

```sh
vagrant plugin install vagrant-vbguest
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


  **Windows**  

  Windows users may want to install cwRsync and use the rsync method of mounting shared drives.
  This eliminates the performance hit in standard vagrant sharing, especially with drives on different indexes.
  Make sure there is only one rsync process found on the system (ex, remove the Rtools/rsync.exe)

## Git SSH Issues

If you experience issues accessing git:// protocols issues (typically because of a proxy denying access), then you can globally set the https:// protocol

```
git config --global url."https://".insteadOf git://
```

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
- Update the Server version in ./server/lib/openstudio_server/version.rb using semantic versioning.
- Commit/push your code
- Run the `rake release` in the root. This will tag the version in git, push the tags, then push the code to ami-build.  Jenkins will take over the generation of the AMIs and push the new AMIs IDs to developer.nrel.gov.
- For OpenStudio PAT, Alex Swinder has to copy over the AMI ID from this file: http://developer.nrel.gov/downloads/buildings/openstudio/api/amis_v2.json to this file: http://developer.nrel.gov/downloads/buildings/openstudio/rsrc/amis.json

