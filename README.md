# OpenStudio Server

## Description
The preferred development approach for this application is to use Vagrant to provision and test the server.  To see the server instructions go to [OpenStudio Rails Application](./openstudio-server/README.md)

## Instructions
- Start the VM and let the provisioning continue until it crashes
- Update Ruby gems

```sh
$ gem update --system
```

- Turn off ssl verification in the .gemrc file (NREL only requirement)

```sh
# Right now this is using sudo. This will be fixed later.
$ sudo -i
$ echo ":ssl_verify_mode: 0" >> /etc/gemrc
```

- Reinstall with --force the gem that didn't install correctly (most likely rails)

```sh
$ sudo gem install rails -v "3.2.13" --force --no-rdoc --no-ri
```

- Exit the VM and then reprovision the VM

```sh
$ vagrant provision
```

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



