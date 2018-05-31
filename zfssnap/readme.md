####   0)  Install Actifio Connector on Solaris host  
####   1)  Create ZFS Snapshot on Solaris host using your own snapshotname like we set below:    zfs snapshot $snapshotname
####   2)  Create ZFS Clone on Solaris host using your own clonename like we set below:     zfs clone $snapshotname $clonename
####   3)  On Actifio, Do App Discovery on Solaris host, find the ZFS Clone as File system and learn APPID.  
####   4)  Protect the discovered APP but disable protection.  
####   Now create two files on host side,  this file with name:    actzfssnap_conf.10792   where 10792 is the APPID
####   Then rename zfsnapshot.sh to zfssnapshot.10792 and make it executable
####   Place both files in /act/scripts
####   Also setup SSH so that the script can SSH to Actfio and run udstask and udsinfo commands.
