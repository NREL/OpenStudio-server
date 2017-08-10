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
echo "Generating the swarm token and swarm join command"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
internalip=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
docker swarm init --advertise-addr=$internalip > /home/ubuntu/token.txt
tokentxt=$(</home/ubuntu/token.txt)
tempvar=${tokentxt##*d:}
tempcmd=${tempvar%%To*}
echo ${tempcmd//\\/} > /home/ubuntu/swarmjoin.sh
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Re-instantiating the private registry with the regdata volume"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker service create --name registry --publish 5000:5000 --mount type=volume,source=regdata,destination=/var/lib/registry registry:2.6
while ( nc -zv $internalip 5000 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
echo "registry initialized"
sleep 1
