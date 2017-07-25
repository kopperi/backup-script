#!/bin/bash
set -e 

########################################################################
########################## CONFIGURATION ###############################

#### PATH variables ####
mkdir=/bin/mkdir
mount=/bin/mount
umount=/bin/umount
cryptsetup=/sbin/cryptsetup
rsync=/usr/bin/rsync
rm=/bin/rm
grep=/bin/grep
lsblk=/bin/lsblk

#Home folder if needed
home=/home/user

#### Configuration file locations ####
#Script root directory (adjust accordingly)
config_location=$home/scripts
#List of files and directories to be included
include=$config_location/backup_list
#List of files and directories to be excluded
exclude=$config_location/backup_exclude

#### Backup media configuration ####
#Drive label of backup media (e.g. sda, sdb... NOT sda1 or /dev/sda)
drive=sdX
#Label to be used when mounting with cryptsetup, e.g. backup
mount_label=backup
#Where to mount the backup media
mount_point=/mnt/backup

#### Backup options
#Backup root directory, where folders created by script should be stored.
#Add folder structure after mount point if preferred
backup_root_dir=$mount_point

#Rsync options and flags
#Refer to 'man rsync' for additional information about flags
#Default flags are: (a)rchive, (v)erbose
#Archive includes following options: rlptGot
#However, for some reason 'r' doesn't seem to work unless separately specified
#In addition to flags defined here, script includes --files-from, --exclude-from and 
#--log-file (see above).
flags=-arv


#### Miscallaneous options ####
#Timeout in seconds to automatically unmount after backup is completed. 
timeout=5



########################################################################
####################### BEGINNING OF SCRIPT ############################


#Check whether script is run as root
if [[ "$EUID" -ne 0  ]]; then
	echo "This script requires root privileges. Please use 'su' or 'sudo' and" \
	"try again."
	exit 1
fi

#Function to mount appropriate drive for backup
function enter_volume { 
	echo -n "Checking device availability.   "
	#Check if already mounted. If yes, inform and continue.
	if $mount | $grep $mount_label | $grep $mount_point > /dev/null; then
		echo -n "Already mounted.   "; echo "[OK]"; 
		return 0
	#Check if defined drive exists in system. If yes, open volume and mount. 
	#Continue on success.
	elif $lsblk | $grep $drive > /dev/null; then 
		echo "[OK]";  
		#Check, if the drive in question is and encrypted volume before
		#opening it.
		if $lsblk --fs | grep $drive | grep 'crypto_LUKS' > /dev/null; then
			#Check whether the volume is already open. 
			if $lsblk --fs | grep $mount_label > /dev/null; then
				echo -n "Volume already open, mounting.   "
				$mount /dev/mapper/$mount_label $mount_point; 
				echo "[OK]";
				return 0
			#If not open yet, open and mount.
			else
				echo "Encrypted volume found, opening.   "
				$cryptsetup luksOpen /dev/$drive $mount_label
				echo -n "Mounting.   "
				$mount /dev/mapper/$mount_label $mount_point
				echo "[OK]";
				return 0
			fi
		#If there is no crypto_LUKS label with appropriate drive label,
		#volume is either unaencrypted or not supported. Attempt to mount.	
		else 
			echo -n "Volume is not encrypted, mounting.   "
		 	$mount /dev/$drive $mount_point
			echo "[OK]"
		        return 0
		fi
	#If target drive does not exist, inform and exit with error.
	else 
		echo "Defined drive /dev/$drive cannot be found in system. Please check" \
		"the configuration. Exiting script."	
		exit 1;
	fi
}

#Funtion to provide user and option to keep volume mounted after script is completed 
#(e.g. to inspect folders with file manager). Includes timeout, after which volume is
#automatically unmounted without user action. Timeout can be specified in the beginning
#of the script under Miscallaneous options.
function exit_dialogue {
       	read -t $timeout -p "Do you want to unmount volume? (Y/n)" choice || unmount_volume;
	if [[ $choice == "n"  ]]; then
		echo "Leaving /dev/$drive mounted. Exiting script."
		exit 0
	else  
		unmount_volume;
	fi
	
}

#Function to unmount encrypted volume and close it.
function unmount_volume {
	echo -n $'\n'"Unmounting $drive from $mount_point.   "
	$umount $mount_point; echo "[OK]"
	if $lsblk --fs | grep $drive | grep 'crypto_LUKS' > /dev/null; then 
		echo -n "Closing encrypted volume.   "
		$cryptsetup luksClose $mount_label; echo "[OK]"
	fi	
	echo "Backup successful, exiting."
	exit 0
}

#Mirror backup. This function makes and exact copy of current files. All files which do 
#not match the current selection of files in directories defined in --files-from will be 
#deleted. This backup uses separate folder, labeled 'backup_mirror'
function do_mirror {
	enter_volume;

	#Go to defined backup root directory and check whether there is already a folder.
	cd $backup_root_dir; local backup_dir_mirr=$backup_root_dir/backup_mirror

	#Create the folder, if not found.
	if [[ ! -d $backup_dir_mirr ]]; then
		echo -n  "Directory not present, creating..."
	        $mkdir $backup_dir_mirr && cd;
       	fi 	       
	
	#Define log file for this backup
	local log_file=$backup_dir_mirr/$(date +'backup_log_mirror_%d%m%y')
	#Perform backup. "True" in the end will allow script to continue even when rsync 
	#gives errors (such as inaccessible files).
	echo "Backing up."
	$rsync $flags --exclude-from=$exclude --files-from=$include / $backup_dir_mirr \
	--log-file=$log_file --delete || true;
	cd && echo "Transfer completed successfully."
	exit_dialogue;	#After backup proceed to exit dialogue.
}

#Incremental backup. This function uses the same backup folder every time, adding
#to the files which are already in the folder. Files with same names are updated to
#newer versions and files with no matches in current system are retained as well.
#Separate folder is used, labeled as 'backup_incremental'
function do_incremental {
	enter_volume;

	#Go to defined backup root directory and check whether there is already a folder.
	cd $backup_root_dir; local backup_dir_incr=$backup_root_dir/backup_incremental

	#Create the folder, if not found.
	if [[ ! -d $backup_dir_incr ]]; then
		echo "Directory not present, creating..."
	        $mkdir $backup_dir_incr && cd;
       	fi 	       
	
	#Define log file for this backup
	local log_file=$backup_dir_incr/$(date +'backup_log_mirror_%d%m%y')

	#Perform backup. "True" in the end will allow script to continue even when rsync
       	#returns errors (such aseinaccessible files).
	echo "Backing up."
	$rsync $flags --exclude-from=$exclude --files-from=$include / $backup_dir_incr \
	--log-file=$log_file || true;
	cd && echo "Transfer completed successfully."
	exit_dialogue;	#After backup proceed to exit dialogue.
}
#Full backup. This function creates new folder to defined backup directory with date label. 
#If folder already exists (i.e. manually created or full backup has already been done today), 
#script asks whether to:
#1. Update the existing backup with any changes that may have been introduced after last update (u)
#2. Quit script (nothing will be changed)
#3. Remove old backup and recreate full backup. CAREFUL
function do_full {
	enter_volume;	
	
	#Go to defined backup root directory and check whether there is already a folder
	cd $backup_root_dir; local backup_dir_full=$backup_root_dir/$(date +'backup_full_%d%m%y')
	if [[ ! -d $backup_dir_full ]]; then
		$mkdir $backup_dir_full && cd 
	#If defined folder already exists, user is given options.	
	else
		echo "Defined folder already exist. Want to (u)pdate backup (same than" \ 
		"incremental), (q)uit or (re)move and recreate (u/Q/re)"
		read choice 
		#When update is selected, perform mirror backup on existing full backup.
		#I.e. all changes to files will be updated.
		if [[ $choice == "u" ]]; then
			echo Update chosen.
		        cd;

		#If user chooses the remove option, additional confirmation required to proceed. 
		elif [[ $choice == "re"  ]]; then
			echo "Absolutely sure? Type 'remove' in capital letters to proceed."
			read confirmation 
				#If confirmation is successful, remove folder
				if [[ $confirmation == "REMOVE" ]]; then
					echo "Removing old backup $backup_dir_full"; 
					$rm -rf $backup_dir_full			
					echo "Recreating folder"; $mkdir $backup_dir_full && cd;

				else
					echo "Required input not provided, aborting."
					exit_dialogue;
				fi 

		#Abort with any other input, including 'q'. 
	        else
		       echo "Aborting by user decision."
		       cd && exit_dialogue;
	        fi
	fi

	#Define log file for this backup
	local log_file=$backup_dir_full/$(date +'backup_log_full_%d%m%y')

	#Perform backup. "True" in the end will allow script to continue even when rsync
       	#returns errors (such as inaccessible files).
	echo "Backing up."
	$rsync $flags --exclude-from=$exclude --files-from=$include / $backup_dir_full \
	--log-file=$log_file || true;
	cd && echo "Transfer completed successfully.";
	exit_dialogue;	
}

#Initial menu for backup script. 
echo "Backup script staring..."
PS3="Choose preferred option: "
options=("Mirror" "Full" "Incremental" "Quit")
select opt in "${options[@]}"
do
	case $opt in
		"Mirror")
			do_mirror; break
			;;	
		"Full")
			do_full; break
			;;
		"Incremental")
			do_incremental; break
			;;
		"Quit")
			echo Quitting. && exit 0
			;;
		*)echo Invalid option.
	esac
done
