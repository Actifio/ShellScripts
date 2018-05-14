#!/bin/bash
# Actifio Copy Data Storage SARGPACK
# Copyright (c) 2018 Actifio Inc. All Rights Reserved
# This script collects health checks
# Version 1.0 Initial Release

################################################################################################
################   THE SECTION BELOW NEEDS TO BE CUSTOMIZED.   LEAVING AS DEFAULT WILL NOT WORK!
################################################################################################
#user name on each appliance.   You define this on each Actifio Appliance and use CLI to access
username=admin

# key location on the RM server.
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
echo "$clusterlist" | while IFS="," read -ra cluster; do
	reporthealthout=$(ssh -n -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $userkey $username@${cluster[1]} reporthealth 2>/dev/null)
	if [ $? -ne 0 ]; then
		 echo "Failed to SSH to ${cluster[0]} using IP address ${cluster[1]} with username $username" >> /root/$reportname
	else
		 echo "$reporthealthout" >> /root/$reportname
	fi
	echo "--------------------------------------------------------------------------------" >> /root/$reportname
done

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


# clean old report files that are older than one week
find /root -name "reporthealth_*.txt" -mtime +8 -exec rm -f {} \;
