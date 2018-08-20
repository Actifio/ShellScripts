#!/bin/bash
# Actifio Copy Data Storage SARGPACK
# Copyright (c) 2018 Actifio Inc. All Rights Reserved
# This script collects health checks
# Version 1.0 Initial Release

# Now check for inputs 
while getopts :f opt
do
        case "$opt"
        in
                f) fileonly=y;;
        esac
done

################################################################################################
################   THE SECTION BELOW NEEDS TO BE CUSTOMIZED.   LEAVING AS DEFAULT WILL NOT WORK!
################################################################################################
#user name on each appliance.   You define this on each Actifio Appliance and use CLI to access
username=admin

# It is the private key that matches the public key assigned to every user on every Actifio Appliance
userkey=/root/.ssh/id_rsa

# destination for report  to be sent to
# You can place multiple email addresses in double quotes with a single comma between each address, example shown:
recipient="cow@over.the.moon,tom.tom@pipers.son"

#  UNHASH LINES BELOW AND CUSTOMIZE WITH YOUR EMAIL USER NAME AND SERVER NAME
# This is the 'from' email address used in this email and the email server that will forward our mail
emailuser=cow@over.the.moon
emailserver=192.43.242.5

# Put all your Appliance Names and IDs in a list 
# example list:

clusterlist="cluster1,172.24.1.1
cluster2,172.24.2.1"

################################################################################################
################   THE SECTION ABOVE NEEDS TO BE CUSTOMIZED.   LEAVING AS DEFAULT WILL NOT WORK!
################################################################################################

# fetch the current date time
currentday=$(/bin/date +"%Y-%m-%d")
currentdate=$(/bin/date +"%Y-%m-%d %H:%M:%S %Z")
reportname="reporthealth_$currentday.txt"

# check the list
if [ -z "$clusterlist" ]; then
	echo "There are no defined clusters"  > /root/$reportname
	exit
fi

# start the report output
echo "Actifo Report created on ${currentdate}" > /root/$reportname
echo "--------------------------------------------------------------------------------" >> /root/$reportname

# work the list
echo "$clusterlist" | { while IFS="," read -ra cluster; do
	reporthealthout=$(ssh -n -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $userkey $username@${cluster[1]} "reporthealth -flncm" 2>/dev/null)
	[[ -z "$reporthealthout" ]] && echo "Failed to SSH to ${cluster[0]} using IP address ${cluster[1]} with username $username" >> /root/$reportname
	[[ $(echo "$reporthealthout" | wc -l) -eq 2 ]] && let cleancount+=1 && cleanlist=$(echo "$reporthealthout" | tail -1 | awk -F"," '{ print $1 }' | awk -F":" '{ print $2 }'; echo "$cleanlist") && continue
	colput=$(echo "$reporthealthout" | head -2| tail -1;echo >> /root/$reportname;echo "$reporthealthout" | head -1;echo "$reporthealthout" | tail -n +3;echo "-----------------------------,-----------------------------,---------------"; echo "$colput")
done
echo "$colput" | column -t -s, >> /root/$reportname
# Create the final report:
[[ $clustercount -gt $cleancount ]] && echo "Clean Appliances were:"  >> /root/$reportname
[[ $clustercount -eq $cleancount ]] && echo "There were no clean Appliances"  >> /root/$reportname
echo "$cleanlist" | sort >> /root/$reportname

[[ $clustercount -ne $cleancount ]] &&  sed -i "1i$clustercount Appliances were checked and $cleancount Clean Appliances were found.  Appliances with messages are displayed below:" /root/$reportname
[[ $clustercount -eq $cleancount ]] &&  sed -i "1i$clustercount Appliances were checked and $cleancount Clean Appliances were found." /root/$reportname
sed -i "1iReport from Actifio Report Manager created on ${currentdate}" /root/$reportname
}
# the close bracket above is part of a closed loop, don't remove it

# clean blank lines
sed -i '/^$/d' /root/$reportname

# clean old report files that are older than one week
find /root -name "reporthealth_*.txt" -mtime +8 -exec rm -f {} \;

#  Execute file only,  print and exit without mailing
if [ "$fileonly" == "y" ]; then
	cat /root/$reportname
	exit 0
fi


# use sendmail
(echo "To: $recipient"
echo 'Subject: ReportHealth from Actifio Report Mailer
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="=_myboundary"

--=_myboundary
Content-Type: text/html; charset=us-ascii
Content-Transfer-Encoding: quoted-printable

<html>
<body>
<pre style="font: monospace">'
cat /root/$reportname
echo '</pre>
</body>
</html>

--=_myboundary--') | /usr/sbin/sendmail -F "" -f $emailuser "$recipient"

