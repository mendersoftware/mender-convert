#!/bin/bash

set -e

show_help() {
  cat << EOF

Custom user files installer.

Usage: $0 [options]

    Options: [-m|--mender-disk-image -r|--rootfs-overlay | -b|--boot-overlay | -d|--data-overlay -h|--help]

        --mender-disk-image - Mender raw disk image
        --rootfs-overlay      - Path to rootfs overlay
        --boot-overlay      - Path to boot partition overlay
        --data-overlay      - Path to data partition overlay
        --help              - Show help and exit

    For examples, see: ./mender-convert --help

EOF
  exit 1
}

declare -a mender_disk_mappings

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

do_install_overlay() {
    local source=$1
    local loopback=$2

    local map_dest=/dev/mapper/"${loopback}"
    local path_dest=$output_dir/${loopback}
    mkdir -p ${path_dest}

    sudo mount ${map_dest} ${path_dest}

    # Attempt to copy the files, preserving attributes.
    # If this fails (e.g. because the file system is vfat)
    # then copy without preserving attributes
    sudo cp -a ${source}/* ${path_dest} 2>/dev/null || log "\t\t\tfiles copied without preserving attributes" && sudo cp -r ${source}/* ${path_dest}

    sudo umount ${map_dest}
    rmdir ${path_dest}
}

do_install_overlays() {
    if [ -z "${mender_disk_image}" ]; then
        log "Mender raw disk image not set. Aborting."
        show_help
    fi

    create_device_maps $mender_disk_image mender_disk_mappings

    if [ -n "${boot_overlay}" ]; then
        log "\t\tInstalling boot overlay..."
        do_install_overlay ${boot_overlay} ${mender_disk_mappings[0]}
    fi

    if [ -n "${rootfs_overlay}" ]; then
        log "\t\tInstalling rootfs overlay..."
        do_install_overlay ${rootfs_overlay} ${mender_disk_mappings[1]}
    fi

    if [ -n "${data_overlay}" ]; then
        log "\t\tInstalling data overlay..."
        do_install_overlay ${data_overlay} ${mender_disk_mappings[3]}
    fi

    # Cleanup
    detach_device_maps ${mender_disk_mappings[@]}
    log "\tOverlays installed."
}

while (( "$#" )); do
  case "$1" in
    -m | --mender-disk-image)
      mender_disk_image=$2
      shift 2
      ;;
    -r | --rootfs-overlay)
      rootfs_overlay=$2
      shift 2
      ;;
    -b | --boot-overlay)
      boot_overlay=$2
      shift 2
      ;;
    -d | --data-overlay)
      data_overlay=$2
      shift 2
      ;;
    -h | --help)
      show_help
      ;;
    -*)
      log "Error: unsupported option $1"
      exit 1
      ;;
  esac
done

cd ${tool_dir}

do_install_overlays
