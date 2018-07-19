# Log check script

This script will check if a snapshot is running for an App and if it is not, will run a log backup on that App.
We need SSH access from the host running this script to the Actifio Appliance.
There are some variables in the script you can change relating to log file location and timeouts.

##  Get variables

Please supply the following variables.  They define: 

* The IP Address of your Actifio Appliance supplied with -i
* The username we will log in with supplied with -u
* The database name of the application we are working with supplied with -a

So if the Actifio APpliance is 10.1.1.1 and my SSH user is ted and the Database I want to run a log on is called bigdata then I use:
```
logcheck -i 10.1.1.1 -u ted -a bigdata
```

## Test SSH

Please test that SSH works from the host to the Actifio Appliance using your userid and password:
```
ssh ted@10.1.1.1 reportrpo -a 4855
```
If you do not get a policy listing you need to get this command working.

## Run the script

You can now run the script and monitor using the log file. 
