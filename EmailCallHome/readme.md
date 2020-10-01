# HTML-Call-Home-Email-Script
User requires regular emails containing SSH command output from multiple sources. For instance, output of reporthealth from multiple Actifio Appliances. 

On a Linux server do the following:
 
1) Create an SSH key pair (public/private key files).  This key pair will be used by the Linux server script to authenticate to the Actifio Appliances.
2) On each Actifio Appliance create a user and enable CLI access using the public SSH key generated in Step 1.
3) Validate that the SSH key pair can be used to login to each Actifio Appliance.  i.e. from Linux server, if keyfile is /root/keyfile, username is monitor and Appliance IP is 192.168.1.1, validate you can SSH like this:

```
ssh -i /root/keyfile monitor@192.168.1.1
```
4) Configure the attached script healthcheck.sh with username, keyfile name, destination name and other variables as detailed below.
5) Place script into relevant CRON folder.  Recommend /etc/cron.daily.  Make sure the script is executable:    

```
[root@localhost ~]# chmod 700 healthcheck.sh
[root@localhost ~]# ls -l /etc/cron.daily
-rwx------ 1 root root 3646 Oct  4 18:18 healthcheck.sh
-rwx------ 1 root root  180 Jul  9  2003 logrotate
```

6) Test script by running it manually from the /etc/cron.daily location.

```
[root@localhost cron.daily]# pwd
/etc/cron.daily
[root@localhost cron.daily]# ls
healthcheck.sh  logrotate
[root@localhost cron.daily]# ./healthcheck.sh
```
 
Steps 1-3 are already documented in the Actifio CLI guide so there is no need to document them here.
Step 4 is the most work as you need to customise the script.
Steps 5 and 6 are basic Unix steps
 
There are several variables:
 
-- user name on each appliance.   You define this on each Actifio Appliance and use CLI to access
```
username=monitor
``` 
-- key location on the Linux server.
--  It is the private key that matches the public key assigned to every user on every Actifio Appliance
```
userkey=/root/.ssh/id_rsa
``` 
-- destination for report  to be sent to
-- You can place multiple email addresses in double quotes with a single comma between each address, example shown:
```
recipient="big.bang@actifio.com,super.dude@actifio.com"
``` 
 
--This is the 'from' email address used in this email and the email server that will forward our mail
```
big.bang@actifio.com
emailuser=big.bang@actifio.com
emailserver=192.43.242.5
```
 
-- Put all your Appliance IDs in a file so they can be learned.   You could also just list them
-- Format would be a list of IPs  in column format

```
cluster1,172.24.1.1
cluster2,172.24.2.1
```
 
 
## Trouble shooting - Postfix won't start with 127.0.0.2 message
 
If you get this:
 
```
[root@AUHDC1-COPARM01 ~]# postfix reload
postfix: fatal: parameter inet_interfaces: no local interface found for 127.0.0.2
``` 
Do this:  
```
vi /etc/postfix/main.cf
```

Change this:

``` 
inet_interfaces = localhost
``` 
To this:
``` 
inet_interfaces = all
``` 
Then start postfix (which will not have been running up till this point):
 
```
[root@AUHDC1-COPARM01 ~]# postfix start
postfix/postfix-script: starting the Postfix mail system
 ```
## Trouble shooting - ipV6 errors
 
If you get these messages, they can be ignored:
 ```
sendmail: warning: inet_protocols: IPv6 support is disabled: Address family not supported by protocol
sendmail: warning: inet_protocols: configuring for IPv4 support only
postdrop: warning: inet_protocols: IPv6 support is disabled: Address family not supported by protocol
postdrop: warning: inet_protocols: configuring for IPv4 support only
 ```
You may also get this:
```
fatal: parameter inet_interfaces: no local interface found for ::1
```
To resolve either, go to /etc/postfix/main.cf and change from:
 ```
inet_protocols = all
```
to:
```
inet_protocols = ipv4
```

Then for RHEL/Centos 6 and below:
```
postfix reload
```
Then for RHEL/Centos 7 and below:
```
 systemctl status postfix.service
 ```
## Trouble shooting - no mail arrives
 
If no mail arrives, check   /var/log/maillog
 
If you see  something like this:
 ```
Nov  3 13:38:37 localhost postfix/smtp[24299]: connect to aspmx.l.google.com[74.125.203.26]:25: Connection timed out
 ```
Then your Linux server is trying to resolve a mail record from DNS.
``` 
cat /etc/postfix/main.cf | grep relay
 ```
you should see lots of remmed out relayhost
now vi the file
```
vi /etc/postfix/main.cf
``` 
Then set one to your mail host, for instance:
```
relayhost = smtp.acme.co
 ```
Then for RHEL/Centos 6 and below:
```
postfix reload
```
Then for RHEL/Centos 7 and below:
```
 systemctl status postfix.service
 ```
