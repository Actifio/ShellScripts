# Purpose
 
User wants to mount the latest image from a specific jobclass to a specific host in a workflow like fashion using a Linux script.
 
## Install Tasks:
 
1)  Copy attached script to Linux server (not to Actifio Appliance but to client side Linux server)
2)  Make script executable:
``` 
chmod 755 mountimage.sh
``` 
3)  Ensure Linux user on that Linux Server has SSH access to Actifio Appliance with default keys.   Confirm with (where username is exchanged with a valid CLI enabled user on your Actifo Appliance and ipaddress is exchanged with a valid Actifo Appliance IP):    
``` 
ssh username@ipaddress udsinfo lscluster 
``` 
 
## Setup tasks
 
1)  Learn application ID using Actifio Desktop or CLI command like reportapps
2)  Learn host name or host ID of host to mount to using Actifio Desktop or CLI command like reportconnectors
3)  Choose a label to use (unique for that host)
4)  Choose a jobclass (dedup, dedupasync, directdedup, liveclone, remote-dedup, snapshot)
 
## Run tasks:
 
For application ID 17169 to mount most recent dedup to host hq-sql with a label of pegasus use this syntax:
``` 
mountimage.sh -u admin -i 172.24.2.180 -a17169 -t hq-sql -l pegasus -j dedup
 ```
The label needs to be unique for a mount to that host but can be used for multiple hosts.
Using this label ensures we unmount the correct mount before mounting the next one.
 
Run example:
```
$ ./mountimage.sh -i 172.24.2.180 -u av -a 17172 -t HQ-SQL -l pegasus -j dedup
Checking for mounts to host HQ-SQL with a label of pegasus
Unmounting and deleting the existing mount ID 1322213 with label pegasus
Job_1322398 progress:       16%
Job_1322398 progress:       20%
Job_1322398 progress:       20%
Job_1322398 progress:       20%
Job_1322398 progress:       44%
Job_1322398 progress:       44%
Job_1322398 progress:       44%
Job_1322398 progress:       44%
Job_1322398 progress:       44%
Job_1322398 progress:       44%
Job_1322398 progress:       44%
Job_1322398 progress:       44%
Job_1322398 progress:       85%
Job_1322398 progress:       99%
Unmount Job Results:
Status:                     succeeded
Duration:                   00:01:25
 
Mounting dedup image sa-hq_1190224 to host HQ-SQL
Job_1322440 progress:       30%
Job_1322440 progress:       30%
Job_1322440 progress:       30%
Job_1322440 progress:       30%
Job_1322440 progress:       30%
Job_1322440 progress:       31%
Job_1322440 progress:       31%
Job_1322440 progress:       32%
Job_1322440 progress:       32%
Job_1322440 progress:       34%
Job_1322440 progress:       34%
Job_1322440 progress:       34%
Job_1322440 progress:       34%
Job_1322440 progress:       34%
Job_1322440 progress:       39%
Job_1322440 progress:       43%
Job_1322440 progress:       47%
Job_1322440 progress:       62%
Job_1322440 progress:       65%
Job_1322440 progress:       74%
Job_1322440 progress:       74%
Job_1322440 progress:       74%
Job_1322440 progress:       74%
Job_1322440 progress:       74%
Job_1322440 progress:       74%
Job_1322440 progress:       74%
Job_1322440 progress:       74%
Job_1322440 progress:       99%
Job_1322440 progress:       99%
Mount Job Results:
Status:                     succeeded
Duration:                   00:03:06
```

