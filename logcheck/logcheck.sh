#!/bin/bash
# Actifio Copy Data Storage Scripting Team 
# Copyright (c) 2018 Actifio Inc. All Rights Reserved
# This script checks log utilization and runs a log backup if too high
# Version 1.0 Initial Release

# we can change these values:
logfile=~/logcheck.txt
actifoip=10.11.1.1
username=admin
appid=4855

# this rotates the log file.   We keep only the current and previous.  Hash this line out if you want to keep growing the one file
[[ -f "$logfile" ]] && mv $logfile $logfile.old

# If we don't have an actifoip  we will complain 
if [ -z "$actifoip" ];then
	echo "Please define a valid IP address" 
	exit 0
fi

# If we dont have a username we will complain
if [ -z "$username" ]; then
	echo "Please define a username"
	exit 0
fi

#  we need an appid
if [ -z "$appid" ]; then
	echo "Please define an appid"
	exit 0
fi

#  given we have made it this far we are now ready to start
echo "-------------------------------------------" >> $logfile
echo "`date "+%F %T"`  Starting run" >> $logfile

# we learn the policy ID for the snapshot policy.  We do this first as a test we can connect to Appliance and use the appid as well
policyid=$(ssh -o BatchMode=yes  -o ConnectTimeout=30 $username@$actifoip "reportpolicies -a $appid -c -n" 2> /dev/null | awk -F"," '$6=="snap" { print $3 }' | head -1)
if [ -z "$policyid" ]; then
    echo "`date "+%F %T"`  No Snapshot policy ID could be learned for appnum $appid" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
else
    echo "`date "+%F %T"`  Snapshot Policy ID $policyid was found for $appid" >> $logfile
fi

# now we look for competing mount or unmount job running on target host
echo "`date "+%F %T"`  Checking for a running snapshot job" >> $logfile
snapcheck=$(ssh $username@$actifoip "udsinfo lsjob -delim } -nohdr -filtervalue jobclass=snapshot\&appid=$appid\&status=running" 2>&1 | awk -F"}" '{ print $5 }') 
if [ -n "$(echo "$snapcheck")" ]; then
    echo "`date "+%F %T"`  Snapshot Job $snapcheck is running for Appid $appid" >> $logfile
    echo "`date "+%F %T"`  Exiting because $snapcheck for $appid is already running" >> $logfile
    exit 0
else
    echo "`date "+%F %T"`  No running job found for Appid $appid, continuing" >> $logfile
fi

# Now run the backup
echo "`date "+%F %T"`  We are now going to run the backup" >> $logfile
runbackup=$(ssh $username@$actifoip "udstask backup -app $appid -policy $policyid -backuptype log -queue")
if [ "${runbackup:0:3}" == "Job" ]; then 
    echo "`date "+%F %T"`  Started this job: $runbackup" >> $logfile
    echo "`date "+%F %T"`  Exiting with success" >> $logfile
    exit 0
else    
    echo "`date "+%F %T"`  Got this message when trying to start job: $runbackup" >> $logfile
    echo "`date "+%F %T"`   ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
fi
