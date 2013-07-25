# OpenStudio Server

## Description
The preferred development approach for this application is to use Vagrant to provision and test the server.  To see the server instructions go to [OpenStudio Rails Application](./openstudio-server/README.md)

## Instructions
- Start the VM and let the provisioning continue until it crashes (if inside of NREL make sure to disable SSL)

```sh
OMNIBUS_INSTALL_URL=http://www.opscode.com/chef/install.sh vagrant up
```

- Log into Vagrant VM

```sh
vagrant ssh
```

- Add http://rubygems.org to gem sources (NREL ONLY)

```sh
sudo -i
gem sources -r https://rubygems.org/
gem sources -a http://rubygems.org/

```

- Reinstall with --force the gem that didn't install correctly (most likely rails).

```sh
sudo -i
gem install rails -v "3.2.13" --force --no-rdoc --no-ri
```

Note if this fails, then go into the rails directory for the application and do bundle install

```sh
cd /var/www/rails/openstudio
bundle install
```

- Exit the VM and then reprovision the VM

```sh
$ vagrant provision
```

- If provisioning fails, continue to call the vagrant provision command

- Test the rails server

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



