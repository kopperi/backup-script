# backup-script

This script is a Bash backup script for nieche use-case.

##Script workflow: 

1. Choose desired backup (Incremental, Mirror, Full)
2. Mount a defined encrypted drive with cryptsetup.
3. Check whether folders exist and either create them, update them or let user decide what to do.
4. Use rsync to perform actual backup based on configured parameters and chosen rsyn flags.
5. After successful backup, let's user choose whether to leave backup drive mounted or unmount it. 

##How to configure this?

All configuration options are on top of the script, hopefully self-explanatory. To make this work you need at least two options configured:
1) config_location #Tell script where to find list of items to backup and exclude
2) drive #Tell the script what encrypted volume to mount

Other than that, you are good to go. Since this requires sudo, I suggest you read through the script to understand what it does. I trust it since I've created it, but you shouldn't. 

##What could be done better?

Probably a lot. Like said, this is practice and I aim to enhance it when I have time to do so. All comments and suggestions are welcome ofcourse. The way I have come up with this is build on previous versions, and I'm sure it shows. I'd like to have any feedback that you can give on how to make it smarter and more consciece. I tried to provide as much comments as I saw necessary, maybe it became bloated. :) Script is rather verbose, I intend to fix that. 

##What doest this require to work?
This script requires superuser privileges (sudo or root) to mount volumes, to backup . Password for encrypted volume will be asked after step 2. It cannot be used as cron job since it requires user interaction. 
Script relies on following commands: 
/bin/mkdir/
/bin/mount
/bin/umount
/sbin/cryptsetup
/usr/bin/rsync
/bin/rm
/bin/grep
/bin/lsblk

##What I intend to do when I have time:

-Add interactive rsync flag options(lightweight frontend), possibility to save configuration
-Add option to use other than encrypted volumes
-Add optional log rotation for mirror backups
-Add rotation of full backups 
- Make the script a bit more flexible, e.g. remove requirement to have configuration files
