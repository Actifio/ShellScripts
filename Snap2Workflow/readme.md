# Purpose
 
User wants to create a snapshot and then immediately mount that snapshot using a workflow.
 
## Install Tasks:
 
1)  Copy attached script to Linux server (not to Actifio Appliance but to client side Linux server)
2)  Make script executable:
``` 
chmod 755 backupworkflow.sh
``` 
3)  Ensure Linux user on that Linux Server has SSH access to Actifio Appliance with default keys.   Confirm with (where username is exchanged with a valid CLI enabled user on your Actifo Appliance and ipaddress is exchanged with a valid Actifo Appliance IP):    
``` 
ssh username@ipaddress udsinfo lscluster 
``` 
 
## Setup tasks

You will clearly need to know Appliance IP and username
 
1)  Learn workflow ID using Actifio Desktop or CLI command like reportworkflows
2)  Optionally learn the name of the target host
3)  Learn the policy ID of the snapshot that needs to be run with reportpolicies

 
## Run tasks:
 
For workflow ID 91011 to run a snapshot using policy ID 5678 mounted to host host1, use this syntax:
``` 
backupworkflow -i 10.10.10.10 -p 5678 -u admin -w 91011 -t host1
 ```


 

