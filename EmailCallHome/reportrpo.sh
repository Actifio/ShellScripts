#!/bin/bash
# Actifio Copy Data Storage SARGPACK
# Copyright (c) 2018 Actifio Inc. All Rights Reserved
# This script collects health checks
# Version 1.0 Initial Release

# Now check for inputs app name length (l) delim (c) help (h)
while getopts :f opt
do
        case "$opt"
        in
                f) fileonly=y;;
        esac
done

# we use this for file names, don't touch this:
currentday=$(/bin/date +"%Y-%m-%d")

################################################################################################
################   THE SECTION BELOW NEEDS TO BE CUSTOMIZED.   LEAVING AS DEFAULT WILL NOT WORK!
################################################################################################
#user name on each appliance.   You define this on each Actifio Appliance and use CLI to access
username=admin

# key location on the RM server.
# It is the private key that matches the public key assigned to every user on every Actifio Appliance
userkey=/home/actifio/.ssh/id_rsa

# location where we keep temporary files
reportsubject="reportrpoUSA_"
emailsubject="USA Reportrpo with mixed dates"
# directory where the report will be placed
workingdirectory="/home/actifio"

# destination for report  to be sent to
# You can place multiple email addresses in double quotes with a single comma between each address, example shown:
blindrecipient="anthonyv@acme.com"
recipient="jojo@acme.com"
emailserver=10.10.10.10
emailuser=ActifioReports@acme.com

# list of clusters
clusterlist="Actifio1}10.10.10.2
Actifio1}10.10.10.3"
################################################################################################
################   THE SECTION ABOVE NEEDS TO BE CUSTOMIZED.   LEAVING AS DEFAULT WILL NOT WORK!
################################################################################################

# fetch the current date time
currentdate=$(/bin/date +"%Y-%m-%d %H:%M:%S %Z")
reportname="$workingdirectory/$reportsubject$currentday.txt"

# check the list
if [ -z "$clusterlist" ]; then
	echo "There are no clusters listed to check"  > $reportname
	exit
fi

# start the report output
echo "Report from Actifio Report Manager created on ${currentdate}" > $reportname
echo "##################################################################################################################################################" >> $reportname
# work the list
echo "$clusterlist" | while IFS="}" read -ra cluster; do
	reporthealthout=$(ssh -n -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $userkey $username@${cluster[1]} reportrpo -i -w 2>/dev/null)
	if [ -z "$reporthealthout" ]; then
		 echo "Failed to SSH to ${cluster[0]} using IP address ${cluster[1]} with username $username" >> $reportname
	else
                 echo "Appliance: ${cluster[0]}" >> $reportname
                 echo >> $reportname
		 echo "$reporthealthout" >> $reportname
	fi
        echo "----------------------------------" >> $reportname
        echo "##################################################################################################################################################" >> $reportname
done

#  Execute file only,  print and exit without mailing
if [ "$fileonly" == "y" ]; then
	cat $reportname
	exit 0
fi


# use sendmail
(echo "To: $recipient"
echo "Bcc: $blindrecipient"
echo "Subject: $emailsubject"
echo 'MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="=_myboundary"

--=_myboundary
Content-Type: text/html; charset=us-ascii
Content-Transfer-Encoding: quoted-printable

<html>
<body>
<pre style="font: monospace">'
cat $reportname
echo '</pre>
</body>
</html>

--=_myboundary--') | /usr/sbin/sendmail -F "" -f $emailuser -t


# clean old report files that are older than one week
find $workingdirectory -name "$reportsubject*.txt" -mtime +8 -exec rm -f {} \;
