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