# ZFS Snap script

This script will allow you to create a ZFS snapshot and back this snapshot up.
This allows you to protect applications where no other protection method is suitable.
It is most likely going to be used on a Solaris host

##  Install Actifio Connector on host  

We need the Actifo Connector installed and running on the host.

## Create host side ZFS Snapshot and Clone so they can be discoverd.

Identify the ZFS volume you are going to protect.   You need its name, which might look like rpool/database
Create ZFS Snapshot on host using your own snapshotname like we set below:    
```
zfs snapshot rpool/database@snapshot
```
So the only part of the name you can choose is the word:  snapshot

Create ZFS Clone on Solaris host using your own clonename like we set below.   The only part you can choose is:  databaseclone   
```
zfs clone rpool/database@snapshot rpool/databaseclone
```

## On Actifio, Do App Discovery 

Do App Discovery on the host, find the ZFS Clone as a File system and learn its APPID.  

## Protect the discovered APP but disable protection.  

We need to apply a policy template to the application that has a snapshot policy.   
We are going to schedule these snapshots from the host side, so disable protection.

## Now create two files on host side    

We need the snapshot shell script and configuration file.   They both need to have the appid as part of the name. If the Appid is 10792 then we woud have two files like ths
```
actzfssnap_conf.10792   
zfsnapshot.10792 
```
Make zfsnapshot.10792 executable
Place both files in /act/scripts.   

##   SSH Setup

Also setup SSH on the host side so that the script can SSH to Actfio and run udstask and udsinfo commands.
This means creating a Public/private key pair on the host and then creating a user on Actifio side that has admin rights and CLI access.  Give this user CLI access.
