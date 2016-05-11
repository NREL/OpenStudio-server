# Virtual Machine Management
The OpenStudio Server is provisioned using Chef through Vagrant. There are currently three provisioners to generate the VM.

* VirtualBox - Dev
The VirtualBox - Dev is used for development and requires the user to install the following.
    * [ChefDK](https://downloads.getchef.com/chef-dk/)
    * VirtualBox
    * Vagrant

* AWS

* VirtualBox - RSync

# Configuring VMs

## Automated Provisioning Scripts
This directory contains a `create_vms.rb` file which can be used to automatically provision and configure either VirtualBox - Dev or AWS.

### Creating new AMIs

Make sure that you have installed the following Vagrant plug-ins.
* vagrant plugin install vagrant-aws
* vagrant plugin install vagrant-awsinfo

In addition, an AWS account needs to be specified to create the EC2 instances in. To specify this account, in your home directory create a .aws folder, and in the folder write a config.yml file following the form below with your AWS account information.
```
access_key_id: accessKeyForAwsUser
secret_access_key: secretAccessKeyForAwsUser
keypair_name: your-keypair-name
region: us-east-1
private_key_path: /Absolute/path/to/aws/.ssh/key.pem
```

Next, go to the [version.rb](https://github.com/NREL/OpenStudio-server/blob/develop/server/lib/openstudio_server/version.rb) file in the /server/lib/openstudio-server directory of this repo and update the VERSION_EXT constant for your one-off build. One off builds using the create_vms.rb script should not change the VERSION constant, as that is updated through the master branch and new AMIs released using the rake release command.

Finally, to automatically create the EC2 instances, provision the application, then create the AMIs simply run the following, substituting in the username to register with the AMI:

```
bundle exec ruby create_vms.rb -p aws -u your_user_name
```

## Server Configuration

- Log into 192.168.33.10 either via `vagrant ssh` or putty.

```sh
cs
```

## Logging Information (in order of importance)

- rails - /var/www/rails/openstudio/log/development.log (rails stack)
- Rserve - /var/www/rails/openstudio/Rserve.log (print messages in R commands)
- rails child processes
  + download files - /tmp/download-output.log*
- delayed_jobs - /var/www/rails/openstudio/log/delayed_jobs.log
- download child process - /var/www/rails/openstudio/log/download.log
- mongo - /var/www/rails/openstudio/log/mongo.log
- apache
  + /var/log/apache2/error.log (http errors like malformed urls)
  + /var/log/apache2/access.log (ip address, client)
- R
  + /tmp/snow.log


## Worker Configuration

- Log into 192.168.33.11 either via `vagrant ssh` or putty.

```sh
cw
```

