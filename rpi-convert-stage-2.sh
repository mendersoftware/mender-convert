#!/bin/bash

output_dir=$1
boot_mapping=$2
build_log=$output_dir/build.log

[ ! -f $output_dir/boot.vfat ] && \
    { log "Error: extracted boot partition not found. Aborting."; exit 1; }

sudo dd if=${output_dir}/boot.vfat of=/dev/mapper/${boot_mapping} bs=1M conv=sparse >> "$build_log" 2>&1

log "\tDone."

exit 0
