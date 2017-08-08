#!/bin/bash

echo ""
echo "------------------------------------------------------------------------"
echo "Expanding the logical volume mount docker/docker-graph"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
echo "Original FS Config is:\n$(sudo lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL)"
if [ "$(sudo lsblk -o NAME | grep xvda1)" = '└─xvda1' ]; then
    sudo umount /dev/xvdb
	sudo vgextend docker -y /dev/xvdb
	sudo vgextend docker -y /dev/xvdc
	sudo vgextend docker -y /dev/xvdd
	sudo vgextend docker -y /dev/xvde
	sudo vgextend docker -y /dev/xvdf
	sudo vgextend docker -y /dev/xvdg
else
	sudo vgextend docker -y /dev/sdb
	sudo vgextend docker -y /dev/sdc
	sudo vgextend docker -y /dev/sdd
	sudo vgextend docker -y /dev/sde
	sudo vgextend docker -y /dev/sdf
	sudo vgextend docker -y /dev/sdg
fi
sudo lvextend -l+95%FREE -n docker/graph
sudo resize2fs /dev/docker/graph
echo "New FS Config is:\n$(sudo lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL)"
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Loading the swarm token and connecting to the docker swarm"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
