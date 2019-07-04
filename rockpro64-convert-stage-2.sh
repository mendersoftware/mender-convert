#!/bin/bash

output_dir=$1
boot_mapping=$2
embedded_rootfs_dir=$3
uboot_backup_dir=${embedded_rootfs_dir}/opt/backup/uboot
build_log=$output_dir/build.log

boot_part_dev="/dev/mapper/${boot_mapping}"

[ ! -f $output_dir/boot.vfat ] && \
    { log "Error: extracted boot partition not found. Aborting."; exit 1; }
[ ! -d "${embedded_rootfs_dir}" ] && \
    { log "Error: embedded content not mounted."; exit 1; }
[ ! -e ${boot_part_dev} ] && \
    { log "Error: boot part does not exist: ${boot_part_dev}."; exit 1; }

sudo dd if=${output_dir}/boot.vfat of=${boot_part_dev} bs=1M conv=sparse >> "$build_log" 2>&1

log "\tDone."

exit 0
