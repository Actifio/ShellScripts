# Log check script

This script will check if a snapshot is running for an App and if it is not, will run a log backup on that App.
We need SSH access from the host running this script to the Actifio Appliance.

##  Configure script

Please update the following variables in the script.  They define: 
* Where we put a log file  
* The IP Address of your Actifio Appliance
* The username we will log in with
* The App ID of the application we are working with.

They are:
```
logfile=~/logcheck.txt
actifoip=10.11.1.1
username=admin
appid=4855
```

## Test SSH

Please test that SSH works from the host to the Actifio Appliance using your userid and password:
```
ssh admin@10.11.1.1 reportrpo -a 4855
```
If you do not get a policy listing you need to get this command working.

## Run the script

You can now run the script and monitor using the log file. 
