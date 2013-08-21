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
vagrant provision
```

Mac / Linux

```sh
# for each cmd window set the environment variable (or set globally (for NREL only)
OMNIBUS_INSTALL_URL=http://www.opscode.com/chef/install.sh vagrant up
vagrant provision
```

Note, if the Vagrant provision fails, run `vagrant provision` at command line again and see if it gets past the issue.

- Log into Vagrant VM

```sh
vagrant ssh
```

- Add http://rubygems.org to gem sources (NREL ONLY)

```sh
sudo -i
apt-get update
apt-get install rubygems -y
gem sources -r https://rubygems.org/
gem sources -a http://rubygems.org/
gem install rails -v "3.2.13" --force --no-rdoc --no-ri
```

- Exit the VM and then reprovision the VM

```sh
vagrant provision
```

Note, if provisioning fails continue to call the `vagrant provision` command

- Run the rails server
By default, apache is configured to run the rails application, but the `bundle install` command has yet to be called.

SSH into the vagrant machine and run bundler in the openstudio-server application directory

```sh
vagrant ssh
cd /var/www/rails/openstudio
sudo bundle install
```

There may be a couple other dependencies to start (i.e. delayed_job).  To see the server instructions go to [OpenStudio Rails Application](./openstudio-server/README.md)

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

- vagrant ssh or vagrant ubuntu@ec2-a-b-c-d.compute-1.amazonaws.com

- login to AWS and take a snapshot of the image



