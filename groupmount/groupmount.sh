
#!/bin/bash

grouplabel=devcorpgrp

sqlsourceapp=4779
sqldbname=dvcorsql
sqltargehost=sydwinsql2
sqlinstance=sydwinsql2

oraclesourceapp=5456
oracledbname=dvcorora
oracletargethost=1778304
oraclehome="/u01/app/oracle/product/11.2.0.4/ora_1"

recoverytime="2019-11-26 18:30:00"

applianceuser=av
applianceip=10.65.5.35

# checking for log window
rpocheck=$(ssh $applianceuser@$applianceip "reportrpo -n -c -a $sqlsourceapp")
snapdate=$(echo $rpocheck | cut -d, -f10)
logdate=$(echo $rpocheck | cut -d, -f9)
[[ "$snapdate" > "$recoverytime" ]] && echo "Most recent Snap date for $sqlsourceapp is after recovery time" && exit 0
[[ "$logdate" < "$recoverytime" ]] && echo "Lastest Log date for $sqlsourceapp is before recovery time" && exit 0
echo "SQL App most recent snap is $snapdate and log date is $logdate which works with requested $recoverytime"

rpocheck=$(ssh $applianceuser@$applianceip "reportrpo -n -c -a $oraclesourceapp")
snapdate=$(echo $rpocheck | cut -d, -f10)
logdate=$(echo $rpocheck | cut -d, -f9)
[[ "$snapdate" > "$recoverytime" ]] && echo "Most recent Snap date for $oraclesourceapp is after recovery time" && exit 0
[[ "$logdate" < "$recoverytime" ]] && echo "Lastest Log date for $oraclesourceapp is before recovery time" && exit 0
echo "Oracle App most recent snap is $snapdate and log date is $logdate which works with requested $recoverytime"

echo "checking for mounts using label $grouplabel"
#check for mounts
mountcheck=$(ssh $applianceuser@$applianceip "udsinfo lsbackup -delim , -nohdr -filtervalue label=$grouplabel")
if [ -n "$mountcheck" ]; then
	echo "Found mounts"
	echo "$mountcheck" | while IFS="," read -ra data; do
		echo "Unmounting image ${data[0]}"
		ssh -n $applianceuser@$applianceip "udstask unmountimage -delete -nowait -image ${data[0]}"
	done
	while true; do
		jobcheck=$(ssh $applianceuser@$applianceip "reportrunningjobs -j unmount-delete -c -n")
		if [ -n "$jobcheck" ]; then
			echo "$jobcheck" | while IFS="," read -ra data; do
				echo -n "${data[1]} for ${data[3]} progress is ${data[9]}% after ${data[6]}   "
			done
			echo
			sleep 10
		else 
			break
		fi
	done
else
	echo "Found no mounts with label $grouplabel"
fi 


# bring up Oracle DB
echo "Starting Oracle DB"
ssh $applianceuser@$applianceip "udstask mountimage -appid $oraclesourceapp -host $oracletargethost -label $grouplabel -recoverytime \"$recoverytime\" -restoreoption 'provisioningoptions=<provisioning-options><databasesid>$oracledbname</databasesid><username>oracle</username><orahome>$oraclehome</orahome><rrecovery>true</rrecovery><standalone>false</standalone></provisioning-options>' -nowait"

# bring up SQL DB
echo "Starting SQL DB"
ssh $applianceuser@$applianceip "udstask mountimage -appid $sqlsourceapp -host $sqltargehost -label $grouplabel -recoverytime \"$recoverytime\"  -restoreoption 'provisioningoptions=<provisioning-options><sqlinstance>$sqlinstance</sqlinstance><dbname>$sqldbname</dbname><username>au\sqladmin</username><password type=\"encrypt\">passw0rd</password><recover>true</recover></provisioning-options>' -nowait"

while true; do
	jobcheck=$(ssh $applianceuser@$applianceip "reportrunningjobs -j mount -c -n" | egrep "$sqltargehost|$")
	if [ -n "$jobcheck" ]; then
		echo "$jobcheck" | while IFS="," read -ra data; do
			echo -n "${data[1]} for ${data[3]} is ${data[9]}% after ${data[6]}   "
		done
		echo
		sleep 10
	else 
		break
	fi
done
echo
mounts=$(ssh $applianceuser@$applianceip reportmountedimages)
echo "$mounts" | head -1
echo "$mounts" | grep $grouplabel

	
