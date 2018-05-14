#!/bin/bash
# Actifio Copy Data Storage Scripting Team 
# Copyright (c) 2018 Actifio Inc. All Rights Reserved
# This script refreshes mounts
# Version 1.0 Initial Release
# Version 1.1 Specify Component Type 0

 # Declare variables used in the script. 
match=0

# Now check for inputs
while getopts :a:c:i:u:j:l:m:t:hd opt
do
        case "$opt"
        in
                a) appnum="$OPTARG";;
                d) deleteonly=y;;
                i) ipaddress="$OPTARG";;
                j) jobclass="$OPTARG";;
                l) mountlabel="$OPTARG";;
                m) mountpoint="$OPTARG";;
                t) hostnum="$OPTARG";;
                u) username="$OPTARG";;
                h) help=y;;
        esac
done
 
# test for attempts to get help
if [ "$1" == "-h" ] || [ "$1" == "-?" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] 
then
echo "
***************************************************************************************************
This script is intended for the following scenario:
 
1)  There is a source application (known as 'appnum') which is being protected by Actifio
2)  There are hosts which need to access an image of this source app
 
When run this script will:
 
a)  Unmount and delete any existing mount to the specified target host with the specified label
b)  Present the latest image in the selected jobclass to the target host.
 
Labels are used to identify mounts.
To ensure the process works correctly these labels must be unique or the script will not work reliably.
The script will have several variables which must be set at script run time:
 
-a <number>    To select the source application ID
-d             To delete the image without running a new mount job
-i <ip addr>   To specify the Appliance to execute commands against (this could also be a host name)
-j <value>     To specify the jobclass you wish to mount from
-l <value>     To specify the label to be used for mounted and to find the mount later
-m <value>     To specify the mount point to be used when mounting (optional)
-t <number>    To select the target host to mount to (either host ID or host name)  
-u <username>  To specify the user name to run commands against
 
An example of the complete syntax is as follows.
This will access an Actifio appliance with IP address 192.168.103.145.
The username on the Appliance is install.
The source application is 17172 and the desired jobclass is snapshot.
The iumage will be mounted to a host called hq-sql and the label used will be pegasus

mountimage.sh -i 192.168.103.145 -u install -a 17172 -t hq-sql -l pegasus -j snapshot 
 
***************************************************************************************************"
exit 0
fi

# If we don't have an ipaddress  we will complain   Dont test for numeric in case they use names
if [ -z "$ipaddress" ];then
	echo "Please use a valid IP address with:   -i <ipaddress>"
	echo "For instance for ipaddress 1.2.3.4:   -i 1.2.3.4"
	exit 0
fi

# If we dont have a username we will complain
if [ -z "$username" ]; then
	echo "Please specify a username with:     -u <username>"
	echo "For instance for username george:   -u george"
	exit 0
fi

# If we don't have an app ID or the app ID is not numeric we will complain
if [ -z "$appnum" ] || [ -n "`echo $appnum | sed 's/[0-9]//g'`" ]; then
	echo "Please use a numeric appid with: -a <appid>"
	echo "For instance for appid 1234:     -a 1234"
	exit 0
fi

# If we don't have a host ID we will complain - can be name or ID
if [ -z "$hostnum" ]; then
	echo "Please use a valid host id with:  -t <hostid>"
	echo "For instance for host id 5678:    -t 5678"
	echo "Or for instance host name hq-sql: -t hq-sql"
	exit 0
fi

# If we dont have a label we will complain
if [ -z "$mountlabel" ]; then
	echo "Please specify a label with:          -l <labelname>"
	echo "For instance for label name pegasus:  -l pegasus"
	exit 0
fi

# If we didn't get a jobclass, then complain
if [ -z "$jobclass" ] ; then
	echo "Please specify a jobclass with:   -j <jobclass>"
	echo "For instance for snapshots use:   -j snapshot"
	exit 0
fi

#First define valid jobclass list.  You can just add to the list if one got missed!
jobclasslist="dedup
dedupasync 
directdedup 
liveclone 
remote-dedup 
snapshot"

# Lets just make sure we can search for that class
for jobtype in $jobclasslist; do
	[[ "$jobclass" == "$jobtype" ]] && match=1
done
if [ "$match" -ne 1 ];then
	echo "$jobclass is not a valid Job Class."
	echo "Please use one of the following:"
	echo "$jobclasslist"
	exit 0
fi

# does the host exist 
hostid=$(ssh $username@$ipaddress udsinfo lshost -delim , $hostnum 2>&1 | awk -F"," '$1=="id" { print $2 }') 
if [ -z $hostid ]; then
	echo "The host specified does not exist"
	echo "Validate host name or ID using:  udsinfo lshost"
	exit 0
fi 

# is there an image to mount?
newimageid=$(ssh $username@$ipaddress "udsinfo lsbackup -filtervalue jobclass=$jobclass\&appid=$appnum\&componenttype=0 -nohdr -delim } 2>&1 | tail -1 | cut -d} -f19")
if [ -z $newimageid ] && [ "$deleteonly" != "y" ]; then
	echo "There are no images in that jobclass so there is nothing to mount"
	echo "Try a different jobclass or validate you are using the correct application ID"
	exit 0
fi
 
 
# Label check
echo "Checking for mounts to host $hostnum with a label of $mountlabel"
mountedname=$(ssh $username@$ipaddress "udsinfo lsbackup -filtervalue label=$mountlabel\&jobclass=mount\&mountedhost=$hostid -delim } -nohdr | cut -d} -f19")
 
# Check if we found more than one mount, exit if we did
mountcount=$(echo "$mountedname" | wc -l)
if [ $mountcount -gt 1 ]; then
	echo "There are multiple mounts with the same label $mountlabel.  Please use unique labels when mounting.  Please use a different label or manually unmount the other mounts"
	echo "The mounts are as follows:"
	ssh $username@$ipaddress "udsinfo lsbackup -filtervalue label=$mountlabel\&jobclass=mount\&mountedhost=$hostid"
	exit 0
fi
 
# If we found one mount then unmount it
if [ -n "$mountedname" ]; then
	echo "Unmounting and deleting the existing mount $mountedname with label $mountlabel"
	unmount=$(ssh $username@$ipaddress "udstask unmountimage -delete -image $mountedname -nowait 2>&1")
	unmountjob=$(echo "$unmount" | cut -d" " -f1)
	#  Now monitor the running job
	while true; do
		jobcheck=$(ssh $username@$ipaddress udsinfo lsjob -delim } $unmountjob  2> /dev/null)
		if [ -z "$jobcheck" ]; then
			history=$(ssh $username@$ipaddress udsinfo lsjobhistory -delim } $unmountjob)
			status=$(echo "$history" | awk -F"}" '$1=="status" { print $2 }')
			duration=$(echo "$history" | awk -F"}" '$1=="duration" { print $2 }')
			if [ "$status" == "succeeded" ]; then
				echo "Unmount Job Results:"
				echo "Status:                     $status"
				echo "Duration:                   $duration"
				echo ""
			else
				echo "An error occurred while unmounting the image with label $mountlabel, please investigate $unmountjob"
				echo -n "The message for this failed job was: "
				ssh $username@$ipaddress udsinfo lsjobhistory -delim } $unmountjob| awk -F"}" '$1=="message" { print $2 }'
				exit 0
			fi
			break
		else
			data=$(echo "$jobcheck" | awk -F"}" '$1=="progress" { print $2 }')
 			echo "$unmountjob progress:       $data%"
			sleep 5
		fi
	done
else
	echo "There were no mounted images with label $mountlabel"
fi
 
if [ "$deleteonly" == "y" ]; then
	exit 0 
fi
 
# Now mount the latest image in jobclass to the target host
echo "Mounting $jobclass image $newimageid to host $hostnum"
if [ -n "$mountpoint" ]; then
	mount=$(ssh $username@$ipaddress "udstask mountimage -image $newimageid  -host $hostnum -label $mountlabel -restoreoption "mountpointperimage=$mountpoint" -nowait 2>&1")
else
	mount=$(ssh $username@$ipaddress "udstask mountimage -image $newimageid  -host $hostnum -label $mountlabel -nowait 2>&1")
fi
mountjob=$(echo "$mount" | cut -d" " -f1)
 
#  Now monitor the running job
while true; do
	jobcheck=$(ssh $username@$ipaddress udsinfo lsjob -delim } $mountjob  2> /dev/null)
	if [ -z "$jobcheck" ]; then
		history=$(ssh $username@$ipaddress udsinfo lsjobhistory -delim } $mountjob)
		status=$(echo "$history" | awk -F"}" '$1=="status" { print $2 }')
		duration=$(echo "$history" | awk -F"}" '$1=="duration" { print $2 }')
		if [ "$status" == "succeeded" ]; then
			echo "Mount Job Results:"
			echo "Status:                     $status"
			echo "Duration:                   $duration"
		else
			echo "An error occurred while mounting the image to $hostnum, please investigate $mountjob"
			echo -n "The message for this failed job was: "
			ssh $username@$ipaddress udsinfo lsjobhistory -delim } $mountjob| awk -F"}" '$1=="message" { print $2 }'
			exit 0
		fi
		break
	else
		data=$(echo "$jobcheck" | awk -F"}" '$1=="progress" { print $2 }')
 		echo "$mountjob progress:       $data%"
		sleep 5
	fi
done
