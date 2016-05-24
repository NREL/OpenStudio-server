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
-  **NREL Windows**  
```bat
cd \path\to\Vagrantfile
rem for each cmd window set the environment variable (or set globally (for NREL only)
set OMNIBUS_INSTALL_URL=http://www.opscode.com/chef/install.sh

```
-  **NREL Mac / Linux**  
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

### Releasing a New Version

- Create a pull request from your feature branch to develop
- Ensure the tests are passing (to be added) for the pull request
- Merge the pull request into develop
- Ensure the version id, found in the server [version.rb](./server/lib/openstudio_server/version.rb) file, is incremented to be one ahead of the master verion, using standard semantic versioning
- Create a pull request to master and assign it to @bball, @nllong, @rhorsey, or @evanweaver
- One of the above will review the pull request, and either re-assign it for further update, or merge it to master
- When it is merged to master, the merger will release a new build using the `rake release` script
- Check the [available OSServer AMI json](http://s3.amazonaws.com//openstudio-resources/server/api/v2/amis.json) regularly to see when the build becomes available

### Releasing a One Off Version

- Create a new branch off of a commit of develop or master which corresponds to the desired base state of your server
- Update the server code as needed
- After making all changes, it is recomended that you create a pull request back to develop, applying the DO NOT MERGE tag, to allow the continuous integration tests to run against your changes
- After ensuring all test are sucessfull, close the pull request.
- Add a suffix to the version id by setting a flag in the [version.rb](./server/lib/openstudio_server/version.rb) file
- NOTE: THIS STEP WILL BE CHANGED SHORTLY: Follow the instructions found [here](./vagrant) to run the [create_vms.rb](./vagrant/create_vms.rb) script. This will build the AMIs and register them with Amazon EC2.
- Check the [available OSServer AMI json](http://s3.amazonaws.com//openstudio-resources/server/api/v2/amis.json) regularly to see when the build becomes available

### Other Notes

For OpenStudio PAT, Alex Swinder has to copy over the AMI ID from this file: http://developer.nrel.gov/downloads/buildings/openstudio/api/amis_v2.json to this file: http://developer.nrel.gov/downloads/buildings/openstudio/rsrc/amis.json

## Questions?

Please contact @rhorsey, @bball, or @nllong with any question regarding this project. Thanks for you interest!
