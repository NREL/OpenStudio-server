#!/bin/bash

echo ""
echo "------------------------------------------------------------------------"
echo "Updating Ubuntu 16.10 Yakkety system"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
sudo apt-get -qq update
sudo rm -f /boot/grub/menu.lst # https://bugs.launchpad.net/ubuntu/+source/cloud-init/+bug/1485685
sudo apt-get -y -qq upgrade
sudo apt-get -y -qq install curl linux-image-extra-$(uname -r) linux-image-extra-virtual htop iftop unzip lvm2 thin-provisioning-tools
sudo apt-get -y -qq install gdisk kpartx parted
sudo apt -qq -y install python3
sudo apt -qq -y install ruby
sudo perl -p -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"/g'  /etc/default/grub
sudo /usr/sbin/update-grub
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Configuring the logical mount volume thinpool-docker for the daemon"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
if [ "$(sudo lsblk -o NAME | grep xvda1)" = '└─xvda1' ]; then
	sudo pvcreate /dev/xvdn
	sudo vgcreate docker /dev/xvdn
else
	sudo pvcreate /dev/sdn
	sudo vgcreate docker /dev/sdn
fi
sudo lvcreate --wipesignatures y -n thinpool docker -l 95%VG
sudo lvcreate --wipesignatures y -n thinpoolmeta docker -l 1%VG
sudo lvconvert -y --zero n -c 512K --thinpool docker/thinpool --poolmetadata docker/thinpoolmeta
sudo mkdir -p /etc/lvm/profile/
echo -e "activation {\nthin_pool_autoextend_threshold=80\nthin_pool_autoextend_percent=20\n}" | sudo tee /etc/lvm/profile/docker-thinpool.profile
sudo lvchange --metadataprofile docker-thinpool docker/thinpool
echo "Logical volume state is:"
sudo lvs -o+seg_monitor
echo -e "FS Config is:\n$(sudo lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL)"
cat /boot/grub/menu.lst |  awk '{ gsub(/console=hvc0/, "console=tty1 console=ttyS0"); print }' | sudo tee /tmp/temp-grub-menu.lst
sudo mv /tmp/temp-grub-menu.lst /boot/grub/menu.lst
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Installing Consul version $CONSUL_VERSION"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
curl -L "https://releases.hashicorp.com/consul/$CONSUL_VERSION/consul_${CONSUL_VERSION}_linux_amd64.zip" -o /tmp/consul.zip
unzip /tmp/consul.zip
sudo cp /tmp/consul /usr/local/bin/
rm -f /tmp/consu*
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Adding the docker GPG to apt-get"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
curl -fsSL https://yum.dockerproject.org/gpg | sudo apt-key add -
apt-key fingerprint 58118E89F3A912897C070ADBF76221572C52609D
sudo add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"
sudo apt-get -qq update
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Installing docker-engine version $DOCKER_MACHINE_VERSION~ubuntu-yakkety"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
echo "" >> /home/ubuntu/.bashrc
echo "# Configuration variables used to build the OpenStudio Server base image"
echo "export DOCKER_MACHINE_VERSION=$DOCKER_MACHINE_VERSION" >> /home/ubuntu/.bashrc
sudo apt-get -y -qq install docker-engine=1.13.0-0~ubuntu-yakkety
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Configuring dockerd with options: $DOCKERD_OPTIONS"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
echo "export DOCKERD_OPTIONS=\"$DOCKERD_OPTIONS\"" >> /home/ubuntu/.bashrc
sudo systemctl enable docker
sudo groupadd docker
sudo usermod -aG docker ubuntu
sudo mkdir /etc/systemd/system/docker.service.d
echo -en "[Service]\nExecStart=\nExecStart=/usr/bin/dockerd $DOCKERD_OPTIONS" | sudo tee -a "/etc/systemd/system/docker.service.d/graph.conf"
sudo systemctl daemon-reload
sudo systemctl restart docker
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Installing docker-compose version $DOCKER_COMPOSE_VERSION"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
echo "export DOCKER_COMPOSE_VERSION=$DOCKER_COMPOSE_VERSION" >> /home/ubuntu/.bashrc
sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sleep 1


echo ""
echo "------------------------------------------------------------------------"
echo "Installing AWS EC2 tools"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
curl "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip" -o "/home/ubuntu/ec2-ami-tools.zip"
sudo mkdir -p /usr/local/ec2
sudo unzip /home/ubuntu/ec2-ami-tools.zip -d /usr/local/ec2
ec2_tools_folder=$(ls /usr/local/ec2)
echo "export EC2_AMITOOL_HOME=/usr/local/ec2/$ec2_tools_folder" >> /home/ubuntu/.bashrc
echo 'export PATH="$EC2_AMITOOL_HOME/bin:$PATH"' >> /home/ubuntu/.bashrc
sudo ln -s /usr/local/ec2/${ec2_tools_folder}/bin/* /bin
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Configuring Consul"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
sudo mkdir -p /etc/consul.d/
sudo mkdir /var/consul
echo -en '{\n\t"bootstrap": true,\n\t"server": true,\n\t"datacenter": "ec2",\n\t"data_dir": "/var/consul",\n' | sudo tee /etc/consul.d/bootstrap.json
echo -en '\t"log_level": "INFO",\n\t"enable_syslog": true,\n' | sudo tee -a /etc/consul.d/bootstrap.json
echo -en '\t"start_join": [],\n\t"retry_join": [],\n\t"client_addr": "0.0.0.0"\n}' | sudo tee -a /etc/consul.d/bootstrap.json
echo -en '{\n\t"datacenter": "ec2",\n\t"bootstrap": false,\n\t"server": true,\n' | sudo tee /etc/consul.d/server.json
echo -en '\t"data_dir": "/var/consul",\n\t"log_level": "INFO",\n\t"enable_syslog": true,\n' | sudo tee -a /etc/consul.d/server.json
echo -en '\t"start_join": [],\n\t"retry_join": [],\n\t"client_addr": "0.0.0.0"\n}' | sudo tee -a /etc/consul.d/server.json
echo -en '[Unit]\nDescription=consul agent\nRequires=network-online.target\n' | sudo tee /etc/systemd/system/consul.service
echo -en 'After=network-online.target\n\n[Service]\nUser=consul\nEnvironmentFile=-/etc/sysconfig/consul\n' | sudo tee -a /etc/systemd/system/consul.service
echo -en 'Environment=GOMAXPROCS=2\nRestart=on-failure\n' | sudo tee -a /etc/systemd/system/consul.service
echo -en 'ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d -bind=INTERNAL_IP_ADDRESS\n' | sudo tee -a /etc/systemd/system/consul.service
echo -en 'ExecReload=/bin/kill -HUP $MAINPID\nKillSignal=SIGTERM\n\n[Install]\nWantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/consul.service
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Rebooting"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
sudo systemctl reboot
sleep 1
