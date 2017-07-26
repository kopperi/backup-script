#!/bin/bash
set -e 

#Source configuration and other files
. backup.config
. backup.functions

#########################################################################
####################### BEGINNING OF SCRIPT #############################
#########################################################################
#									#
# 	This is the main script which provides:				#
#	1. Light interface to choose backup method			#
#	2. Automated mounting of normal and encrypted media (LUKS)	#
#	3. Logging for chosen backup type.				#
#	4. Automated media unmount during exit (can be intercepted)	#
#									#
# 	All configuration should be included in file 'backup.config'. 	#
#	All functions are used by the script are included in 		#
#	'backup.functions'.						#
# 									#
# #######################################################################




#Check whether script is run as root
if [[ "$EUID" -ne 0  ]]; then
	echo "This script requires root privileges. Please use 'su' or 'sudo' and" \
	"try again."
	exit 1
fi

#Verify that needed files exist
if [[ ! -f backup_list  ]] || [[ ! -f backup_exclude   ]]; then
	echo "There is no file lists available. Verify that include and exclude" \
	"parameters in backup.configure points to correct files. Try again."
	exit 1
fi

#Initial menu for backup script. 
echo "Backup script staring..."
PS3="Choose preferred option: "
options=("Mirror" "Full" "Incremental" "Quit")
select opt in "${options[@]}"
do
	case $opt in
		"Mirror")
			backup_mirror; break
			;;	
		"Full")
			backup_full; break
			;;
		"Incremental")
			backup_incremental; break
			;;
		"Quit")
			echo Quitting. && exit 0
			;;
		*)echo Invalid option.
	esac
done


#Function to mount appropriate drive for backup
function enter_volume() { 
	echo -n "Checking device availability."'/t'
	#Check if already mounted. If yes, inform and continue.
	if $mount | $grep $mount_label | $grep $mount_point > /dev/null; then
		echo -n "Already mounted."'/t'; echo "[OK]"; 
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
				echo -n "Volume already open, mounting."'/t'
				$mount /dev/mapper/$mount_label $mount_point; 
				echo "[OK]";
				return 0
			#If not open yet, open and mount.
			else
				echo "Encrypted volume found, opening."'/t'
				$cryptsetup luksOpen /dev/$drive $mount_label
				echo -n "Mounting.   "
				$mount /dev/mapper/$mount_label $mount_point
				echo "[OK]";
				return 0
			fi
		#If there is no crypto_LUKS label with appropriate drive label,
		#volume is either unaencrypted or not supported. Attempt to mount.	
		else 
			echo -n "Volume is not encrypted, mounting."'/t' 
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
function exit_dialogue() {
       	read -t $timeout -p "Do you want to unmount volume? (Y/n)" choice || unmount_volume;
	if [[ $choice == "n"  ]]; then
		echo "Leaving /dev/$drive mounted. Exiting script."
		exit 0
	else  
		unmount_volume;
	fi
	
}

#Function to unmount encrypted volume and close it.
function unmount_volume() {
	echo -n $'\n'"Unmounting $drive from $mount_point."'/t'  
	$umount $mount_point; echo "[OK]"
	if $lsblk --fs | grep $drive | grep 'crypto_LUKS' > /dev/null; then 
		echo -n "Closing encrypted volume."'/t'
		$cryptsetup luksClose $mount_label; echo "[OK]"
	fi	
	echo "Backup successful, exiting."
	exit 0
}

#Mirror backup. This function makes and exact copy of current files. All files which do 
#not match the current selection of files in directories defined in --files-from will be 
#deleted. This backup uses separate folder, labeled 'backup_mirror'
function backup_mirror() {
	enter_volume;
	#Check whether there is already a folder. Create the folder, if not found.
	if [[ ! -d $backup_dir_mirr ]]; then
		echo -n  "Creating directory.   "
	        $mkdir $backup_dir_mirr && cd; echo "[OK]"
       	fi 	       
	
	#Define log file for this backup
	local log_file=$log_path_mirr/$log_syntax_mirr
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

function backup_incremental() {
	enter_volume;
	#Check whether there is already a folder. Create the folder, if not found.
	if [[ ! -d $backup_dir_incr ]]; then
		echo -n "Creating directory."'/t'
	        $mkdir $backup_dir_incr && cd; echo "[OK]"
       	fi 	       
	
	#Define log file for this backup
	local log_file=$log_path_incr/$log_syntax_incr

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

function backup_full() {
	enter_volume;	
	#Check whether there is already a folder. Create the folder, if not found.
	if [[ ! -d $backup_dir_full ]]; then
		echo "Creating directory."'/t'
		$mkdir $backup_dir_full && cd; echo "[OK]" 
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
	local log_file=$log_path_full/$log_syntax_full

	#Perform backup. "True" in the end will allow script to continue even when rsync
       	#returns errors (such as inaccessible files).
	echo "Backing up."
	$rsync $flags --exclude-from=$exclude --files-from=$include / $backup_dir_full \
	--log-file=$log_file || true;
	cd && echo "Transfer completed successfully.";
	exit_dialogue;	
}

