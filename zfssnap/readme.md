# ZFS Snap script

This script will allow you to create a ZFS snapshot and back this snapshot up.
This allows you to protect applications where no other protection method is suitable.
It is most likely going to be used on a Solaris host

##  Install Actifio Connector on host  

We need the Actifo Connector installed and running on the host.

## Create host side ZFS Snapshot and Clone so they can be discoverd.

Create ZFS Snapshot on host using your own snapshotname like we set below:    zfs snapshot $snapshotname
Create ZFS Clone on Solaris host using your own clonename like we set below:     zfs clone $snapshotname $clonename

## On Actifio, Do App Discovery 

Do App Discovery on the host, find the ZFS Clone as File system and learn APPID.  

## Protect the discovered APP but disable protection.  

## Now create  files on host side    

actzfssnap_conf.10792   where 10792 is the APPID
zfsnapshot.10792 

Make zfsnapshot.10792 executable
Place both files in /act/scripts

##   SSH Setup

Also setup SSH so that the script can SSH to Actfio and run udstask and udsinfo commands.
