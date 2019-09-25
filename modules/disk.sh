#!/usr/bin/env bash
#
# Copyright 2019 Northern.tech AS
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

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

# Prints number of partitions found in disk image
#
# Example usage:
#
#     nr_of_parts=$(disk_get_nr_of_parts ${disk_image_path})
#
#  $1 - path to disk image
disk_get_nr_of_parts() {
  echo "$(partx -l ${1} | wc -l)"
}

# Extract a file system image from a disk image
#
#  $1 - path to disk image
#  $2 - sector start (in 512 blocks)
#  $3 - size (in 512 blocks)
#  $4 - path to output file
disk_extract_part() {
  run_and_log_cmd "dd if=$1 of=$4 skip=$2 bs=512 count=$3 conv=sparse status=none"
}

# Convert MiB to number of 512 sectors
#
#  $1 - MiB value
disk_mb_to_sectors() {
    echo "$(( (${1} * 1024 * 1024) / 512 ))"
}

# Convert 512 sectors to MiB
#
#  $1 - number of 512 sectors
disk_sectors_to_mb() {
    echo "$(( (${1} * 512) / 1024 / 1024 ))"
}


# Align value (result is number of 512 sectors)
#
# $1 - value to align (number of 512 sectors)
# $2 - alignment in bytes
disk_align_sectors() {
  local size_in_bytes=$(( ${1} * 512))
  local reminder=$(( ${size_in_bytes} % ${2} ))

  if [ $reminder -ne 0 ]; then
    size_in_bytes=$(( $size_in_bytes - $reminder + ${2} ))
  fi

  echo "$(( $size_in_bytes / 512 ))"
}

# Write file at offset of another file
#
# $1 - file to write
# $2 - destination file
# $3 - offset in number of 512 sectors
disk_write_at_offset() {
  run_and_log_cmd "dd if=${1} of=${2} seek=${3} conv=sparse status=none"
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

  case "$4" in
    "ext4")
      MKFS_EXT4="/usr/bin/mkfs.ext4"
      if [ ! -f ${MKFS_EXT4} ]; then
          MKFS_EXT4="/sbin/mkfs.ext4"
      fi
      run_and_log_cmd "${MKFS_EXT4} -q -F ${2}"
      ;;

    "xfs")
      MKFS_XFS="/usr/bin/mkfs.xfs"
      if [ ! -f ${MKFS_XFS} ]; then
          MKFS_XFS="/sbin/mkfs.xfs"
      fi
      run_and_log_cmd "${MKFS_XFS} -q -f ${2}"
      ;;
    *)
    log_fatal "Unknown file system type specified: ${4}"
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
