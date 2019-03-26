#!/bin/bash

# Partition alignment value in bytes.
declare -i partition_alignment
# Boot partition storage offset in bytes.
declare -i vfat_storage_offset

PART_ALIGN_4MB=4194304
PART_ALIGN_8MB=8388608

# Default 'data' partition size in MiB.
declare -i data_part_size_mb
# Default total storage size in MiB.
declare -i storage_total_size_mb

DATA_PART_SIZE_MB=128
STORAGE_TOTAL_SIZE_MB=8000

# Number of required heads in a final image.
declare -i -r heads=255
# Number of required sectors in a final image.
declare -i -r sectors=63

declare -a mender_partitions_regular=('boot' 'primary' 'secondary' 'data')
declare -a mender_partitions_extended=('boot' 'primary' 'secondary' 'n/a' 'data' 'swap')
declare -a raw_disk_partitions=('boot' 'rootfs')

declare -A raw_disk_sizes
declare -A mender_disk_sizes

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
files_dir=${tool_dir}/files
output_dir=${tool_dir}/output
build_log=${output_dir}/build.log

embedded_base_dir=$output_dir/embedded
sdimg_base_dir=$output_dir/sdimg

embedded_boot_dir=$embedded_base_dir/boot
embedded_rootfs_dir=$embedded_base_dir/rootfs
sdimg_boot_dir=$sdimg_base_dir/boot
sdimg_primary_dir=$sdimg_base_dir/primary
sdimg_secondary_dir=$sdimg_base_dir/secondary
sdimg_data_dir=$sdimg_base_dir/data

logsetup() {
  [ ! -f $build_log ] && { touch $build_log; }
  echo -n "" > $build_log
  exec > >(tee -a $build_log)
  exec 2>&1
}

log() {
  echo -e "$*"
}

# Takes following arguments:
#
#  $1 -relative file path
get_path() {
  echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

get_part_number_from_device() {
  case "$1" in
    /dev/*[0-9]p[1-9])
      echo ${1##*[0-9]p}
      ;;
    /dev/[sh]d[a-z][1-9])
      echo ${1##*d[a-z]}
      ;;
    ubi[0-9]_[0-9])
      echo ${1##*[0-9]_}
      ;;
    [a-z]*\.sdimg[1-9])
      echo ${1##*\.sdimg}
      ;;
    /dev/mapper/*[0-9]p[1-9])
      echo ${1##*[0-9]p}
      ;;
    *)
      log "Could not determine partition number from $1"
      exit 1
      ;;
  esac
}

# Takes following arguments:
#
#  $1 - raw disk image
#  $2 - boot partition start offset (in sectors)
#  $3 - boot partition size (in sectors)
create_single_disk_partition_table() {
  local device=$1
  local bootstart=$2
  local stopsector=$(( $3 - 1 ))

  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $device &> /dev/null
	d # delete partition
	n # new partition
	p # primary partition
	1 # partion number 1
	${bootstart}
	+${stopsector}
	a # set boot flag
	w # write the partition table
	q # and we're done
EOF
}

# Takes following arguments:
#
#  $1 - raw disk image
#  $2 - root filesystem partition start offset (in sectors)
#  $3 - root filesystem partition size (in sectors)
create_double_disk_partition_table() {
  local device=$1
  local rootfsstart=$2
  local rootfsstop=$(( $3 - 1 ))

  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $device &> /dev/null
	d # delete partition
	2
	n
	p
	2
	${rootfsstart}
	+${rootfsstop}
	w # write the partition table
	q # and we're done
EOF
}

# Takes following arguments:
#
#  $1 - raw_disk image path
#
# Calculates following values:
#
#  $2 - number of partitions
#  $3 - array of partitions' sizes for raw disk
#
get_raw_disk_sizes() {
  local limage=$1
  local rvar_count=$2
  shift 2
  local rvar_array=($@)

  local lsubname=${limage:0:10}
  local lfdisk="$(fdisk -u -l ${limage})"
  local lparts=($(echo "${lfdisk}" | grep "^${lsubname}" | cut -d' ' -f1))
  local lcount=${#lparts[@]}

  if [[ $lcount -gt 3 ]]; then
    log "\tError: invalid/unsupported raw disk image. Aborting."
    return 1
  fi

  local lsectorsize=($(echo "${lfdisk}" | grep '^Sector' | cut -d' ' -f4))

  local idx_start=2
  local idx_size=4

  local lfirstpartinfo="$(echo "${lfdisk}" | grep "^${lparts[0]}")"

  if [[ $lcount -gt 1 ]]; then
    local lsecondpartinfo="$(echo "${lfdisk}" | grep "^${lparts[1]}")"
    eval $rvar_array[prootfs_start]="'$(echo "${lsecondpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_start})'"
    eval $rvar_array[prootfs_size]="'$(echo "${lsecondpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_size})'"
  fi

  if [[ $lcount -gt 2 ]]; then
    local lthirdpartinfo="$(echo "${lfdisk}" | grep "^${lparts[2]}")"
    eval $rvar_array[pswap_start]="'$(echo "${lthirdpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_start})'"
    eval $rvar_array[pswap_size]="'$(echo "${lthirdpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_size})'"
  fi

  # Check is first partition is marked as bootable.
  if [[ "$lfirstpartinfo" =~ .*\*.* ]]; then
    ((idx_start+=1))
    ((idx_size+=1))
  fi

  eval $rvar_array[pboot_start]="'$(echo "${lfirstpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_start})'"
  eval $rvar_array[pboot_size]="'$(echo "${lfirstpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_size})'"
  eval $rvar_array[sector_size]="'$lsectorsize'"

  eval $rvar_count="'$lcount'"

  return 0
}

# Takes the following argument
#  $1 - device type
#
# Calculates the following arguments:
#  $2 - partition alignment
#  $3 - vfat storage offset

set_mender_disk_alignment() {
  local rvar_partition_alignment=$2
  local rvar_vfat_storage_offset=$3

  case "$1" in
    "beaglebone" | "qemux86_64")
      local lvar_partition_alignment=${PART_ALIGN_8MB}
      local lvar_vfat_storage_offset=$lvar_partition_alignment
      ;;
    "raspberrypi3" | "raspberrypi0w")
      local lvar_partition_alignment=${PART_ALIGN_4MB}
      local lvar_uboot_env_size=$(( $lvar_partition_alignment * 2 ))
      local lvar_vfat_storage_offset=$(( $lvar_partition_alignment + $lvar_uboot_env_size ))
      ;;
    *)
      log "Error: unsupported device type $1"
      exit 1
      ;;
  esac

  eval $rvar_partition_alignment="'$lvar_partition_alignment'"
  eval $rvar_vfat_storage_offset="'$lvar_vfat_storage_offset'"
}

# Takes following arguments:
#
#  $1 - Mender disk image path
#
# Calculates following values:
#
#  $2 - number of partitions
#  $3 - size of the sector (in bytes)
#  $4 - rootfs A partition start offset (in sectors)
#  $5 - rootfs A partition size (in sectors)
#  $6 - rootfs B partition start offset (in sectors)
#  $7 - rootfs B partition size (in sectors)
get_mender_disk_sizes() {
  local limage=$1
  local rvar_count=$2
  local rvar_sectorsize=$3
  local rvar_rootfs_a_start=$4
  local rvar_rootfs_a_size=$5
  local rvar_rootfs_b_start=$6
  local rvar_rootfs_b_size=$7

  local lsubname=${limage:0:10}
  local lfdisk="$(fdisk -u -l ${limage})"

  local lparts=($(echo "${lfdisk}" | grep "^${lsubname}" | cut -d' ' -f1))
  local lcount=${#lparts[@]}

  if [[ $lcount -ne 4 ]] && [[ $lcount -ne 6 ]]; then
    log "Error: invalid Mender disk image. Aborting."
    return 1
  else
    local lsectorsize=($(echo "${lfdisk}" | grep '^Sector' | cut -d' ' -f4))

    local lrootfs_a_info="$(echo "${lfdisk}" | grep "^${lparts[1]}")"
    local lrootfs_b_info="$(echo "${lfdisk}" | grep "^${lparts[2]}")"

    idx_start=2
    idx_size=4

    local lrootfs_a_start=($(echo "${lrootfs_a_info}" | tr -s ' ' | cut -d' ' -f${idx_start}))
    local lrootfs_a_size=($(echo "${lrootfs_a_info}" | tr -s ' ' | cut -d' ' -f${idx_size}))
    local lrootfs_b_start=($(echo "${lrootfs_b_info}" | tr -s ' ' | cut -d' ' -f${idx_start}))
    local lrootfs_b_size=($(echo "${lrootfs_b_info}" | tr -s ' ' | cut -d' ' -f${idx_size}))

    eval $rvar_count="'$lcount'"
    eval $rvar_sectorsize="'$lsectorsize'"
    eval $rvar_rootfs_a_start="'$lrootfs_a_start'"
    eval $rvar_rootfs_a_size="'$lrootfs_a_size'"
    eval $rvar_rootfs_b_start="'$lrootfs_b_start'"
    eval $rvar_rootfs_b_size="'$lrootfs_b_size'"

    return 0
  fi
}

# Takes following arguments:
#
#  $1 - size variable to be aligned in sectors
#  $2 - size of the sector
#
align_partition_size() {
  # Final size is aligned with reference to 'partition_alignment' variable.
  local rvar_size=$1
  local -n ref=$1

  local size_in_bytes=$(( $ref * $2 ))
  local reminder=$(( ${size_in_bytes} % ${partition_alignment} ))

  if [ $reminder -ne 0 ]; then
    size_in_bytes=$(( $size_in_bytes - $reminder + ${partition_alignment} ))
  fi

  local lsize=$(( $size_in_bytes / $2 ))

  eval $rvar_size="'$lsize'"
}

# Takes following arguments:
#
#  $1 - number of partition of the raw disk image
#  $2 - mender image partition alignment
#  $3 - mender image's boot partition offset
#  $4 - data partition size (in MB)
#  $5 - array of partitions' sizes for raw image
#
# Returns:
#
#  $6 - array of partitions' sizes for Mender image
#
set_mender_disk_sizes() {
  local count=$1
  local alignment=$2
  local offset=$3
  local datasize_mb=$4
  local _raw_sizes=$(declare -p $5)
  eval "declare -A raw_sizes="${_raw_sizes#*=}
  shift 5
  local rvar_array=($@)

  local sector_size=${raw_sizes[sector_size]}
  local datasize=$(( ($datasize_mb * 1024 * 1024) / $sector_size ))

  local bootstart=
  local bootsize=
  local rootfsstart=
  local rootfssize=
  local bootflag=

  if [[ $count -eq 1 ]]; then
    # Default size of the boot partition: 16MiB.
    bootsize=$(( (${alignment} * 2) / ${sector_size} ))
    # Root filesystem size is determined by the size of the single partition.
    rootfssize=${raw_sizes[pboot_size]}
  else
    bootsize=${raw_sizes[pboot_size]}
    rootfssize=${raw_sizes[prootfs_size]}
  fi

  # Boot partition storage offset is defined from the top down.
  bootstart=$(( ${offset} / ${sector_size} ))

  align_partition_size bootsize $sector_size
  align_partition_size rootfssize $sector_size
  align_partition_size datasize $sector_size

  eval $rvar_array[pboot_start]="'$bootstart'"
  eval $rvar_array[pboot_size]="'$bootsize'"
  eval $rvar_array[prootfs_size]="'$rootfssize'"
  eval $rvar_array[pdata_size]="'$datasize'"

  if [[ $count -eq 3 ]]; then
    # Add space for Swap partition.
    local swapsize=${raw_sizes[pswap_size]}
    align_partition_size swapsize $sector_size
    eval $rvar_array[pswap_size]="'$swapsize'"
  fi

  eval $rvar_array[sector_size]="'$sector_size'"
}

# Takes following arguments:
#
#  $1 - partition alignment
#  $2 - array of partitions' sizes for Mender image
#
#  Returns:
#
#  #3 - number of partitions of the Mender disk image
#  $4 - final Mender disk image size (in bytes)
#
calculate_mender_disk_size() {
  local _mender_sizes=$(declare -p $2)
  eval "declare -A mender_sizes="${_mender_sizes#*=}
  local sector_size=${mender_sizes[sector_size]}
  local rvar_counts=$3
  local rvar_sdimgsize=$4

  local sdimgsize=$(( (${mender_sizes[pboot_start]} + ${mender_sizes[pboot_size]} + \
                       2 * ${mender_sizes[prootfs_size]} + \
                       ${mender_sizes[pdata_size]}) * $sector_size ))

  eval $rvar_counts="'4'"

  if [ -v mender_sizes[pswap_size] ]; then
     log "\tSwap partition found."
     # Add size of the swap partition to the total size.
     sdimgsize=$(( $sdimgsize + (${mender_sizes[pswap_size]} * $sector_size) ))
     # Add alignment used as swap partition offset.
     sdimgsize=$(( $sdimgsize + 2 * ${1} ))
     eval $rvar_counts="'6'"
  fi

  eval $rvar_sdimgsize="'$sdimgsize'"
}

# Takes following arguments:
#
#  $1 - number of partition of the Mender image
#  $2 - calculated total size of the Mender image in bytes
#  $3 - expected total size of the Mender image in mb
#  $4 - array of partitions' sizes for Mender image
#
#  Returns:
#
#  Size of the rootfs partition updated and adjusted to total storage size
#
mender_image_size_to_total_storage_size() {
  local count=$1
  local rvar_image_size=$2
  local -n image_size_bytes=$2
  local storage_size_mb=$3

  local _mender_sizes=$(declare -p $4)
  eval "declare -A mender_sizes="${_mender_sizes#*=}

  shift 3
  local rvar_array=($@)

  local image_size_mb=$(( (($image_size_bytes / 1024) / 1024) ))

  log "\tAdjust Mender disk image size to the total storage size (${storage_size_mb}MB)."

  if [ $image_size_mb -gt $storage_size_mb ]; then
    log "\tDefined total storage size of ${3}MB is too small."
    log "\tMinimal required storage is ${image_size_mb}MB. Aborting."
    return 1
  elif [ $image_size_mb -eq $storage_size_mb ]; then
    # Simply continue.
    log "\tCalculated Mender image size exactly fits the defined total storage."
    return 0
  fi

  # Get spare space for rootfs a/b partitions (in sectors).
  local sector_size=${mender_sizes[sector_size]}
  local image_size_s=$(( $image_size_bytes / $sector_size ))
  local storage_size_bytes=$(( ($storage_size_mb * 1024 * 1024) ))
  local storage_size_s=$(( $storage_size_bytes / $sector_size ))
  local rootfs_overplus_bytes=0

  local spare_storage_bytes=$(( $storage_size_bytes - $image_size_bytes ))

  if [ $(($spare_storage_bytes % 2)) -ne 0 ]; then
    log "\tAdditional space for rootfs partitions not divisible by 2.\
         \n\tFinal image will be smaller than ${storage_size_mb}MB"
  fi
  rootfs_overplus_bytes=$(( $spare_storage_bytes / 2 ))

  local reminder=$(( ${rootfs_overplus_bytes} % ${partition_alignment} ))
  if [ $reminder -ne 0 ]; then
    log "\tAdditional space for rootfs partitions not aligned.\
         \n\tFinal image will be smaller than ${storage_size_mb}MB"
  fi
  rootfs_overplus_bytes=$(($rootfs_overplus_bytes - $reminder))
  rootfs_overplus_s=$(( $rootfs_overplus_bytes / $sector_size ))

  local prootfs_size=${mender_sizes[prootfs_size]}
  prootfs_size=$(( $prootfs_size + $rootfs_overplus_s ))

  image_size_bytes=$(( $image_size_bytes + 2 * $rootfs_overplus_bytes ))

  eval $rvar_array[prootfs_size]="'$prootfs_size'"
  eval $rvar_image_size="'$image_size_bytes'"

  return 0
}

# Takes following arguments:
#
#  $1 - raw disk image path
#  $2 - raw disk image size
create_mender_disk() {
  local lfile=$1
  local lsize=$2

  # Generates a sparse image
  dd if=/dev/zero of=${lfile} seek=${lsize} bs=1 count=0 >> "$build_log" 2>&1
}

# Takes following arguments:
#
#  $1 - Mender disk image path
#  $2 - Mender disk image size
#  $3 - partition alignment
#  $4 - array of partitions' sizes for Mender image
#
format_mender_disk() {
  local lfile=$1
  local lsize=$2
  local rc=0

  local _mender_sizes=$(declare -p $4)
  eval "declare -A mender_sizes="${_mender_sizes#*=}

  local sector_size=${mender_sizes[sector_size]}
  local alignment=$(($3 / ${sector_size}))

  cylinders=$(( ${lsize} / ${heads} / ${sectors} / ${sector_size} ))

  pboot_start=${mender_sizes[pboot_start]}
  pboot_size=${mender_sizes[pboot_size]}
  pboot_end=$((${pboot_start} + ${pboot_size} - 1))

  prootfs_size=${mender_sizes[prootfs_size]}

  prootfsa_start=$((${pboot_end} + 1))
  prootfsa_end=$((${prootfsa_start} + ${prootfs_size} - 1))

  prootfsb_start=$((${prootfsa_end} + 1))
  prootfsb_end=$((${prootfsb_start} + ${prootfs_size} - 1))

  pdata_start=$((${prootfsb_end} + 1))
  pdata_size=${mender_sizes[pdata_size]}
  pdata_end=$((${pdata_start} + ${pdata_size} - 1))

  if [ -v mender_sizes[pswap_size] ]; then
    local pextended_start=$((${prootfsb_end} + 1))

    pdata_start=$(($pextended_start + ${alignment}))
    pdata_end=$((${pdata_start} + ${pdata_size} - 1))

    local pswap_start=$((${pdata_end} + ${alignment} + 1))
    local pswap_size=${mender_sizes[pswap_size]}
    local pswap_end=$((${pswap_start} + ${pswap_size} - 1))
  fi

  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk ${lfile} &> /dev/null
	o # clear the in memory partition table
	x
	h
	${heads}
	s
	${sectors}
	c
	${cylinders}
	r
	w # write the partition table
	q # and we're done
EOF

  # Create partition table
  sudo parted -s ${lfile} mklabel msdos || rc=$?
  sudo parted -s ${lfile} unit s mkpart primary fat32 ${pboot_start} ${pboot_end} || rc=$?
  sudo parted -s ${lfile} set 1 boot on || rc=$?
  sudo parted -s ${lfile} -- unit s mkpart primary ext4 ${prootfsa_start} ${prootfsa_end} || rc=$?
  sudo parted -s ${lfile} -- unit s mkpart primary ext4 ${prootfsb_start} ${prootfsb_end} || rc=$?

  if [ -v mender_sizes[pswap_size] ]; then
    log "\tAdding swap partition."
    sudo parted -s ${lfile} -- unit s mkpart extended ${pextended_start} 100% || rc=$?
    sudo parted -s ${lfile} -- unit s mkpart logical ext4 ${pdata_start} ${pdata_end} || rc=$?
    sudo parted -s ${lfile} -- unit s mkpart logical linux-swap ${pswap_start} ${pswap_end} || rc=$?
  else
    sudo parted -s ${lfile} -- unit s mkpart primary ext4 ${pdata_start} ${pdata_end} || rc=$?
  fi

  [[ $rc -eq 0 ]] && { log "\tChanges in partition table applied."; }

  return $rc
}

# Takes following arguments:
#
#  $1 - raw disk file
#
verify_mender_disk() {
  local lfile=$1
  local lcounts=$2

  local limage=$(basename $lfile)
  local partitions=($(fdisk -l -u ${limage} | cut -d' ' -f1 | grep 'sdimg[1-9]\{1\}$'))

  local no_of_parts=${#partitions[@]}

  [[ $no_of_parts -eq $lcounts ]] || \
      { log "Error: incorrect number of partitions: $no_of_parts. Aborting."; return 1; }

  return 0
}

# Takes following arguments:
#
#  $1 - raw disk image
#  $2 - partition mappings holder
create_device_maps() {
  local -n mappings=$2

  if [[ -n "$1" ]]; then
    mapfile -t mappings < <( sudo kpartx -v -a $1 | grep 'loop' | cut -d' ' -f3 )
    [[ ${#mappings[@]} -eq 0 ]] \
        && { log "Error: partition mappings failed. Aborting."; exit 1; }
  else
    log "Error: no device passed. Aborting."
    exit 1
  fi

  sudo partprobe /dev/${mappings[0]%p*}
}

# Takes following arguments:
#
#  $1 - partition mappings holder
detach_device_maps() {
  local mappings=($@)

  [ ${#mappings[@]} -eq 0 ] && { log "\tPartition mappings cleaned."; return; }

  local mapper=${mappings[0]%p*}

  for mapping in ${mappings[@]}
  do
    map_dev=/dev/mapper/"$mapping"
    is_mounted=`grep ${map_dev} /proc/self/mounts | wc -l`
    if [ ${is_mounted} -ne 0 ]; then
      sudo umount -l $map_dev
    fi
  done

  sudo kpartx -d /dev/$mapper &
  sudo losetup -d /dev/$mapper &
  wait && sync
}

# Takes following arguments:
#
#  $1 - partition mappings holder
#
make_mender_disk_filesystem() {
  local mappings=($@)
  local counts=${#mappings[@]}

  if [ $counts -eq 4 ]; then
    local labels=(${mender_partitions_regular[@]})
  elif [ $counts -eq 6 ]; then
    local labels=(${mender_partitions_extended[@]})
  fi

  for mapping in ${mappings[@]}
  do
    map_dev=/dev/mapper/"$mapping"
    part_no=$(get_part_number_from_device $map_dev)
    label=${labels[${part_no} - 1]}

    case ${part_no} in
      1)
        log "\tCreating MS-DOS filesystem for '$label' partition."
        sudo mkfs.vfat -n ${label} $map_dev >> "$build_log" 2>&1
        ;;
      2|3)
        log "\tCreating ext4 filesystem for '$label' partition."
        sudo mkfs.ext4 -L ${label} $map_dev >> "$build_log" 2>&1
        ;;
      4)
        if [ $counts -eq 4 ]; then
          log "\tCreating ext4 filesystem for '$label' partition."
          sudo mkfs.ext4 -L ${label} $map_dev >> "$build_log" 2>&1
        else
          continue
        fi
        ;;
      5)
        log "\tCreating ext4 filesystem for '$label' partition."
        sudo mkfs.ext4 -L ${label} $map_dev >> "$build_log" 2>&1
        ;;
      6)
        log "\tCreating swap area for '$label' partition."
        sudo mkswap -L ${label} $map_dev >> "$build_log" 2>&1
        ;;
      *)
        break
        ;;
    esac
  done
}

# Takes following arguments:
#
#  $1 - partition mappings holder
mount_raw_disk() {
  local mappings=($@)

  if [ ${#mappings[@]} -eq 1 ]; then
    local path=$embedded_rootfs_dir
    mkdir -p $path
    sudo mount /dev/mapper/"${mappings[0]}" $path
    return
  fi

  for mapping in ${mappings[@]}
  do
    local part_no=${mapping#*p*p}
    local path=$embedded_base_dir/${raw_disk_partitions[${part_no} - 1]}
    mkdir -p $path
    sudo mount /dev/mapper/"${mapping}" $path 2>&1 >/dev/null
  done
}

# Takes following arguments:
#
#  $1 - partition mappings holder
mount_mender_disk() {
  local mappings=($@)
  local counts=${#mappings[@]}

  if [ $counts -eq 4 ]; then
    local labels=(${mender_partitions_regular[@]})
  elif [ $counts -eq 6 ]; then
    local labels=(${mender_partitions_extended[@]})
  fi

  for mapping in ${mappings[@]}
  do
    local part_no=${mapping#*p*p}
    local path=$sdimg_base_dir/${labels[${part_no} - 1]}
    mkdir -p $path

    case ${part_no} in
      1|2|3)
        sudo mount /dev/mapper/"${mapping}" $path 2>&1 >/dev/null
        ;;
      4)
        if [ $counts -eq 4 ]; then
          sudo mount /dev/mapper/"${mapping}" $path 2>&1 >/dev/null
        else
          # Skip extended partition.
          continue
        fi
        ;;
      5)
        sudo mount /dev/mapper/"${mapping}" $path 2>&1 >/dev/null
        ;;
      6)
        # Skip swap partition.
        continue
        ;;
      *)
        break
        ;;
    esac

  done
}

# Takes following arguments
#
#  $1 - device type
set_fstab() {
  local mountpoint=
  local blk_device=
  local data_id=4
  local device_type=$1
  local sysconfdir="$sdimg_primary_dir/etc"

  [ ! -d "${sysconfdir}" ] && { log "Error: cannot find rootfs config dir."; exit 1; }

  # Erase/create the fstab file.
  sudo install -b -m 644 /dev/null ${sysconfdir}/fstab

  case "$device_type" in
    "beaglebone")
      mountpoint="/boot/efi"
      blk_device=mmcblk0p
      ;;
    "raspberrypi3"|"raspberrypi0w")
      mountpoint="/uboot"
      blk_device=mmcblk0p
      ;;
    "qemux86_64")
      mountpoint="/boot/efi"
      blk_device=hda
      data_id=5
      ;;
    *)
      log "Error: unsupported device type $device_type"
      exit 1
      ;;
  esac

  # Add Mender specific entries to fstab.
  sudo bash -c "cat <<- EOF > ${sysconfdir}/fstab
	# stock fstab - you probably want to override this with a machine specific one

	/dev/root            /                    auto       defaults              1  1
	proc                 /proc                proc       defaults              0  0
	devpts               /dev/pts             devpts     mode=0620,gid=5       0  0
	tmpfs                /run                 tmpfs      mode=0755,nodev,nosuid,strictatime 0  0
	tmpfs                /var/volatile        tmpfs      defaults              0  0

	# uncomment this if your device has a SD/MMC/Transflash slot
	#/dev/mmcblk0p1       /media/card          auto       defaults,sync,noauto  0  0

	# Where the U-Boot environment resides; for devices with SD card support ONLY!
	/dev/${blk_device}1   $mountpoint          auto       defaults,sync    0  0
	/dev/${blk_device}${data_id}   /data          auto       defaults         0  0
	EOF"

  if [ "$device_type" == "qemux86_64" ]; then
    # Add entry referring to swap partition.
    sudo tee -a ${sysconfdir}/fstab <<< "/dev/hda6       swap    swap    defaults        0       0" 2>&1 >/dev/null
  fi

  log "\tDone."
}

# Takes following arguments
#
#  $1 - path to source raw disk image
#  $2 - sector start (in 512 blocks)
#  $3 - size (in 512 blocks)

extract_file_from_image() {
  log "\tStoring data in $4."
  local cmd="dd if=$1 of=${output_dir}/$4 skip=$2 bs=512 count=$3 conv=sparse"
  $(${cmd}>> "$build_log" 2>&1)
}

# Takes following arguments
#
#  $1 - device type
#  $2 - partition alignment in bytes
#  $3 - total size in bytes
#  $4 - array of partitions' sizes for Mender image
#
create_test_config_file() {
  local device_type=$1
  local alignment=$2
  local mender_image_size_mb=$(( (($3 / 1024) / 1024) ))
  local _mender_sizes=$(declare -p $4)
  eval "declare -A mender_sizes="${_mender_sizes#*=}
  local sector_size=${mender_sizes[sector_size]}

  local boot_offset=$(( (${mender_sizes[pboot_start]} * $sector_size) ))
  local boot_size_mb=$(( (((${mender_sizes[pboot_size]} * $sector_size) / 1024) / 1024) ))
  local rootfs_size_mb=$(( (((${mender_sizes[prootfs_size]} * $sector_size) / 1024) / 1024) ))
  local data_size_mb=$(( (((${mender_sizes[pdata_size]} * $sector_size) / 1024) / 1024) ))

  cp ${files_dir}/variables.template ${output_dir}/${device_type}_variables.cfg

  sed -i '/^MENDER_BOOT_PART_SIZE_MB/s/=.*$/="'${boot_size_mb}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_DATA_PART_SIZE_MB/s/=.*$/="'${data_size_mb}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_DEVICE_TYPE/s/=.*$/="'${device_type}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_PARTITION_ALIGNMENT/s/=.*$/="'${alignment}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_STORAGE_TOTAL_SIZE_MB/s/=.*$/="'${mender_image_size_mb}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_UBOOT_ENV_STORAGE_DEVICE_OFFSET/s/=.*$/="'${boot_offset}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_CALC_ROOTFS_SIZE/s/=.*$/="'${rootfs_size_mb}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_MACHINE/s/=.*$/="'${device_type}'"/' ${output_dir}/${device_type}_variables.cfg
  sed -i '/^DEPLOY_DIR_IMAGE/s/=.*$/="'${output_dir//\//\\/}'"/' ${output_dir}/${device_type}_variables.cfg
}

# Takes following arguments
#
#  $1 - device type
#  $2 - parameter name to change
#  $3 - parameter value
update_test_config_file() {
  local device_type=$1

  [ ! -f "${output_dir}/${device_type}_variables.cfg" ] && \
      { log "Error: test configuration file '${device_type}_variables.cfg' not found. Aborting."; return 1; }

  shift

  while test ${#} -gt 0
  do
    case "$1" in
      "artifact-name")
        sed -i '/^MENDER_ARTIFACT_NAME/s/=.*$/="'${2}'"/' ${output_dir}/${device_type}_variables.cfg
        ;;
      "distro-feature")
        sed -i '/^DISTRO_FEATURES/s/=.*$/="'${2}'"/' ${output_dir}/${device_type}_variables.cfg
        ;;
      "mount-location")
        sed -i '/^MENDER_BOOT_PART_MOUNT_LOCATION/s/=.*$/="'${2}'"/' ${output_dir}/${device_type}_variables.cfg
        ;;
    esac
    shift 2
  done

  return 0
}
