#!/bin/bash

echo ""
echo "------------------------------------------------------------------------"
echo "Expanding the logical volume docker-thinpool"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
old_sectors="$(sudo blockdev --getsize64 /dev/docker/thinpool)"
echo "Original sector count for 'docker-thinpool' is $old_sectors"
if [ "$(sudo lsblk -o NAME | grep xvda1)" = '└─xvda1' ]; then
	sudo vgextend docker /dev/xvdb
	sudo vgextend docker /dev/xvdc
	sudo vgextend docker /dev/xvdd
	sudo vgextend docker /dev/xvde
	sudo vgextend docker /dev/xvdf
	sudo vgextend docker /dev/xvdg
else
	sudo vgextend docker /dev/sdb
	sudo vgextend docker /dev/sdc
	sudo vgextend docker /dev/sdd
	sudo vgextend docker /dev/sde
	sudo vgextend docker /dev/sdf
	sudo vgextend docker /dev/sdg
fi
sudo lvextend -l+100%FREE -n /dev/docker/thinpool
new_sectors="$(sudo blockdev --getsize64 /dev/docker/thinpool)"
echo "New sector count for 'docker-thinpool' is $new_sectors"
docker_thinpool_table="$(sudo dmsetup table docker-thinpool)"
echo "Original devicemapper table for 'docker-thinpool' is: \"$docker_thinpool_table\""
new_table=${docker_thinpool_table/${old_sectors}/${new_sectors}}
echo "New devicemapper table for 'docker-thinpool' will be: \"$new_table\""
sudo dmsetup suspend docker-thinpool && sudo dmsetup reload docker-thinpool --table "$new_table" && sudo dmsetup resume docker-thinpool