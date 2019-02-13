#!/bin/sh

smartctl --scan |  awk '{print $3, $1}' |  grep -v ses0 | \
	while read bus disk
	do
		printf "smartctl -d %s -H %s \t" "$bus" "$disk"
		smartctl -d $bus -H $disk |  awk '/^SMART/ {print $NF}'
	done | column -t -s "	"
