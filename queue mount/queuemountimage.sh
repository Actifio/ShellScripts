#!/bin/bash
# Actifio Copy Data Storage Scripting Team 
# Copyright (c) 2018 Actifio Inc. All Rights Reserved
# This script queues mounts
# Version 1.0 Initial Release

# Now check for inputs
while getopts :hi:m:u:w:t: opt
do
        case "$opt"
        in
                h) help=y;;
                i) ipaddress="$OPTARG";;
                m) mountcommand="$OPTARG";;
                t) targethost="$OPTARG";;
                u) username="$OPTARG";;
        esac
done
 
# test for attempts to get help
if [ "$1" == "-h" ] || [ "$1" == "-?" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] 
then
echo "
***************************************************************************************************
This script is intended for the following scenario:
 
We need to run a mount against a host but cater for the chance a mount is already running
 
When run this script will:
1)  Check no mount job is running
2)  Run a mount

View this script as a replacement for 'udstask mountimage'

The script will have several variables which must be set at script run time:

-i <ip addr>   To specify the Appliance to execute commands against (this could also be a host name) 
-p <policy ID> To specify policy ID
-t <targethost> To specify the hostname of the target host for the workflow (optional)
-u <username>  To specify the user name to run commands against

So if you were going to run the following command with username ted on Appliance 10.1.1.1

ssh ted@10.1.1.1 udstask mountimage -host demo-mgmt-4 -appid 5434

You would instead run:

queuemountimage.sh -u ted -i 10.1.1.1  -m '-host demo-mgmt-4 -appid 5434'
***************************************************************************************************"
exit 0
fi

# we could change these values:
logfile=~/queuemountimagelog.txt
timeout=120

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

#  we need a mount command
if [ -z "$mountcommand" ]; then
	echo "Please specify a mount command with:     -m '<mount command>'"
    echo "For instance  -m '-host demo-mgmt-4 -appid 5434'"
	exit 0
fi

# we need to learn the hostname from the mount command
hostsearch=$(echo "$mountcommand" | perl -ne 'while(m/-host (.*?) /g){ print $1 }' )
if [ -z "$hostsearch" ]; then
	echo "Failed to find a hostname in the mount command that was specified with -host"
	exit 0
fi

#  given we have made it this far we are now ready to start


echo "-------------------------------------------" >> $logfile
echo "`date "+%F %T"`  Starting mount run" >> $logfile
 
# now we look for competing mount or unmount job running on target host
if [ -n $targethost ]; then
	interval=0
	runningjob=y
	while [ "$runningjob" == "y" ]; do
		echo "`date "+%F %T"`  Checking for a running job to the target host: $hostsearch" >> $logfile
		mountcheck=$(ssh $username@$ipaddress "udsinfo lsjob -delim } -nohdr -filtervalue jobclass=mount" 2>&1 | awk -F"}" '{ print $26 }') 
		if [ -n "$(echo "$mountcheck" | grep $hostsearch)" ]; then
			interval=$[$interval+1]
			echo "`date "+%F %T"`  Job is running on the target host.  This was check $interval of $timeout. Sleeping 55 seconds" >> $logfile
			if [ $interval -gt $timeout ]; then
	  		    echo "`date "+%F %T"`   We have checked for $timeout times.  Giving up" >> $logfile
	  		    exit 0
			fi
			sleep 55
		else
			echo "`date "+%F %T"`  No running job found targetng $hostsearch, continuing" >> $logfile
			runningjob=n
		fi
	done
fi

# Now run the mount
echo "`date "+%F %T"`  We are now going to run the mount" >> $logfile
runmount=$(ssh $username@$ipaddress "udstask mountimage $mountcommand -nowait")
echo "`date "+%F %T"`  $runmount" >> $logfile
