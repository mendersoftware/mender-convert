#!/bin/bash

output_dir=$1
rootfs_mapping=$2

[ ! -f ${output_dir}/rootfs.img ] && \
    { echo "Error: extracted rootfs partition not found. Aborting."; exit 1; }

sudo dd if=${output_dir}/rootfs.img of=/dev/mapper/${rootfs_mapping} bs=8M

# dd sets the original label, make sure label follows Mender naming convention.
sudo e2label /dev/mapper/${rootfs_mapping} "primary"

echo -e "\nStage done."

exit 0
