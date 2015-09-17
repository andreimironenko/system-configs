#! /bin/bash

# This script extends the root file system partition to the whole disk

# Device
DEV="/dev/mmcblk0"
PART1="/dev/mmcblk0p1"
PART2="/dev/mmcblk0p2"

FLAGDIR="/usr/share/config-data"
FLAG="$FLAGDIR/extendpart.flag"

# Default cylinder size
CYLN_SIZE_BYTES=8225280

if [ ! -d $FLAGDIR ] ; then
	mkdir -p $FLAGDIR	
fi


if [ ! -f $FLAG ] ; then
	#Delete existing partitions
	dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=1

	SD_SIZE=`fdisk -l $DEV | grep Disk | grep bytes | awk '{print $5}'`
	SD_SIZE_CYLN=$(( $SD_SIZE/255/63/512 ))
	printf "%s\n" "SD_SIZE_CYLN=$SD_SIZE_CYLN"

	#Partition sizes 
	ROOT_PART_SIZE_CYLN=$(($SD_SIZE_CYLN/2))
	USER_PART_SIZE_CYLN=$(($SD_SIZE_CYLN/2 - 3))
	printf "%s\n" "ROOT_PART_SIZE_CYLN=$ROOT_PART_SIZE_CYLN"
	printf "%s\n" "USER_PART_SIZE_CYLN=$USER_PART_SIZE_CYLN"
	
	printf "%s" "Creating partition table ..."
	{
	 echo "2,$(($ROOT_PART_SIZE_CYLN)),,-"
	 echo "$(($ROOT_PART_SIZE_CYLN +3)),$USER_PART_SIZE_CYLN,,-"
	} | sfdisk --force --heads 255 --sectors 63 --cylinders $SD_SIZE_CYLN $DEV

	#Set the flag to indicate 
	touch $FLAG 

	#Force the system to reboot 
	/etc/init.d/watchdog stop

else 
	# Start root file system resizing
	resize2fs $PART1
	mkfs.ext3 $PART2 -L data
	
	mkdir -p /usr/local
	echo "/dev/mmcblk0p2 /usr/local ext3 rw,relatime,errors=continue,user_xattr,data=writeback 0 0" >> /etc/fstab
	sync
	mount -a

	# Adding user data to the newly created partition
	pushd ${PWD}
	cd /boot
	if [ -f data.zip ] ; then
		unzip -o data.zip -d /
	fi
	popd	
	
	# Creating symlink to /usr/local/update in /media folder
	# This must be done for the sake of the compatibility with older 
	# mechanism update which can be found on some IPTFTs
	pushd ${PWD}
	cd /media
	ln -sf /usr/local/update update
	popd
	
	# Update procedure and NFS export requires directory structure to be created
	# under /usr/local/update prio to the start of the update process
	mkdir -p /usr/local/update/tmp
	mkdir -p /usr/local/update/log
	mkdir -p /usr/local/update/obc-iv/ipk/stib
	mkdir -p /usr/local/update/obc-iv/ipk/ip_tft
	mkdir -p /usr/local/update/obc-iv/ipk/ip_led
	
	# Syncing to media device	
	sync
	
	# Removing extendpart symlink from rc5.d, to avoid starting it after next 
	# reboot
	rm $FLAG 
	rm /etc/rc5.d/S99extendpart
	
	#Force the system to reboot 
	/etc/init.d/watchdog stop
fi

exit 0