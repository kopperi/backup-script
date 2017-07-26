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
