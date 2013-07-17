# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  is_windows = (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)

  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "ubuntu-precise-64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  config.omnibus.chef_version = :latest

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network :forwarded_port, guest: 3000, host: 8081
  config.vm.network :forwarded_port, guest: 27017, host: 8888

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network :private_network, ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder "openstudio-server", "/var/www/rails/openstudio", :nfs => !is_windows


  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider :virtualbox do |vb|
    # Don't boot with headless mode
    # vb.gui = true

    # Use VBoxManage to customize the VM. For example to change memory:
    vb.customize ["modifyvm", :id, "--memory", 4096, "--cpus", 4]

    # Disable DNS proxy.
    # Causes slowness: https://github.com/rubygems/rubygems/issues/513
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
  end

  # View the documentation for the provider you're using for more
  # information on available options.

  # Enable provisioning with chef solo, specifying a cookbooks path, roles
  # path, and data_bags path (all relative to this Vagrantfile), and adding
  # some recipes and/or roles.
  #
  config.vm.provision :chef_solo do |chef|
    chef.cookbooks_path = "chef/cookbooks"
    chef.roles_path = "chef/roles"

    chef.add_role "openstudio-server"
  end

  config.vm.provider :aws do |aws, override|
    #http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?
    require 'excon'
    Excon.defaults[:ssl_verify_peer] = false

    # you will need to create a yaml file with these values to
    # properly deploy to ec2
    require 'yaml'
    aws_config = YAML::load_file(File.join(Dir.home, ".aws_secrets"))
    aws.access_key_id = aws_config.fetch("access_key_id")
    aws.secret_access_key = aws_config.fetch("secret_access_key")
    aws.keypair_name = aws_config.fetch("keypair_name")
    override.ssh.private_key_path = aws_config.fetch("private_key_path")

    aws.security_groups = ["default"]
    #aws.instance_type = "m1.small"
    aws.instance_type = "m1.xlarge"
    aws.ami = "ami-d0f89fb9"

    override.ssh.username = "ubuntu"

    aws.tags = {
        'Name' => 'OpenStudio',
        'OpenStudio Version' => '0.10.5'
    }


  end
end
