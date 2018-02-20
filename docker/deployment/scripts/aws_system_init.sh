#!/bin/bash

echo ""
echo "------------------------------------------------------------------------"
echo "Updating Ubuntu 17.04 Zesty system"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
echo "REMOVE THE MIRROR ALTERATION UPON UPDATING OS"
sudo sed -i -e 's/us-east-1.ec2.archive.ubuntu.com\|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list
sudo apt-get -qq update
sudo rm -f /boot/grub/menu.lst # https://bugs.launchpad.net/ubuntu/+source/cloud-init/+bug/1485685
sudo apt-get -y -qq upgrade
sudo apt-get -y -qq install curl linux-image-extra-$(uname -r) linux-image-extra-virtual htop iftop unzip lvm2 thin-provisioning-tools
sudo apt-get -y -qq install gdisk kpartx parted ca-certificates software-properties-common apt-transport-https
sudo apt -qq -y install python3
sudo apt -qq -y install ruby
sudo perl -p -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"/g'  /etc/default/grub
sudo /usr/sbin/update-grub
sudo mkdir /mnt/coredumps/ && sudo chown ubuntu:ubuntu /mnt/coredumps && chmod 777 /mnt/coredumps/
echo "/mnt/coredumps/core.%e.%p.%h.%t" | sudo tee /proc/sys/kernel/core_pattern
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Configuring the logical mount volume on /var/lib/docker"
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
sudo lvcreate --wipesignatures y -n graph docker -l 95%VG
sudo mkdir /var/lib/docker
sudo chmod 722 /var/lib/docker
sudo mkfs.ext4 /dev/docker/graph
echo '/dev/docker/graph /var/lib/docker ext4 defaults 0 2' | sudo tee -a /etc/fstab
sudo mount -a
echo -e "FS Config is:\n$(sudo lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL)"
cat /boot/grub/menu.lst |  awk '{ gsub(/console=hvc0/, "console=tty1 console=ttyS0"); print }' | sudo tee /tmp/temp-grub-menu.lst
sudo mv /tmp/temp-grub-menu.lst /boot/grub/menu.lst
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Adding the docker GPG to apt-get"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -qq update
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Installing docker server version $DOCKER_VERSION"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
echo "" >> /home/ubuntu/.bashrc
echo "# Configuration variables used to build the OpenStudio Server base image"
echo "export DOCKER_VERSION=$DOCKER_VERSION" >> /home/ubuntu/.bashrc
sudo apt-get -y -qq install docker-ce=$DOCKER_VERSION~ce-0~ubuntu
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
echo -en "[Service]\nExecStart=\nExecStart=/usr/bin/dockerd $DOCKERD_OPTIONS\n" | sudo tee -a /etc/systemd/system/docker.service.d/config.conf
sudo systemctl daemon-reload
sudo systemctl restart docker
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
echo "Setting IPVS keepalive configuration"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
echo -en "net.ipv4.tcp_keepalive_time = 600\nnet.ipv4.tcp_keepalive_intvl = 60\nnet.ipv4.tcp_keepalive_probes = 5\n" | sudo tee /etc/sysctl.d/ipvs-keepalive.conf
sudo chmod 644 /etc/sysctl.d/ipvs-keepalive.conf
sudo sysctl --system
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Rebooting"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
sudo systemctl reboot
sleep 1
