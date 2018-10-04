#!/bin/bash

# Partition alignment value in bytes (8MB).
partition_alignment=8388608
# Boot partition storage offset in bytes (8MB).
vfat_storage_offset=8388608
# Number of required heads in a final image.
heads=255
# Number of required sectors in a final image.
sectors=63

declare -a mender_disk_partitions=("boot" "primary" "secondary" "data")
declare -a raw_disk_partitions=("boot" "rootfs")

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
files_dir=${tool_dir}/files
output_dir=${tool_dir}/output

embedded_base_dir=$output_dir/embedded
sdimg_base_dir=$output_dir/sdimg

embedded_boot_dir=$embedded_base_dir/boot
embedded_rootfs_dir=$embedded_base_dir/rootfs
sdimg_boot_dir=$sdimg_base_dir/boot
sdimg_primary_dir=$sdimg_base_dir/primary
sdimg_secondary_dir=$sdimg_base_dir/secondary
sdimg_data_dir=$sdimg_base_dir/data

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
      echo "Could not determine partition number from $1"
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

  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $device
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

  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $device
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
#  $3 - size of the sector (in bytes)
#  $4 - boot partition start offset (in sectors)
#  $5 - boot partition size (in sectors)
#  $6 - root filesystem partition start offset (in sectors)
#  $7 - root filesystem partition size (in sectors)
#  $8 - boot flag
get_image_info() {
  local limage=$1
  local rvar_count=$2
  local rvar_sectorsize=$3
  local rvar_bootstart=$4
  local rvar_bootsize=$5
  local rvar_rootfsstart=$6
  local rvar_rootfssize=$7
  local rvar_bootflag=$8

  local lbootsize=0
  local lsubname=${limage:0:8}
  local lfdisk="$(fdisk -u -l ${limage})"

  local lparts=($(echo "${lfdisk}" | grep "^${lsubname}" | cut -d' ' -f1))
  local lcount=${#lparts[@]}

  local lsectorsize=($(echo "${lfdisk}" | grep '^Sector' | cut -d' ' -f4))

  local lfirstpartinfo="$(echo "${lfdisk}" | grep "^${lparts[0]}")"

  idx_start=2
  idx_size=4

  if [[ $lcount -gt 1 ]]; then
    local lsecondpartinfo="$(echo "${lfdisk}" | grep "^${lparts[1]}")"
    local lsecondpartstart=($(echo "${lsecondpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_start}))
    local lsecondpartsize=($(echo "${lsecondpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_size}))
  fi

  eval $rvar_bootflag="0"
  if [[ "$lfirstpartinfo" =~ .*\*.* ]]; then
    eval $rvar_bootflag="1"
    ((idx_start+=1))
    ((idx_size+=1))
  fi

  lfirstpartsize=($(echo "${lfirstpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_size}))
  lfirstpartstart=($(echo "${lfirstpartinfo}" | tr -s ' ' | cut -d' ' -f${idx_start}))

  eval $rvar_count="'$lcount'"
  eval $rvar_sectorsize="'$lsectorsize'"
  eval $rvar_bootstart="'$lfirstpartstart'"
  eval $rvar_bootsize="'$lfirstpartsize'"
  eval $rvar_rootfsstart="'$lsecondpartstart'"
  eval $rvar_rootfssize="'$lsecondpartsize'"

  [[ $lcount -gt 2 ]] && \
      { echo "Unsupported type of source image. Aborting."; return 1; } || \
      { return 0; }
}

# Takes following arguments:
#
#  $1 - raw disk image path
#
# Calculates following values:
#
#  $2 - number of partitions
#  $3 - size of the sector (in bytes)
#  $4 - rootfs A partition start offset (in sectors)
#  $5 - rootfs A partition size (in sectors)
#  $6 - rootfs B partition start offset (in sectors)
#  $7 - rootfs B partition size (in sectors)
get_mender_disk_info() {
  local limage=$1
  local rvar_count=$2
  local rvar_sectorsize=$3
  local rvar_rootfs_a_start=$4
  local rvar_rootfs_a_size=$5
  local rvar_rootfs_b_start=$6
  local rvar_rootfs_b_size=$7

  local lsubname=${limage:0:8}
  local lfdisk="$(fdisk -u -l ${limage})"

  local lparts=($(echo "${lfdisk}" | grep "^${lsubname}" | cut -d' ' -f1))
  local lcount=${#lparts[@]}

  if [[ $lcount -ne 4 ]]; then
    echo "Error: invalid Mender disk image. Aborting."
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
  # Final size is aligned to 8MiB.
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
#  $1 - raw_disk image
#
# Returns:
#
#  $2 - boot partition start offset (in sectors)
#  $3 - boot partition size (in sectors)
#  $4 - root filesystem partition size (in sectors)
#  $5 - sector size (in bytes)
#  $6 - image type
analyse_raw_disk_image() {
  local image=$1
  local count=
  local sectorsize=
  local bootstart=
  local bootsize=
  local rootfsstart=
  local rootfssize=
  local bootflag=

  local rvar_bootstart=$2
  local rvar_bootsize=$3
  local rvar_rootfssize=$4
  local rvar_sectorsize=$5
  local rvar_imagetype=$6

  get_image_info $image count sectorsize bootstart bootsize \
          rootfsstart rootfssize bootflag

  [[ $? -ne 0 ]] && \
      { echo "Error: invalid/unsupported raw_disk image. Aborting."; exit 1; }

  if [[ $count -eq 1 ]]; then
    echo -e "\nDetected single partition raw_disk image."
    rootfssize=$bootsize
    # Default size of the boot partition: 16MiB.
    bootsize=$(( ($partition_alignment * 2) / $sectorsize ))
  elif [[ $count -eq 2 ]]; then
    echo -e "\nDetected multipartition ($count) raw_disk image."
  fi

  # Boot partition storage offset is defined from the top down.
  bootstart=$(( $vfat_storage_offset / $sectorsize ))

  align_partition_size bootsize $sectorsize
  align_partition_size rootfssize  $sectorsize

  eval $rvar_bootstart="'$bootstart'"
  eval $rvar_bootsize="'$bootsize'"
  eval $rvar_rootfssize="'$rootfssize'"
  eval $rvar_sectorsize="'$sectorsize'"
  eval $rvar_imagetype="'$count'"

  echo -e "\nEmbedded image processing summary:\
           \nboot part start sector: ${bootstart}\
           \nboot part size (sectors): ${bootsize}\
           \nrootfs part size (sectors): ${rootfssize}\
           \nsector size (bytes): ${sectorsize}\n"
}

# Takes following arguments:
#
#  $1 - boot partition start offset (in sectors)
#  $2 - boot partition size (in sectors)
#  $3 - root filesystem partition size (in sectors)
#  $4 - data partition size (in MB)
#  $5 - sector size (in bytes)
#
#  Returns:
#
#  $6 - aligned data partition size (in sectors)
#  $7 - final .sdimg file size (in bytes)
calculate_mender_disk_size() {
  local rvar_datasize=$6
  local rvar_sdimgsize=$7

  local datasize=$(( ($4 * 1024 * 1024) / $5 ))

  align_partition_size datasize $5

  local sdimgsize=$(( ($1 + $2 + 2 * ${3} +  $datasize) * $5 ))

  eval $rvar_datasize="'$datasize'"
  eval $rvar_sdimgsize="'$sdimgsize'"
}

# Takes following arguments:
#
#  $1 - raw disk image
unmount_partitions() {
  echo "1. Check if device is mounted..."
  is_mounted=`grep ${1} /proc/self/mounts | wc -l`
  if [ ${is_mounted} -ne 0 ]; then
    sudo umount ${1}?*
  fi
}

# Takes following arguments:
#
#  $1 - raw disk image
erase_filesystem() {
  echo "2. Erase filesystem..."
  sudo wipefs --all --force ${1}?*
  sudo dd if=/dev/zero of=${1} bs=1M count=100
}

# Takes following arguments:
#
#  $1 - raw disk image path
#  $2 - raw disk image size
create_mender_disk() {
  local lfile=$1
  local lsize=$2
  local bs=$(( 1024*1024 ))
  local count=$(( ${lsize} / ${bs} ))

  echo -e "\nWriting $lsize bytes to Mender disk image..."
  dd if=/dev/zero of=${lfile} bs=${bs} count=${count}
}

# Takes following arguments:
#
#  $1 - raw disk image path
#  $2 - raw disk image size
#  $3 - boot partition start offset
#  $4 - boot partition size
#  $5 - root filesystem partiotion size
#  $6 - data partition size
#  $7 - sector size
format_mender_disk() {
  local lfile=$1
  local lsize=$2

#  if [ -z "$3" ]; then
#    echo "Error: no root filesystem size provided"
#    exit 1
#  fi

#  if [ -z "$2" ]; then
#    size=$(sudo blockdev --getsize64 ${sdimg_file})
#  else
#    size=$2
#  fi

  cylinders=$(( ${lsize} / ${heads} / ${sectors} / ${7} ))
  rootfs_size=$(( $5 - 1 ))
  pboot_offset=$(( ${4} - 1 ))
  primary_start=$(( ${3} + ${pboot_offset} + 1 ))
  secondary_start=$(( ${primary_start} + ${rootfs_size} + 1 ))
  data_start=$(( ${secondary_start} + ${rootfs_size} + 1 ))
  data_offset=$(( ${6} - 1 ))

  echo $3 ${pboot_offset} $primary_start $secondary_start $data_start $data_offset

  echo -e "\nFormatting Mender disk image..."

  sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk ${lfile}
	o # clear the in memory partition table
	x
	h
	${heads}
	s
	${sectors}
	c
	${cylinders}
	r
	n # new partition
	p # primary partition
	1 # partition number 1
	${3}  # default - start at beginning of disk
	+${pboot_offset} # 16 MB boot parttion
	t
	c
	a
	n # new partition
	p # primary partition
	2 # partion number 2
	${primary_start}	# start immediately after preceding partition
	+${rootfs_size}
	n # new partition
	p # primary partition
	3 # partion number 3
	${secondary_start}	# start immediately after preceding partition
	+${rootfs_size}
	n # new partition
	p # primary partition
	${data_start}		# start immediately after preceding partition
	+${data_offset}
	p # print the in-memory partition table
	w # write the partition table
	q # and we're done
EOF
}

# Takes following arguments:
#
#  $1 - raw disk file
#
# Returns:
#
#  $2 - number of detected partitions
verify_mender_disk() {
  local lfile=$1
  local rvar_no_of_parts=$2

  local limage=$(basename $lfile)
  local partitions=($(fdisk -l -u ${limage} | grep '^mender' | cut -d' ' -f1))

  local no_of_parts=${#partitions[@]}

  [[ $no_of_parts -eq 4 ]] || \
      { echo "Error: incorrect number of partitions: $no_of_parts. Aborting."; return 1; }

  eval $rvar_no_of_parts=="'$no_of_parts='"

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
        && { echo "Error: partition mappings failed. Aborting."; exit 1; } \
        || { echo "Mapped ${#mappings[@]} partition(s)."; }
  else
    echo "Error: no device passed. Aborting."
    exit 1
  fi

  sudo partprobe /dev/${mappings[0]%p*}

  echo "Mapper device: ${mappings[0]%p*}"
}

# Takes following arguments:
#
#  $1 - partition mappings holder
detach_device_maps() {
  local mappings=($@)

  [ ${#mappings[@]} -eq 0 ] && { echo "Nothing to detach."; return; }

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
make_mender_disk_filesystem() {
  local mappings=($@)
  echo -e "\nCreating filesystem for ${#mappings[@]} partitions..."

  for mapping in ${mappings[@]}
  do
    map_dev=/dev/mapper/"$mapping"
    part_no=$(get_part_number_from_device $map_dev)

    echo -e "\nFormatting partition: ${part_no}..."

    if [[ part_no -eq 1 ]]; then
      sudo mkfs.vfat -n ${mender_disk_partitions[${part_no} - 1]} $map_dev
    else
      sudo mkfs.ext4 -L ${mender_disk_partitions[${part_no} - 1]} $map_dev
    fi
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

  for mapping in ${mappings[@]}
  do
    local part_no=${mapping#*p*p}
    local path=$sdimg_base_dir/${mender_disk_partitions[${part_no} - 1]}
    mkdir -p $path
    sudo mount /dev/mapper/"${mapping}" $path 2>&1 >/dev/null
  done
}

# Takes following arguments
#
#  $1 - device type
set_fstab() {
  echo -e "\nSetting fstab..."
  local mountpoint=
  local device_type=$1
  local sysconfdir="$sdimg_primary_dir/etc"

  [ ! -d "${sysconfdir}" ] && { echo "Error: cannot find rootfs config dir."; exit 1; }

  # Erase/create the fstab file.
  sudo install -b -m 644 /dev/null ${sysconfdir}/fstab

  case "$device_type" in
    "beaglebone")
      mountpoint="/boot/efi"
      ;;
    "raspberrypi3")
      mountpoint="/uboot"
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
	/dev/mmcblk0p1   $mountpoint          auto       defaults,sync    0  0
	/dev/mmcblk0p4   /data                auto       defaults         0  0
	EOF"
}

# Takes following arguments
#
#  $1 - path to source raw disk image
#  $2 - sector start (in 512 blocks)
#  $3 - size (in 512 blocks)

extract_file_from_image() {
    local cmd="dd if=$1 of=${output_dir}/$4 skip=$2 bs=512 count=$3 status=progress"

    echo "Running command:"
    echo "    ${cmd}"
    $(${cmd})
}

# Takes following arguments
#
#  $1 - device type
#  $2 - partition alignment in bytes
#  $3 - boot partition storage offset in bytes
#  $4 - boot partition size in sectors
#  $5 - rootfs partition size in sectors
#  $6 - data partition size in sectors
#  $7 - complete image size in bytes
#  $8 - sector size in bytes

create_test_config_file() {
  local device_type=$1
  local alignment=$2
  local boot_offset=$3
  local boot_size_mb=$(( ((($4 * $8) / 1024) / 1024) ))
  local rootfs_size_mb=$(( ((($5 * $8) / 1024) / 1024) ))
  local data_size_mb=$(( ((($6 * $8) / 1024) / 1024) ))
  local mender_image_size_mb=$(( (($7 / 1024) / 1024) ))

  cp ${files_dir}/variables.template ${files_dir}/${device_type}_variables.cfg

  sed -i '/^MENDER_BOOT_PART_SIZE_MB/s/=.*$/="'${boot_size_mb}'"/' ${files_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_DATA_PART_SIZE_MB/s/=.*$/="'${data_size_mb}'"/' ${files_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_DEVICE_TYPE/s/=.*$/="'${device_type}'"/' ${files_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_PARTITION_ALIGNMENT/s/=.*$/="'${alignment}'"/' ${files_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_STORAGE_TOTAL_SIZE_MB/s/=.*$/="'${mender_image_size_mb}'"/' ${files_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_UBOOT_ENV_STORAGE_DEVICE_OFFSET/s/=.*$/="'${boot_offset}'"/' ${files_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_CALC_ROOTFS_SIZE/s/=.*$/="'${rootfs_size_mb}'"/' ${files_dir}/${device_type}_variables.cfg
  sed -i '/^MENDER_MACHINE/s/=.*$/="'${device_type}'"/' ${files_dir}/${device_type}_variables.cfg
}

# Takes following arguments
#
#  $1 - device type
#  $2 - parameter name to change
#  $3 - parameter value
update_test_config_file() {
  local device_type=$1

  [ ! -f "${files_dir}/${device_type}_variables.cfg" ] && \
      { echo "Error: test configuration file '${device_type}_variables.cfg' not found. Aborting."; return 1; }

  shift

  while test ${#} -gt 0
  do
    case "$1" in
      "artifact-name")
        sed -i '/^MENDER_ARTIFACT_NAME/s/=.*$/="'${2}'"/' ${files_dir}/${device_type}_variables.cfg
        ;;
      "distro-feature")
        sed -i '/^DISTRO_FEATURES/s/=.*$/="'${2}'"/' ${files_dir}/${device_type}_variables.cfg
        ;;
      "mount-location")
        sed -i '/^MENDER_BOOT_PART_MOUNT_LOCATION/s/=.*$/="'${2}'"/' ${files_dir}/${device_type}_variables.cfg
        ;;
    esac
    shift 2
  done

  return 0
}
