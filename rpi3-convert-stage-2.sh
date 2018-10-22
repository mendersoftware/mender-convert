#!/bin/bash

output_dir=$1
boot_mapping=$2

[ ! -f $output_dir/boot.vfat ] && \
    { echo "Error: extracted boot partition not found. Aborting."; exit 1; }

# Make a copy of Linux kernel arguments and modify.
mcopy -on -i ${output_dir}/boot.vfat -s ::cmdline.txt ${output_dir}/cmdline.txt
sed -i 's/\b[ ]root=[^ ]*/ root=\/dev\/mmcblk0p2/' ${output_dir}/cmdline.txt
sed -i 's/\b[ ]console=tty1//' ${output_dir}/cmdline.txt
# Update Linux kernel command arguments with our custom configuration
mcopy -o -i ${output_dir}/boot.vfat -s ${output_dir}/cmdline.txt ::cmdline.txt

mcopy -on -i ${output_dir}/boot.vfat -s ::config.txt ${output_dir}/config.txt
echo -e '\nenable_uart=1\n' >> ${output_dir}/config.txt
mcopy -o -i ${output_dir}/boot.vfat -s ${output_dir}/config.txt ::config.txt

sudo dd if=${output_dir}/boot.vfat of=/dev/mapper/${boot_mapping} bs=1M

echo -e "\tDone."

exit 0
