#!/bin/bash

##############
## Settings ##
##############

BACKUPDATE=$(date +"%Y-%m-%d_%H-%M")
FILENAME=backup-$BACKUPDATE.tar.gz
BASEDIR="/mnt/docker_data/bitwarden"
SRCDIR="bwdata"
BACKUPDIR="/mnt/backup/bitwarden"
MAXBACKUPDAYS="14"

## Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RESET='\e[0m'

## Messages
ERR='\e[1;31m ERROR\e[0m'

##############
##  Script  ##
##############

# Checking backupdate
check_backupdate () {
    if [ -z "$BACKUPDATE" ]; then
        echo -e "$ERR Could not determine backupdate: $BACKUPDATE $RESET"
        return 1
    fi
}

### Main backup tasks
echo -e "$YELLOW Starting backup of bitwarden... $RESET"

# Check for backup dir
if [ ! -d "$BACKUPDIR" ]; then
	mkdir $BACKUPDIR && cd $BACKUPDIR
	echo -e "$GREEN Backup directory $BASEDIR/$BACKUPDIR created $RESET"
fi

# Change to the backupdir for all the file store operations
cd $BACKUPDIR

# Create backup file
echo -e; sleep 0.5s
if tar -cpzf $BACKUPDIR/$FILENAME $BASEDIR/$SRCDIR; then
	echo -e "$GREEN Succesfully created backup file $FILENAME $RESET"
else
	echo -e "$ERR Could not create backup file $FILENAME $RESET"
	exit 1
fi

# Delete old backup files
echo -e; sleep 0.5s
backupcount=$(find "${BACKUPDIR}"/*.tar.gz | wc -l)
echo -e "$YELLOW ${backupcount} $RESET backup(s) found."
backupsoudatedcount=$(find "${BACKUPDIR}"/ -type f -name "*.tar.gz" -mtime +"${MAXBACKUPDAYS}"|wc -l)
if [ "${backupsoudatedcount}" -gt "0" ]; then
	echo -e "$YELLOW ${backupsoudatedcount} backup(s) are older than ${MAXBACKUPDAYS} days. $RESET"
	find "${BACKUPDIR}"/ -type f -mtime +"${MAXBACKUPDAYS}" -exec rm -f {} \;
	echo -e "$GREEN ${backupsoudatedcount} deleted $RESET"
else
	echo -e "$YELLOW No old backups found $RESET"
fi

echo -e; sleep 0.5s
echo -e "$YELLOW Starting update process... $RESET"
$BASEDIR/bitwarden.sh updateself
$BASEDIR/bitwarden.sh update