#!/bin/bash

output_dir=$1
rootfs_mapping=$2
build_log=$output_dir/build.log

[ ! -f ${output_dir}/rootfs.img ] && \
    { log "Error: extracted rootfs partition not found. Aborting."; exit 1; }

sudo dd if=${output_dir}/rootfs.img of=/dev/mapper/${rootfs_mapping} bs=8M >> "$build_log" 2>&1
sync
# Check Linux ext4 file system just in case.
sudo fsck.ext4 -fp /dev/mapper/${rootfs_mapping} >> "$build_log" 2>&1
# Make sure the rootfs partition's label follows Mender naming convention.
sudo tune2fs -L "primary" /dev/mapper/${rootfs_mapping} >> "$build_log" 2>&1

log "\tDone."

exit 0
