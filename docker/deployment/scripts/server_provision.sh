#!/bin/bash

echo ""
echo "------------------------------------------------------------------------"
echo "Expanding the logical volume docker-thinpool"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
old_sectors="$(($(sudo blockdev --getsize64 /dev/docker/thinpool)/512))"
echo "Original 512 sector count for 'docker-thinpool' is $old_sectors"
docker_thinpool_table="$(sudo dmsetup table docker-thinpool)"
echo "Original devicemapper table for 'docker-thinpool' is: \"$docker_thinpool_table\""
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
sudo lvextend -l+100%FREE -n docker/thinpool
new_sectors="$(($(sudo blockdev --getsize64 /dev/docker/thinpool)/512))"
echo "New 512 sector count for 'docker-thinpool' is $new_sectors"
new_table=${docker_thinpool_table/${old_sectors}/${new_sectors}}
echo "New devicemapper table for 'docker-thinpool' will be: \"$new_table\""
sudo dmsetup suspend docker-thinpool && sudo dmsetup reload docker-thinpool --table "$new_table" && sudo dmsetup resume docker-thinpool
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
echo "Creating the private registry and pushing the local images"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker service create --name registry --publish 5000:5000 registry:2.6
while ( nc -zv $internalip 5000 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
echo "registry initialized"
docker tag nrel/openstudio-server:OSSERVER_DOCKERHUB_TAG localhost:5000/openstudio-server
docker tag nrel/openstudio-rserve:OSSERVER_DOCKERHUB_TAG localhost:5000/openstudio-rserve
docker tag mongo localhost:5000/mongo
docker push localhost:5000/openstudio-server
docker push localhost:5000/openstudio-rserve
docker push localhost:5000/mongo
