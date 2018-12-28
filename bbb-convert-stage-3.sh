#!/bin/bash

sdimg_primary_dir=$1
embedded_rootfs_dir=$2

[ ! -d "${sdimg_primary_dir}" ] &&  \
    { log "Error: rootfs location not mounted."; exit 1; }
[ ! -d "${embedded_rootfs_dir}" ] && \
    { log "Error: embedded content not mounted."; exit 1; }

# Copy rootfs partition.
sudo cp -ar ${embedded_rootfs_dir}/* ${sdimg_primary_dir}

log "\tDone."

exit 0
