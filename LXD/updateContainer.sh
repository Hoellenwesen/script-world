#!/bin/bash

##############
## Settings ##
##############

## Colors
YELLOW='\033[1;33m'
RESET='\e[0m'

##############
##  Script  ##
##############

# Set full path to bins
_apt="/usr/bin/apt-get"
_lxc="/usr/bin/lxc"
_awk="/usr/bin/awk"

# Get containers list
clist="$(${_lxc} list -c ns | ${_awk} '!/NAME/{ if ( $4 == "RUNNING" ) print $2}')"

# Update all container running Debian or Ubuntu
for c in $clist
do
        echo -e "$YELLOW Updating Debian/Ubuntu container hypervisor \"$c\"... $RESET"
        ${_lxc} exec $c ${_apt} -- -qq update
        ${_lxc} exec $c ${_apt} -- -qq -y upgrade
        ${_lxc} exec $c ${_apt} -- -qq -y clean
        ${_lxc} exec $c ${_apt} -- -qq -y autoclean
        ${_lxc} exec $c -- reboot
done
