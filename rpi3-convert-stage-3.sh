#!/bin/bash

output_dir=$1
rootfs_mapping=$2
build_log=$output_dir/build.log

[ ! -f ${output_dir}/rootfs.img ] && \
    { log "Error: extracted rootfs partition not found. Aborting."; exit 1; }

sudo dd if=${output_dir}/rootfs.img of=/dev/mapper/${rootfs_mapping} bs=8M >> "$build_log" 2>&1

# dd sets the original label, make sure label follows Mender naming convention.
sudo e2label /dev/mapper/${rootfs_mapping} "primary"

log "\tDone."

exit 0
