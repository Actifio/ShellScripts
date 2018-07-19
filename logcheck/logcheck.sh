#!/bin/bash
# Actifio Copy Data Storage Scripting Team 
# Copyright (c) 2018 Actifio Inc. All Rights Reserved
# This script checks log utilization and runs a log backup if too high
# Version 1.0 Initial Release
# Version 1.1 Major rework

# Now check for inputs
while getopts :i:u:a: opt
do
        case "$opt"
        in
                a) appname="$OPTARG";;
                i) actifoip="$OPTARG";;
                u) username="$OPTARG";;
        esac
done

# we can change these values:
logfile=~/logcheck.txt
timeout=120

# this rotates the log file.   We keep only the current and previous.  Hash this line out if you want to keep growing the one file
[[ -f "$logfile" ]] && mv $logfile $logfile.old

# If we don't have an actifo ip  we will complain 
if [ -z "$actifoip" ];then
	echo "Please define a valid IP address" 
	exit 1
fi

# If we dont have a username we will complain
if [ -z "$username" ]; then
	echo "Please define a username"
	exit 1
fi

#  we need an appid
if [ -z "$appname" ]; then
	echo "Please define an appname"
	exit 1
fi

#  given we have made it this far we are now ready to start
echo "-------------------------------------------" >> $logfile
echo "`date "+%F %T"`  Starting run" >> $logfile

# we need to learn the app ID.  By using batch mode and connect timeout we also test we can connect to Actifio Appliance without password
appid=$(ssh -o BatchMode=yes  -o ConnectTimeout=30 $username@$actifoip "udsinfo lsapplication -delim , -filtervalue appname=$appname\&apptype=Oracle -nohdr" | awk -F"," '{ print $1 }')
if [ -z "$appid" ]; then
    echo "`date "+%F %T"`  No AppID could be learned for app $appname" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
fi
if [ "$(echo "$appid" | wc -l)" -ne "1" ]; then    
    echo "`date "+%F %T"`  More than one AppID could be learned for app $appname" >> $logfile
    echo "`date "+%F %T"`  $appid" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
fi

echo "`date "+%F %T"`  Appid $appid was found for $appname" >> $logfile


# we learn the policy ID for the snapshot policy.  We do this first as a test we can connect to Appliance and use the appid as well
policyid=$(ssh $username@$actifoip "reportpolicies -a $appid -c -n" 2> /dev/null | awk -F"," '$6=="snap" { print $3 }' | head -1)
if [ -z "$policyid" ]; then
    echo "`date "+%F %T"`  No Snapshot policy ID could be learned for app $appname" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
else
    echo "`date "+%F %T"`  Snapshot Policy ID $policyid was found for $appname" >> $logfile
fi

# now we look for competing snapshot job running for our app
echo "`date "+%F %T"`  Checking for a running snapshot job for $appname" >> $logfile
runningjob=$(ssh $username@$actifoip "udsinfo lsjob -delim } -nohdr -filtervalue jobclass=snapshot\&appid=$appid\&status=running" | awk -F"}" '{ print $5 }') 
if [ -n "$(echo "$runningjob")" ]; then
    echo "`date "+%F %T"`  Snapshot $runningjob was already running for Appname $appname" >> $logfile
fi

if [ -z "$(echo "$runningjob")" ]; then
    echo "`date "+%F %T"`  No running job found for Appname $appname, we will need to start one" >> $logfile
    runningjob=$(ssh $username@$actifoip "udstask backup -app $appid -policy $policyid -backuptype log -queue")
    if [ "${runningjob:0:3}" == "Job" ]; then 
        echo "`date "+%F %T"`  Started this job: $runningjob" >> $logfile
    else
        echo "`date "+%F %T"`  Got this message when trying to start job: $runbackup" >> $logfile
        echo "`date "+%F %T"`   ############################### FINISHED IN ERROR ######################" >> $logfile
        exit 1
    fi
fi

# now we monitor the running job
interval=0
jobfound=y
sleeptime=55
echo "`date "+%F %T"`  Loop check to monitor snapshot $runningjob is still running" >> $logfile
while [ "$jobfound" == "y" ]; do
    runcheck=$(ssh $username@$actifoip "udsinfo lsjob -filtervalue jobname=$runningjob") 
    if [ -n "$(echo "$runcheck")" ]; then
        interval=$[$interval+1]
        echo "`date "+%F %T"`  $runningjob is still running.  This was check $interval of $timeout. Sleeping $sleeptime seconds" >> $logfile
        if [ $interval -gt $timeout ]; then
            echo "`date "+%F %T"`   We have checked for $timeout times.  Giving up" >> $logfile
            exit 0
        fi
        sleep $sleeptime
    else
        echo "`date "+%F %T"`  $runningjob is no longer running" >> $logfile
        jobfound=n
    fi
done

# now we learn the most recent log backup date
lastsnap=$(ssh $username@$actifoip "udsinfo lsbackup -filtervalue appid=$appid\&jobclass=snapshot -delim , -nohdr" | awk -F"," 'END{ print $1 }')
lasthostlog=$(ssh $username@$actifoip "udsinfo lsbackup -delim , $lastsnap" | awk -F"," '$1=="  hostendpit" { print $2 }')
echo "`date "+%F %T"`  Logs found till this date:  $lasthostlog" >> $logfile
echo "`date "+%F %T"`   ############################### FINISHED ######################" >> $logfile
