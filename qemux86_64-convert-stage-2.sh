#!/bin/bash

output_dir=$1
boot_mapping=$2
build_log=$output_dir/build.log

[ ! -f $output_dir/boot.vfat ] && \
    { log "Error: extracted boot partition not found. Aborting."; exit 1; }

# Make a copy of Linux kernel arguments and modify.
mcopy -on -i ${output_dir}/boot.vfat -s ::EFI/BOOT/grub.cfg ${output_dir}/grub.cfg
sed -i 's/\b[ ]root=[^ ]*/ root=\/dev\/hda2/' ${output_dir}/grub.cfg

# Update Linux kernel command arguments with our custom configuration
mcopy -o -i ${output_dir}/boot.vfat -s ${output_dir}/grub.cfg ::EFI/BOOT/grub.cfg

sudo dd if=${output_dir}/boot.vfat of=/dev/mapper/${boot_mapping} bs=1M conv=sparse >> "$build_log" 2>&1

log "\tDone."

exit 0
