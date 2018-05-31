#!/bin/bash
# Script to use ZFS snapshot to capture an image of an applcation that Actifio can snapshot
#########################
####   BEFORE WE BEGIN
#########################
####   0)  Install Actifio Connector on host  
####   1)  Create ZFS Snapshot on host using your own snapshotname like we set below:    zfs snapshot $snapshotname
####   2)  Create ZFS Clone on host using your own clonename like we set belowe:     zfs clone $snapshotname $clonename
####   3)  On Actifio, Do App Discovery on host, find the ZFS Clone as File system and learn APPID.  
####   4)  Protect the discovered APP but disable protection. 
####   Now create two files on host side, config file with name:    actzfssnap_conf.10792   where 10792 is the APPID
####   Then rename this file to zfssnapshot.10792 and make it executable:  chmod 755 /act/scripts/zfssnapshot.10792
####   Ensure both files are in /act/scripts
####   Also setup SSH so that the script can SSH to Actfio and run udstask and udsinfo commands.


# this script should be runnng in /act/scripts
PWDS=/act/scripts
# we will drop some temp files here
tmp_loc=/act/touch
if [ ! -d $tmp_loc ]; then
 mkdir -p $tmp_loc
fi
# we take the script name to look for the appid.   So If the appd s 123, then the scrpt should be zfsnapshot.123
sname=`basename $0`
appnum=`echo $sname | cut -d '.' -f2`
if [ -z "$appnum" ]; then   
    echo "This script needs the app ID of the protected application as part of its name, e.g:   zfsnaps.123  for appID 123"
    exit 1
fi
# we also use a configuration file so this script doesnt need to be edited.
conffile=$PWDS/actzfssnap_conf'.'$appnum
if [ -f $PWDS/actzfssnap_conf'.'$appnum ]; then
    source $conffile
else
    echo "Configuration File $PWDS/actzfssnap_conf'.'$appnum does not exist or is not located in $PWDS or is misnamed"
    exit 1
fi

# this is the log file we will use.  You should not need to change this unless you want to use different naming standards
logfile=/var/act/log/appid.$appnum.log


#########################
####   FREEZE PHASE - snapshot check
#########################
####   The goal here is for Actifio to snapshot the ZFS Clone on host side, so we need to make sure a snapshot is not running on Actifio side
####   The appname check handles a missing / from the clone name.   It should also find connection issues 
#########################
echo "`date "+%F %T"` ############################### STARTING  ######################" >> $logfile
echo "`date "+%F %T"` ############################### INIT PHASE - CHECK FOR RIGHT APPNAME and RUNNING SNAP ######################" >> $logfile
# this check both confirms the APPID given is valid and also that the Actifio Appliance is reachable
appcheck=$(ssh -o BatchMode=yes  -o ConnectTimeout=30 $actusername@$actip "udsinfo lsapplication -delim } $appnum"  2> /dev/null)
if [ -z "$appcheck" ]; then
    echo "`date "+%F %T"` Failed to connect to Actifio Appliance with command:   ssh $actusername@$actip" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
fi
appname=$(echo "$appcheck" | awk -F"}" '$1=="appname" { print $2 }')
# the ZFS Clone we create gets a bonus / on Actifo side, so we need to handle this, thus we try with or without the first character
if [ "${appname: 1}" == "$clonename" ] || [ "${appname}" == "$clonename" ]; then
    echo "`date "+%F %T"` The Appname ${appname} learned for $appnum matches $clonename" >> $logfile
else
    echo "`date "+%F %T"` The Appname learned for $appnum is $appname which is not the same as $clonename" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
fi
# we check for runnning snapshot against our app
jobcheck=$(ssh $actusername@$actip "udsinfo lsjob -delim } -filtervalue appid=$appnum\&jobclass=snapshot"  2> /dev/null)
if [ -n "$jobcheck" ]; then
    echo "`date "+%F %T"` A snapshot job is currently running against $appnum so we cannot continue" >> $logfile
    echo "`date "+%F %T"` Either cancel the snapshot job or wait for it to finish and try again" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
else
    echo "`date "+%F %T"` No snapshot job is currently running against $appnum so we can continue" >> $logfile
fi
# we learn the policy ID for the snapshot policy so we dont need to code this anywhere
policyid=$(ssh $actusername@$actip "reportpolicies -a $appnum -c -n" 2> /dev/null | awk -F"," '$6=="snap" { print $3 }' | head -1)
if [ -z "$policyid" ]; then
    echo "`date "+%F %T"` No Snapshot policy ID could be learned for appnum $appnum" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
else
    echo "`date "+%F %T"` Snapshot Policy ID $policyid was found for $appnum" >> $logfile
fi


#########################
####   FREEZE PHASE - INITITAL CLEAN UP
#########################
####   The goal here is for Actifio to snapshot the ZFS Clone on host side, so we need to make sure the clone is fresh and new
####   So we will check if any clone and snap exists and if they do, we remove them
#########################
echo "`date "+%F %T"` ############################### INIT PHASE - CHECK FOR OLD CLONE/SNAP ######################" >> $logfile
echo "`date "+%F %T"` Checking for clone $clonename" >> $logfile
clonecheck=$(zfs list $clonename 2>/dev/null)
if [ -n "$clonecheck" ]; then
    echo "`date "+%F %T"` Clone $clonename found with this command:  zfs list $clonename"  >> $logfile
    echo "`date "+%F %T"` Issuing this command:  zfs destroy $clonename" >> $logfile
    zfs destroy $clonename
    clonecheck=$(zfs list $clonename 2>/dev/null)
    if [ -n "$clonecheck" ]; then
        echo "`date "+%F %T"` Failed to remove $clonename"
        echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
        exit 1
    else    
        echo "`date "+%F %T"` Clone $clonename removed successfully" >> $logfile
    fi
else    
    echo "`date "+%F %T"` Clone $clonename was not found, this is good" >> $logfile
fi

echo "`date "+%F %T"` Checking for snapshot $snapshotname" >> $logfile
snapcheck=$(zfs list $snapshotname 2>/dev/null)
if [ -n "$snapcheck" ]; then
    echo "`date "+%F %T"` Snap $snapshotname found, issuing destroy command" >> $logfile
    zfs destroy $snapshotname
    snapcheck=$(zfs list $snapshotname 2>/dev/null)
    if [ -n "$snapcheck" ]; then
        echo "`date "+%F %T"` Failed to destroy $snapshotname"
        echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
        exit 1
    else    
        echo "`date "+%F %T"` Snap $snapshotname destroyed successfully" >> $logfile
    fi
else    
    echo "`date "+%F %T"` Snap $snapshotname was not found, this is good" >> $logfile
fi

# before we go any further lets make sure there is room in the ZFS pool
if [ -n "$maxpoolusage" ]; then
    echo "`date "+%F %T"` Checking pool usage against supplied max value" >> $logfile
    if [ -n "`echo $maxpoolusage | sed 's/[0-9]//g'`" ]; then    
        echo "`date "+%F %T"` Max pool usage was set in the conf file but it is not numeric: $maxpoolusage" >> $logfile
        echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
        exit 1
    else
        if [ "$maxpoolusage" -ge 100 ]; then    
            echo "`date "+%F %T"` Max pool usage of $maxpoolusage% is set to 100% or higher, please set to a lower number" >> $logfile
            echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
            exit 1
        fi
        zpoolname=$(echo $clonename | awk -F"/" '{ print $ 1 }')
        if [ -z "$zpoolname" ]; then
            echo "`date "+%F %T"` Failed to learn zpool name from $clonename" >> $logfile
            echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
            exit 1
        else
            poolstats=$(zpool list -H $zpoolname)
            if [ -n "$poolstats" ]; then    
                poolusage=$(echo "$poolstats" | awk '{ print $5 }')
                if [ -n "$(echo "$poolusage" | grep "%")" ]; then
                    if [ "${poolusage%?}" -gt "$maxpoolusage" ]; then
                        echo "`date "+%F %T"` Pool usage $poolusage for $zpoolname was greater than $maxpoolusage% so we are stopping here"  >> $logfile
                        echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
                        exit 1 
                    else
                         echo "`date "+%F %T"` Pool usage $poolusage for $zpoolname is less than $maxpoolusage% which is good" >> $logfile                       
                    fi
                else
                    echo "`date "+%F %T"` The pool stats learned were: $poolusage   but the fifth field does not appear to be a %" >> $logfile 
                    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
                    exit 1
                fi
            else
                echo "`date "+%F %T"` Failed to learn pool usage with pool name:  $zpoolname " >> $logfile
                echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
                exit 1
            fi
        fi
    fi
fi


#########################
####   Database freeze
#########################
####   We must freeze the database now
#########################

echo "`date "+%F %T"` ############################### FREEZE PHASE - MAKE APP CONSISTENT  ######################" >> $logfile
echo "`date "+%F %T"` Right now we are not doing anything in this phase" >> $logfile



#########################
####   FREEZE PHASE - NEW SNAP AND CLONE
#########################
####   The goal here is to create a new host side snapshot and then clone so the Actfio snapshot will run against them
#########################


echo "`date "+%F %T"` ############################### ZFS SNAP/CLONE PHASE  ######################" >> $logfile
echo "`date "+%F %T"` Creating new snapshot with this command:  zfs snapshot $snapshotname" >> $logfile
zfs snapshot $snapshotname
snapcheck=$(zfs list $snapshotname 2>/dev/null)
if [ -n "$snapcheck" ]; then
    echo "`date "+%F %T"` zfs list $snapshotname  shows snapshot" >> $logfile
    echo "`date "+%F %T"` Creating new clone with this command: zfs clone $snapshotname $clonename" >> $logfile
    zfs clone $snapshotname $clonename
    clonecheck=$(zfs list $clonename 2>/dev/null)
    if [ -n "$clonecheck" ]; then
        echo "`date "+%F %T"` Clone $clonename found, we are ready to start Actifio snapshot" >> $logfile
    else
        echo "`date "+%F %T"` Failed to create $clonename" >> $logfile
        echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
        exit 1
    fi
else
    echo "`date "+%F %T"` Failed to create $snapshotname" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
    exit 1
fi

#########################
####   DATABASE thaw
#########################
####   We can unfreeze the database now
#########################

echo "`date "+%F %T"` ############################### THAW PHASE - RELEASE DB  ######################" >> $logfile
echo "`date "+%F %T"` Right now we are not doing anything in this phase" >> $logfile

#########################
####   SNAPSHOT PHASE - create Actifio side snapshot
#########################
####   The goal here is to start an Actifo snapshot of the ZFS Clone.   Queue is used in case there are no free slots
#########################

echo "`date "+%F %T"` ############################### ACTIFIO SNAPSHOT PHASE  ######################" >> $logfile
echo "`date "+%F %T"` We are now going to run this command:  udstask backup -app $appnum -policy $policyid -queue" >> $logfile

newimage=$(ssh $actusername@$actip "udstask backup -app $appnum -policy $policyid" 2>&1)
backupjob=$(echo "$newimage" | cut -d" " -f1)
if [ "$(echo "$backupjob" | cut -c 1-3)" != "Job" ]; then
	echo "`date "+%F %T"` The job failed with:  $newimage" >> $logfile
    echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
	exit 1
else
	echo "`date "+%F %T"` The following job has started: $backupjob" >> $logfile
fi


#########################
####   MONITOR PHASE 
#########################
####   The goal here is to monitor the Actifio side snapshot,  we will stay here till it succeeds or fails
#########################

while true; do
	jobcheck=$(ssh $actusername@$actip "udsinfo lsjob -delim } $backupjob"  2> /dev/null)
	if [ -z "$jobcheck" ]; then
		history=$(ssh $actusername@$actip udsinfo lsjobhistory -delim } $backupjob)
		status=$(echo "$history" | awk -F"}" '$1=="status" { print $2 }')
		duration=$(echo "$history" | awk -F"}" '$1=="duration" { print $2 }')
		if [ "$status" == "succeeded" ]; then
			echo "`date "+%F %T"` Backup Job Results:" >> $logfile
			echo "`date "+%F %T"` Status:                     $status" >> $logfile
			echo "`date "+%F %T"` Duration:                   $duration" >> $logfile
		else
			echo "`date "+%F %T"` Snapshot $backupjob status does not report as succeeded" >> $logfile
			failedmessage=$(ssh $actusername@$actip udsinfo lsjobhistory -delim } $backupjob | awk -F"}" '$1=="message" { print $2 }')
			echo -n "`date "+%F %T"` The message for this job was: $failedmessage" >> $logfile
            echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
			exit 1
		fi
		break
	else
		data=$(echo "$jobcheck" | awk -F"}" '$1=="progress" { print $2 }')
 		echo "`date "+%F %T"` $backupjob progress:       $data%" >> $logfile
		sleep 30
	fi
done

# we look in the host side UDSAgent log for this
echo "`date "+%F %T"` Checking local log for statistics" >> $logfile
locallogs=$(egrep -i "examined|copied" /var/act/log/UDSAgent.log | grep "files (" | grep $backupjob | awk '{ $1=""; $2=""; print}')
if [ -n "$locallogs" ]; then
    echo "$locallogs" | while read line; do
        echo "`date "+%F %T"` $line"  >> $logfile
    done
else
    echo "`date "+%F %T"` Failed to find any local logs" >> $logfile 
fi

#########################
####   THAW PHASE - REMOVE CLONE AND SNAP
#########################
####   The goal here is to remove the ZFS Clone and Snapshot so they dont get too large.   They are not needed for normal operation
####   Once removed, we are ready for the next run
#########################

echo "`date "+%F %T"` ############################### CLEANUP PHASE - REMOVE ZFS CLONE/SNAPSHOT  ######################" >> $logfile
echo "`date "+%F %T"` Checking for clone $clonename" >> $logfile
clonecheck=$(zfs list $clonename 2>/dev/null)
if [ -n "$clonecheck" ]; then
    echo "`date "+%F %T"` Clone $clonename found, issuing this command:  zfs destroy $clonename" >> $logfile
    zfs destroy $clonename
    clonecheck=$(zfs list $clonename 2>/dev/null)
    if [ -n "$clonecheck" ]; then
        echo "`date "+%F %T"` Failed to destroy $clonename"
        echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
        exit 1
    else
        echo "`date "+%F %T"` Clone $clonename destroyed successfully" >> $logfile
    fi
fi

echo "`date "+%F %T"` Checking for snapshot $snapshotname" >> $logfile
snapcheck=$(zfs list $snapshotname 2>/dev/null)
if [ -n "$snapcheck" ]; then
    echo "`date "+%F %T"` Snap $snapshotname found, issuing this command:  zfs destroy $snapshotname" >> $logfile
    zfs destroy $snapshotname
    snapcheck=$(zfs list $snapshotname 2>/dev/null)
    if [ -n "$snapcheck" ]; then
        echo "`date "+%F %T"` Failed to destroy $snapshotname"
        echo "`date "+%F %T"` ############################### FINISHED IN ERROR ######################" >> $logfile
        exit 1
        else    
        echo "`date "+%F %T"` Snap $snapshotname destroyed successfully, cleanup is complete" >> $logfile
    fi
fi
echo "`date "+%F %T"` ############################### FINISHED SUCCESSFULLY  ######################" >> $logfile
exit 0
