#! /bin/bash

#Check if ht5 is on

MOUNTNFS_CONF="/etc/mountnfs.conf"

if [ ! -f ${MOUNTNFS_CONF} ] ; then
	printf "%s\n" "System configuration file /etc/mountnfs.conf is not found!"
	printf "%s\n" "NFS mount has stopped ..."
	exit 1 
fi

# This flag will indicate either the network connection was lost
# 0 - connection was stable
# 1 - connection was lost
net_disconnect_flag="1"

# This flag will indicate either NFS connection was dropped
nfs_disconnect_flag="1"

# This flag will indicate that the NFS mount attempt has failed
nfs_mount_failed_flag="1"

# Hosts list
hosts=( $(awk '!/^($|[:space:]*#)/{print $1;}' $MOUNTNFS_CONF) )
nfs_remote_dirs=( $(awk '!/^($|[:space:]*#)/{print $2;}' $MOUNTNFS_CONF) )
nfs_mount_points=( $(awk '!/^($|[:space:]*#)/{print $3;}' $MOUNTNFS_CONF) )

if [ ${#hosts[*]} -eq "0" -o ${#nfs_remote_dirs[*]} -eq "0" -o ${#nfs_mount_points[*]} -eq "0" ] ; then
	printf "%s\n" "Syntax error in $MOUNTNFS_CONF! Each line must be:"
	printf "\t%s\n" "host remote_dir mount_point"
	printf "%s\n" "Line started with \"#\" is commented out" 
	exit 1
fi
	
if [ ${#hosts[*]} -ne ${#nfs_remote_dirs[*]}  -o ${#hosts[*]} -ne ${#nfs_mount_points[*]} -o ${#nfs_mount_points[*]} -ne ${#nfs_remote_dirs[*]} ] ; then
	printf "%s\n" "Syntax error in $MOUNTNFS_CONF! Each line must be:"
	printf "\t%s\n" "host remote_dir mount_point"
	printf "%s\n" "Line started with \"#\" is commented out" 
	exit 1
fi
	

printf "%s\n" "Requested mounts:"
for (( i=0; i < ${#hosts[*]} ; i++ )) ; do

	printf "%s\n" "${hosts[$i]}:${nfs_remote_dirs[$i]} ${nfs_mount_points[$i]}"
done

#Check if mount points exist	
for (( d=0; d < ${#nfs_mount_points[@]}; d++ )) ; do
	if [ ! -d "${nfs_mount_points[$d]}" ] ; then
		printf "%s\n" "#$d ${nfs_mount_points[$d]} does not exist, create"
		mkdir -p ${nfs_mount_points[$d]} 
	fi
done

function maintain_nfs_mount ()
{
	local host=$1
	local nfs_remote_dir=$2
	local nfs_mount_point=$3

while true;  do
	#Check physical network connection first
	ping -w 1 ${host} 
	network_status=$?
	if [ $network_status -eq "0" ] ; then
		net_disconnect_flag="0";
	else
		net_disconnect_flag="1";	
	fi	

	# Also check NFS 	
	showmount -e ${host} 
	nfs_status=$?
	
	if [ $nfs_status -eq "0" ] ; then
		nfs_disconnect_flag="0"
		#Seems the mounts exist check each of the folder against of stale NFS
		test -d ${nfs_mount_point}
		nfs_disconnect_flag=$?
	else
		nfs_disconnect_flag="1"
	fi

	if [ $network_status -ne "0"  -o $nfs_status -ne "0" ] ; then
		echo "${host} is not present ..."
		
		printf "%s\n" "Unmounting ${nfs_mount_point}"
		umount "${nfs_mount_point}"

		echo "Sleep for the next 15 seconds..."
		sleep 15
		nfs_mount_failed_flag="1"
		continue;
	else
		
		if [ "$net_disconnect_flag" -eq "1" -o "$nfs_disconnect_flag" -eq "1" -o "$nfs_mount_failed_flag" -eq "1" ] ; then
			# If connection lost flag is set then we deal with reconnecting.
			# To restore connection we need first to unmount and then to mount NFS 
			# shares again
			printf "%s\n" "Connection was lost!"
			printf "%s\n" "net_disconnect_flag=$net_disconnect_flag" 
			printf "%s\n" "nfs_disconnect_flag=$nfs_disconnect_flag"
			printf "%s\n" "nfs_mount_failed_flag=$nfs_mount_failed_flag"
			
			printf "%s\n" "Unmounting ${nfs_mount_point}"
			umount "${nfs_mount_point}"
		else
			printf "%s\n" "It's a periodical connection check"
			sleep 15
			continue;
		fi	
 
		
		# Let's try to mount the NFS shares
		# status flag is changed to non-zero value if something goes wrong	
		status=0;	
		printf "%s\n" "Trying to mount ${nfs_remote_dir}"
		busybox mount -t nfs ${host}:${nfs_remote_dir} ${nfs_mount_point} 
		if [ "$?" -ne "0" ] ; then
			status=$?
		fi
		

		# 15 seconds should be enough for ht5 to start NFS server after first moment
		# when we detected it on the network 
		mounts_attempt_counter=5
		while [ "$status" -ne "0" ] ; do 
		
			printf "%s\n" "NFS mount has failed, decreasing a mount counter" 
			let "mounts_attempt_counter --"
			if [ "$mounts_attempt_counter" -eq "0" ]; then
				break;
			fi		

			printf "%s\n" "Sleep for 3 secs"
			sleep 3 

			printf "%s\n" "Trying to mount ${nfs_remote_dir}"
			busybox mount -t nfs ${host}:${nfs_remote_dir} ${nfs_mount_point} 
			if [ "$?" -ne "0" ] ; then
				status=$?
				printf "%s\n" "Mount for #$d ${host}:${nfs_remote_dir} ${nfs_mount_point} has failed"
			fi
		done
		
		if [ "$mounts_attempt_counter" -eq "0" ] ; then
			nfs_mount_failed_flag="1"
		else
			nfs_mount_failed_flag="0"
		fi
		continue;
	fi
done
}

for (( i=0 ; i < ${#hosts[*]} ; i ++ )) ; do
	maintain_nfs_mount ${hosts[$i]} ${nfs_remote_dirs[$i]} ${nfs_mount_points[$i]} & 
done 

#Wait for all jobs to complete, but as all jobs are running in infinite loop
wait

exit 0