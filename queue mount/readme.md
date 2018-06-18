This script is intended for the following scenario:
 
We need to run a mount against a host but cater for the chance a mount is already running
 
When run this script will:
1)  Check no mount job is running
2)  Run a mount

View this script as a replacement for 'udstask mountimage'

The script will have several variables which must be set at script run time:
```
-i <ip addr>   To specify the Appliance to execute commands against (this could also be a host name) 
-p <policy ID> To specify policy ID
-t <targethost> To specify the hostname of the target host for the workflow (optional)
-u <username>  To specify the user name to run commands against
```
So if you were going to run the following command with username ted on Appliance 10.1.1.1
```
ssh ted@10.1.1.1 udstask mountimage -host demo-mgmt-4 -appid 5434
```
You would instead run:
```
queuemountimage.sh -u ted -i 10.1.1.1  -m '-host demo-mgmt-4 -appid 5434'
```
