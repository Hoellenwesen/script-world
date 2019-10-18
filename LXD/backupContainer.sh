#!/bin/bash

##############
## Settings ##
##############

BACKUPDIR="/mnt/data/backups/lxd"
BACKUPDATE=$(date +"%Y-%m-%d_%H-%M")
MAXBACKUPDAYS="14"

## Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RESET='\e[0m'

## Messages
ERR='\e[1;31m ERROR\e[0m'

# Set full path to bins
_lxc="/usr/bin/lxc"
_awk="/usr/bin/awk"

##############
##  Script  ##
##############

# Get containers list
#clist="$(${_lxc} list -c ns | ${_awk} '!/NAME/{ if ( $4 == "RUNNING" || $4 == "STOPPED") print $2}')"
clist="$(${_lxc} list -c ns | ${_awk} '!/NAME/{ if ( $4 == "RUNNING") print $2}')"

# Checking backupdate
check_backupdate () {
    if [ -z "$BACKUPDATE" ]; then
        echo -e "$ERR Could not determine backupdate: $BACKUPDATE $RESET"
        return 1
    fi
}

### Cleanup tasks

# Cleanup the LXC snapshots
cleanup_snapshot () {
    check_backupdate
    if $_lxc info $c|grep $BACKUPDATE; then
        if $_lxc delete $c/$BACKUPDATE; then
            echo -e "$GREEN Cleanup: Succesfully deleted snapshot $c/$BACKUPDATE - $OUTPUT $RESET"
        else
            echo -e "$ERR Cleanup: Could not delete snapshot $c/$BACKUPDATE - $OUTPUT $RESET"
            return 1
        fi
    fi
}

# Cleanup the image created by LXC
cleanup_image () {
    check_backupdate
    if $_lxc image info $c-BACKUP-$BACKUPDATE-IMAGE; then
        if $_lxc image delete $c-BACKUP-$BACKUPDATE-IMAGE; then
            echo "Cleanup: Succesfully deleted image $c-BACKUP-$BACKUPDATE-IMAGE"
        else
            echo "Cleanup: Could not delete image $c-BACKUP-$BACKUPDATE-IMAGE"
            return 1
        fi
    fi
}

# Aggregated cleanup functions
cleanup () {
    cleanup_snapshot
    cleanup_image
}

### Main backup tasks

for c in $clist
do
    echo -e "$YELLOW Starting backup of container \"$c\"... $RESET"

    # Check for backup dir
    if [ ! -d "$BACKUPDIR/$c" ]; then
        mkdir $BACKUPDIR/$c && cd $BACKUPDIR/$c
        echo -e "$GREEN Backup directory $BACKUPDIR/$c created $RESET"
    fi

    # Change to the backupdir for all the file store operations
    cd $BACKUPDIR/$c

    # Create snapshot with date as name
    echo -e; sleep 0.5s
    if $_lxc snapshot $c $BACKUPDATE; then
        echo -e "$GREEN Snapshot: Succesfully created snaphot $BACKUPDATE on container $c $RESET"
    else
        echo -e "$ERR Snapshot: Could not create snaphot $BACKUPDATE on container $c $RESET"
        return 1
    fi

    # Publish container snapshot to create image
    echo -e; sleep 0.5s
    if $_lxc publish --force $c/$BACKUPDATE --alias $c-BACKUP-$BACKUPDATE-IMAGE; then
        echo -e "$GREEN Publish: Succesfully published an image of $c-BACKUP-$BACKUPDATE to $c-BACKUP-$BACKUPDATE-IMAGE $RESET"
    else
        echo -e "$ERR Publish: Could not create image from $c-BACKUP-$BACKUPDATE to $c-BACKUP-$BACKUPDATE-IMAGE $RESET"
        cleanup
        return 1
    fi

    # Export lxc image to tar.gz file
    echo -e; sleep 0.5s
    if $_lxc image export $c-BACKUP-$BACKUPDATE-IMAGE $c-BACKUP-$BACKUPDATE-IMAGE.tar.gz; then
        echo -e "$GREEN Image: Succesfully exported an image of $c-BACKUP-$BACKUPDATE-IMAGE to $BACKUPDIR/$c/$c-BACKUP-$BACKUPDATE-IMAGE.tar.gz $RESET"
    else
        echo -e "$ERR Image: Could not publish image from $c-BACKUP-$BACKUPDATE-IMAGE to $BACKUPDIR/$c/$c-BACKUP-$BACKUPDATE-IMAGE.tar.gz $RESET"
        cleanup
        exit 1
    fi

    # Delete old backup files
    echo -e; sleep 0.5s
    backupcount=$(find "${BACKUPDIR}"/$c/*.tar.gz | wc -l)
    echo -e "$YELLOW ${backupcount} $RESET backup(s) found."
    backupsoudatedcount=$(find "${BACKUPDIR}"/$c -type f -name "*.tar.gz" -mtime +"${MAXBACKUPDAYS}"|wc -l)
    if [ "${backupsoudatedcount}" -gt "0" ]; then
        echo -e "$YELLOW ${backupsoudatedcount} backup(s) are older than ${MAXBACKUPDAYS} days. $RESET"
        find "${BACKUPDIR}"/$c -type f -mtime +"${MAXBACKUPDAYS}" -exec rm -f {} \;
        echo -e "$GREEN ${backupsoudatedcount} deleted $RESET"
    else
        echo -e "$YELLOW No old backups found $RESET"
    fi

    # Cleanup everything after backup
    cleanup
done
