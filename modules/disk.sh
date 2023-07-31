#!/usr/bin/env bash
# Copyright 2023 Northern.tech AS
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

# Print desired information about a partition
#
# Example usage:
#
#     part_one_start=$(disk_get_part_value ${disk_image_path} 1 START)
#
#  $1 - path to disk image
#  $2 - part number
#  $3 - information to be printed
#
# We use 'partx' to parse input disk image and it supports the following fields:
#
#         NR  partition number
#      START  start of the partition in sectors
#        END  end of the partition in sectors
#    SECTORS  number of sectors
#       SIZE  human readable size
#       NAME  partition name
#       UUID  partition UUID
#       TYPE  partition type (a string, a UUID, or hex)
#      FLAGS  partition flags
#     SCHEME  partition table type (dos, gpt, ...)
disk_get_part_value() {
    echo "$(partx -o ${3} -g -r --nr ${2} ${1})"
}

# Prints the partition numbers of all the partitions
#
# Example usage:
#
#     part_nums=$(disk_get_part_nums ${disk_image_path})
#
#  $1 - path to disk image
disk_get_part_nums() {
    partx --show $1 | tail -n +2 \
                               | while read line; do
            echo $line | awk '{printf "%d\n", $1}'
        done
}

# Extract a file system image from a disk image
#
#  $1 - path to disk image
#  $2 - sector start (in 512 blocks)
#  $3 - size (in 512 blocks)
#  $4 - path to output file
disk_extract_part() {
    run_and_log_cmd "dd if=$1 of=$4 skip=${2}b bs=1M count=${3}b status=none iflag=count_bytes,skip_bytes"
}

# Convert MiB to number of 512 sectors
#
#  $1 - MiB value
disk_mb_to_sectors() {
    echo "$(((${1} * 1024 * 1024) / 512))"
}

# Convert 512 sectors to MiB
#
#  $1 - number of 512 sectors
disk_sectors_to_mb() {
    echo "$(((${1} * 512) / 1024 / 1024))"
}

# Align value (result is number of 512 sectors)
#
# $1 - value to align (number of 512 sectors)
# $2 - alignment in bytes
disk_align_sectors() {
    local size_in_bytes=$((${1} * 512))
    local reminder=$((${size_in_bytes} % ${2}))

    if [ $reminder -ne 0 ]; then
        size_in_bytes=$(($size_in_bytes - $reminder + ${2}))
    fi

    echo "$(($size_in_bytes / 512))"
}

# Write file at offset of another file
#
# $1 - file to write
# $2 - destination file
# $3 - offset in number of 512 sectors
disk_write_at_offset() {
    run_and_log_cmd "dd if=${1} of=${2} seek=${3} conv=notrunc status=none"
}

# Create file system image from directory content
#
# $1 - base folder
# $2 - destination file
# $3 - image size in sectors
# $4 - file system type, e.g ext4, xfs, ...
disk_create_file_system_from_folder() {
    log_info "Creating a file-system image from: ${1}"

    run_and_log_cmd "dd if=/dev/zero of=${2} seek=${3} count=0 bs=512 status=none"

    case ${1} in
        *data/) EXTRA_OPTS="${MENDER_DATA_PART_MKFS_OPTS}" ;;
        *rootfs/) EXTRA_OPTS="${MENDER_ROOT_PART_MKFS_OPTS}" ;;
        *) EXTRA_OPTS="" ;;
    esac

    case "$4" in
        "ext4")
            MKFS_EXT4="/usr/bin/mkfs.ext4"
            if [ ! -f ${MKFS_EXT4} ]; then
                MKFS_EXT4="/sbin/mkfs.ext4"
            fi
            run_and_log_cmd "${MKFS_EXT4} -q -F ${2} ${EXTRA_OPTS}"
            ;;

        "xfs")
            MKFS_XFS="/usr/bin/mkfs.xfs"
            if [ ! -f ${MKFS_XFS} ]; then
                MKFS_XFS="/sbin/mkfs.xfs"
            fi
            run_and_log_cmd "${MKFS_XFS} -q -f ${2} ${EXTRA_OPTS}"
            ;;
        *)
            log_fatal "Unknown file system type specified: ${4}"
            ;;
    esac

    run_and_log_cmd "mkdir -p work/output"
    run_and_log_cmd "sudo mount ${2} work/output"
    run_and_log_cmd "sudo rsync --archive --delete ${1} work/output/"
    run_and_log_cmd "sudo umount work/output"
}

# Print path to the boot partition filesystem image
#
disk_boot_part() {
    # Why this little dance you might wonder.
    #
    # Some disk images do not have a boot partition, but our integration does
    # require one and this is why there is a difference here.
    #
    # If input image did not have a boot part it will be generated and be called:
    #
    #  work/boot-generated.vfat
    #
    # This is mostly done to make it obvious that we have created an empty vfat file.
    #
    # But if the disk image already had a boot part, we assume that it is the first
    # partition that was extracted.
    #
    # We also need to adjust the part number of the rootfs part depending on if
    # boot part was extracted or generated.
    boot_part="work/boot-generated.vfat"
    if [ ! -f ${boot_part} ]; then
        boot_part="work/part-1.fs"
    fi
    echo "${boot_part}"
}

# Print path to the root partition filesystem image
#
disk_root_part() {
    boot_part="work/boot-generated.vfat"
    if [ ! -f ${boot_part} ]; then
        root_part="work/part-2.fs"
    else
        root_part="work/part-1.fs"
    fi
    echo "${root_part}"
}

# Check if supplied argument is valid partuuid device path.
# Supports both dos and gpt paths
#
# $1 - partuuid device path
disk_is_valid_partuuid_device() {
    disk_is_valid_partuuid_gpt_device "$1" || disk_is_valid_partuuid_dos_device "$1"
}

# Check if supplied argument is valid gpt partuuid device path.
#
# Example: /dev/disk/by-partuuid/26445670-f37c-408b-be2c-3ef419866620
#
# $1 - gpt partuuid device path
disk_is_valid_partuuid_gpt_device() {
    echo "${1}" | grep -qE '^/dev/disk/by-partuuid/([0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12})$'
}

# Check if supplied argument is valid dos partuuid device path.
#
# Example: /dev/disk/by-partuuid/26445670-01
#
# $1 - dos partuuid device path
disk_is_valid_partuuid_dos_device() {
    echo "${1}" | grep -qE '^/dev/disk/by-partuuid/[0-9a-f]{8}-[0-9a-f]{2}$'
}

# Get partuuid from supplied device path.
# Supports both dos and gpt paths
#
# $1 - partuuid device path
disk_get_partuuid_from_device() {
    if ! disk_is_valid_partuuid_device "${1}"; then
        log_fatal "Invalid partuuid device: '${1}'"
    fi
    echo "${1}" | sed "s:/dev/disk/by-partuuid/::"
}

# Get dos disk identifier from supplied device path.
#
# $1 - dos compatible partuuid device path
disk_get_partuuid_dos_diskid_from_device() {
    if ! disk_is_valid_partuuid_dos_device "${1}"; then
        log_fatal "Invalid dos partuuid device: '${1}'"
    fi
    partuuid=$(disk_get_partuuid_from_device "${1}")
    echo "$partuuid" | cut -d- -f1
}

# Get dos partuuid number from supplied device path.
#
# $1 - dos compatible partuuid device path
disk_get_partuuid_dos_part_number() {
    if ! disk_is_valid_partuuid_dos_device "${1}"; then
        log_fatal "Invalid dos partuuid device: '${1}'"
    fi
    partuuid=$(disk_get_partuuid_from_device "${1}")
    echo "$partuuid" | cut -d- -f2
}

# Get correct device path for current configuration.
# Unrecognized or unsupported device paths will generate an error
#
# $1 - partition number to use if fine grained variable not set
# $2 - fine grained device part variable name
disk_get_part_device() {
    part="${!2}"
    if [ "${MENDER_ENABLE_PARTUUID}" == "y" ]; then
        if ! disk_is_valid_partuuid_device "${part}"; then
            log_fatal "Invalid partuuid device for ${2}: '${part}'"
        fi
    else
        part="${MENDER_STORAGE_DEVICE_BASE}${1}"
    fi
    echo "${part}"
}

disk_boot_part_device() {
    disk_get_part_device "${MENDER_BOOT_PART_NUMBER}" "MENDER_BOOT_PART"
}

disk_data_part_device() {
    disk_get_part_device "${MENDER_DATA_PART_NUMBER}" "MENDER_DATA_PART"
}

disk_root_part_a_device() {
    disk_get_part_device "${MENDER_ROOTFS_PART_A_NUMBER}" "MENDER_ROOTFS_PART_A"
}

disk_root_part_b_device() {
    disk_get_part_device "${MENDER_ROOTFS_PART_B_NUMBER}" "MENDER_ROOTFS_PART_B"
}

# Get device partition number from device path.
# Unrecognized or unsupported device paths will generate an error
#
# $1 - device path
disk_get_device_part_number() {
    dev_part="unknown"
    case "$1" in
        /dev/nvme*n*p*)
            dev_part=$(echo $1 | cut -dp -f2)
            ;;
        /dev/mmcblk*p*)
            dev_part=$(echo $1 | cut -dp -f2)
            ;;
        /dev/[sh]d[a-z][1-9]*)
            dev_part=${1##*d[a-z]}
            ;;
        ubi*_*)
            dev_part=$(echo $1 | cut -d_ -f2)
            ;;
        /dev/disk/by-partuuid/*)
            if disk_is_valid_partuuid_dos_device "$1"; then
                dev_part=$(disk_get_partuuid_dos_part_number "$1")
                dev_part=$((16#${dev_part}))
            else
                log_fatal "partition number does not exist for GPT partuuid: '$1'"
            fi
            ;;
    esac
    part=$(printf "%d" $dev_part 2> /dev/null)
    if [ $? = 1 ]; then
        log_fatal "Could not determine partition number from '${1}'"
    else
        echo "$part"
    fi
}

# Get device base path without partition number from argument.
# Unrecognized or unsupported device paths will generate an error
#
# $1 - device path
disk_get_device_base() {
    dev_base=""
    case "$1" in
        /dev/nvme*n*p*)
            dev_base=$(echo $1 | cut -dp -f1)
            ;;
        /dev/mmcblk*p*)
            dev_base=$(echo $1 | cut -dp -f1)
            ;;
        /dev/[sh]d[a-z][1-9]*)
            dev_base=${1%%[1-9]*}
            ;;
        ubi*_*)
            dev_base=$(echo $1 | cut -d_ -f1)
            ;;
        /dev/disk/by-partuuid/*)
            log_fatal "device base does not exist for GPT partuuid: '$1'"
            ;;
    esac
    if [ -z "$dev_base" ]; then
        log_fatal "Could not determine device base from '${1}'"
    else
        echo $dev_base
    fi
}

# Conditionally redefine partition number/device if fine grained variable set.
#
# $1 - variable name
# $2 - variable value
disk_override_partition_variable() {
    if [ "${MENDER_ENABLE_PARTUUID}" == "y" ]; then
        if disk_is_valid_partuuid_dos_device "${2}"; then
            eval "${1}"=$(disk_get_device_part_number "${2}")
        fi
    else
        if [ -n "${2}" ]; then
            eval "${1}"=$(disk_get_device_part_number "${2}")
            MENDER_STORAGE_DEVICE_BASE=$(disk_get_device_base "${2}")
        fi
    fi
}
