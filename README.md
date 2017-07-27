# backup-script

## What is this and why does this exist.

This script is a Bash backup script for nieche use-case. Essentially, script mounts volume, performs rsync backup based on configured parameters and couple of choises given in script. This has been created, first and foremost, for practice. This started as a mere attempt to automate mounting, backing up and unmounting encrypted volumes and now it's something more (not much but still). 

Script provides incremental, mirror and full backups by default and has some pre-existing automation on managing folder-structure. See more details below.

## Who is this for?

Me, and anyone else who for reason or another can't or don't want to rely on cron jobs to do their backup, while using normal or encrypted backup media. Anyone who wants to use this as base or part of something else. 

## Script workflow: 

1. Choose desired backup (Incremental, Mirror, Full) or Quit
2. Identify whether target volume is encrypted or non-encrypted.
2. Mount a defined drive with cryptsetup or just mount.
3. Check whether folders exist and either create them, based on chosen backup type  update them or let user decide what to do.
4. Use rsync to perform actual backup based on configured parameters and rsync flags in backup.config.
5. After successful backup, let's user choose whether to leave backup drive mounted or unmount it. 

## How to configure this?

All configuration parameters are located in file backup.config. Following sections should be checked before attempting to use the script: 
- FOLDERS AND FILES
- BACKUP MEDIA 
Instructions are included in the file for each parameter. Other than that, you should be good to go. You can fully control rsync flags in configuration file. 

Since this requires sudo, I suggest you read through the script to understand what it does. I trust it since I've created it, but you shouldn't. 

## What could be done better?

Probably a lot. Like said, this is practice and I aim to enhance it when I have time to do so. All comments, suggestions and contributions are welcome ofcourse. The way I have come up with this is build on previous versions, and I'm sure it shows. I'd like to have any feedback that you can give on how to make it smarter and more concise. I tried to provide as much comments as I saw necessary, maybe it became bloated. :)


## What doest this require to work?
This script requires superuser privileges (sudo or root) to mount volumes, to backup . Password for encrypted volume will be asked after step 2. It cannot be used as cron job since it requires user interaction. 
Script relies on rsync and cryptsetup. All other tools are part of standard OS installation (GNU\Linux) 

This script has been tested successfully with Bash version 4.4.12.


## What I intend to do when I have time:

- Log rotation for mirror and incremental backups 
- Rotation of full backups 
- Verify that there is enough space in target media before attempting to backup. 
- Support for easier rsync to remote location (can be done now by adding needed parameters to rsync flags in backup.config) 
- FIX: Row 71: In case backup volume is already mounted, script does not (yet) verify whether mount point and drive label actually belong to the backup media (drive). Risk: Drive runs out of space. Current workaround: Delete created backup folder, unmount volume and restart script. 
- IDEA: Interactive rsync flag options(lightweight frontend), possibility to save configuration
