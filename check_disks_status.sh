#!/bin/sh

# List of disks
DISKS=$(camcontrol devlist | grep -v Enclosure | awk '{print $NF}' | sed -e's/[)(]//' -e 's/,.*$//')

# SMART report dispaly filters
FILTERS=$(cat <<__EOF | xargs | sed 's/ /|/g'
_Error
Power_Cycle_Count
Temperature
__EOF
)

# Highlights
BOLD=`tput bold`
END=`tput sgr0`

for d in ${DISKS}; do
	echo "==== SMART report for ${BOLD}$d${END} ===="
	smartctl -a "/dev/${d}" | grep -E "${FILTERS}"
	echo
done
