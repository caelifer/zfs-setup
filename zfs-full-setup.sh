#!/usr/bin/env bash

## Print usage
help() {
	printf "\nUsage:\n\t%s <create | destroy> [num-of-disks]\n\n" $(basename $0) >&2
	exit 1
}

if [ $# -lt 1 ]
then
	help
fi

count_disks() {
	ATA_DISKS=$(sudo camcontrol devlist 2>/dev/null | grep ada | wc -l | xargs)
	test $ATA_DISKS -ne 0 && echo $ATA_DISKS || echo 1
}

# Upper bounds for the seq command
DISK_COUNT=$((${2:-$(count_disks)} - 1))

if [ $DISK_COUNT -eq 0 ]
then
	echo "$(basename $0): No ATA disks found" >&2
	exit 1
fi

# Disk partiton size (based on start offset 4K + (total # of 512B sectors - ~50MB)
SLICE_SZ=7813934680

# Zpool name
ZPOOL_NAME=ztank

# Name of the dataset
DATASET_NAME=ztank/data

# Mount points for data and snapshots on ztank
MOUNT_POINTS=/ztank/{data,snapshots}

# Device bash sub template, i.e. {0,1,2,3}
DEV_BASH_TMPL=$(seq 0 $DISK_COUNT | xargs | sed 's/ /,/g')

create() {
	## 1. Setup GEOM providers - GPART slices of fixed size (7813934680 512B blocks) 
	for i in $(seq 0 $DISK_COUNT)
	do
		cat <<__
gpart create -s GPT ada$i \
	&& gpart add -b 4096 -s $SLICE_SZ -t freebsd-zfs -l disk0$i ada$i \
	&& gpart show ada$i
__
	done

	## 2. Setup new RAIDZ2 zpool tank from the GEOM providers

	cat <<__
sysctl vfs.zfs.min_auto_ashift=12
zpool create -m none $ZPOOL_NAME raidz2 gpt/disk0{$DEV_BASH_TMPL}
__

	## 3. Create new ZFS and mount it

	cat <<__
mkdir -p $MOUNT_POINTS
zfs create -o mountpoint=/$DATASET_NAME $DATASET_NAME
__

}

destroy() {
	## 1. Destroy all datasets inside ztank

	cat <<__
zfs destroy -r $ZPOOL_NAME
__

	## 2. Destory zpool ztank
	cat <<__
zpool destroy ztank
__

	## 3. Remove partitions and disk lable
	for i in $(seq 0 $DISK_COUNT)
	do
		cat <<__
gpart destroy -F ada$i
__
	done
}

## Parse CLI arguments
case $1 in
create)
	create
	;;
destroy)
	destroy
	;;
*)
	help
esac

# vim: :ts=4:sw=4:noexpandtab
