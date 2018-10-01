#!/bin/bash

show_help() {
cat << EOF

Mender conversion tool

A tool for taking an existing embedded image (Debian, Ubuntu, Raspbian, etc) and
convert it to a Mender image by restructuring partition table and adding
necessary files.

Usage: $0 [prepare_image | make_sdimg | install_mender | install_bootloader | make_all] [options]

Actions:

        prepare_image       - shrinks existing embedded image

        make_sdimg          - composes image file compliant with Mender partition
                              layout

        install_mender      - installs Mender client related files

        install_bootloader  - installs Grub related files

        make_artifact       - creates Mender artifact file based on .sdimg file

        make_all            - composes fully functional .sdimg file compliant
                              with Mender partition layout, having all necessary
                              files installed

Options: [-e|--embedded | -i|--image | -s|--size-data | -d|--device-type |
          -r|--rootfs_type | -p| --demo-ip | -c| --certificate |
          -u| --production-url | -o| --hosted-token]

        embedded       - raw disk embedded linux image path, e.g. Debian 9.3, Raspbian, etc.
        image          - raw disk .sdimg file name where the script writes to
        size-data      - size of data partition in MiB; default value 128MiB
        device-type    - target device identification used to build .sdimg name
        rootfs_type    - selects rootfs_a|rootfs_b as the source filesystem for an artifact
        demo_ip        - server demo ip used for testing purposes
        certificate    - server certificate file
        production-url - production server url
        hosted-token   - mender hosted token

        Note: root filesystem size used in .sdimg creation can be found as an
              output from 'prepare_image' command or, in case of using unmodified
              embedded image, can be checked with any partition manipulation
              program (e.g. parted, fdisk, etc.).

Examples:

    To shrink the existing embedded image:

        ./mender-convert.sh prepare_image --embedded <embedded_image_file_path>

        Output: Root filesystem size (sectors): 4521984

    To prepare .sdimg file:

        ./mender-convert.sh make_sdimg --image <sdimg_file_name>
                --embedded <embedded_image_file_path>
                --size-data 128 --device-type beaglebone

	Output: ready to use ./output/*.sdimg file which can be used to flash SD card

    To install Mender client related files:

        ./mender-convert.sh install_mender --image <sdimg_file_path>
                --device-type beaglebone --artifact release-1_1.5.0
                --demo-ip 192.168.10.2 --mender <mender_binary_path>

        Output: ./output/*.sdimg file with Mender client related files installed

    To install Grub/U-Boot related files:

        ./mender-convert.sh install_bootloader --image <sdimg_file_path>
                --device-type beaglebone --toolchain arm-linux-gnueabihf

        Output: ./output/*.sdimg file with Grub/U-Boot related files installed

    To prepare .mender artifact file:

        ./mender-convert.sh make_artifact --image <sdimg_file_path>
                --device-type beaglebone --artifact release-1_1.5.0
                --rootfs-type rootfs_a

        Note: artifact name format is: release-<release_no>_<mender_version>

    To compose .sdimg file in a single step:

        ./mender-convert.sh make_all --embedded <embedded_image_file_path>
                --image <sdimg_file_name> --device-type raspberrypi3
                --mender <mender_binary_path> --artifact release-1_1.5.0
                --demo-ip 192.168.10.2 --toolchain arm-linux-gnueabihf --keep

EOF
}

if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default sector size
sector_size=
# Boot partition start in sectors (512 bytes per sector).
pboot_start=
# Default 'boot' partition size in sectors: 16MiB
# (i.e 16777216 bytes, equals to 'erase_block' * 2)
pboot_size=
# Default 'data' partition size in MiB.
data_size=128
# Data partition size in sectors.
pdata_size=
# Exemplary values for Beaglebone: 9.3: 4521984 9.4: 4423680
prootfs_size=

menderimage=
embeddedimage=
device_type=
partitions_number=
artifact=
rootfs_type=
image_type=
mender=
# Mender production certificate.
certificate=
# Mender production server url.
production_url=
# Mender demo server IP address.
demo_ip=
# Mender hosted token.
hosted_token=

declare -a rootfs_types=("rootfs_a" "rootfs_b")
declare -a sdimgmappings
declare -a embedmappings

do_prepare_image() {
  if [ -z "${embeddedimage}" ]; then
    echo "Embedded image not set. Aborting."
    exit 1
  fi

  local count=
  local bootstart=
  local bootsize=
  local rootfsstart=
  local rootfssize=
  local bootflag=

  # Gather information about embedded image.
  get_image_info $embeddedimage count sector_size bootstart bootsize \
          rootfsstart rootfssize bootflag

  # Find first available loopback device.
  loopdevice=($(losetup -f))

  # Mount appropriate partition.
  if [[ $count -eq 1 ]]; then
    sudo losetup $loopdevice $embeddedimage -o $(($bootstart * $sector_size))
  elif [[ $count -eq 2 ]]; then
    sudo losetup $loopdevice $embeddedimage -o $(($rootfsstart * $sector_size))
  else
    echo "Error: invalid/unsupported embedded image. Aborting."
    exit 1
  fi

  [ $? -ne 0 ] && { echo "Error: inaccesible loopback device"; exit 1; }

  block_size=($(sudo dumpe2fs -h $loopdevice | grep 'Block size' | tr -s ' ' | cut -d ' ' -f3))
  min_size_blocks=($(sudo resize2fs -P $loopdevice | awk '{print $NF}'))

  new_size_sectors=$(( $min_size_blocks * $block_size / $sector_size ))
  align_partition_size new_size_sectors $sector_size

  echo -e "Root filesystem size:"
  echo -e "\nminimal: $(( $min_size_blocks * $block_size ))"
  echo -e "\naligned: $(( $new_size_sectors * $sector_size ))"
  echo -e "\nsectors: $new_size_sectors"

  sudo e2fsck -y -f $loopdevice
  sudo resize2fs -p $loopdevice ${new_size_sectors}s
  sudo e2fsck -y -f $loopdevice

  sudo losetup -d $loopdevice
  sudo losetup $loopdevice $embeddedimage

  if [[ $count -eq 1 ]]; then
    create_single_disk_partition_table $loopdevice $bootstart $new_size_sectors
  elif [[ $count -eq 2 ]]; then
    echo
    create_double_disk_partition_table $loopdevice $rootfsstart $new_size_sectors
  fi

  sudo partprobe
  endsector=($(sudo parted $loopdevice -ms unit s print | grep "^$count" | cut -f3 -d: | sed 's/[^0-9]*//g'))

  sudo losetup -d $loopdevice
  echo "Image new endsector: $endsector"
  truncate -s $((($endsector+1) * $sector_size)) $embeddedimage
  echo "Root filesystem size (sectors): $new_size_sectors"
}

do_make_sdimg() {
  if [ -z "${embeddedimage}" ]; then
    echo "Source embedded image not set. Aborting."
    exit 1
  fi

  if [ -z "${device_type}" ]; then
    echo "Target device type name not set. Aborting."
    exit 1
  fi

  if [[ ! -f ${embeddedimage} ]]; then
    echo "Source embedded image not found. Aborting."
    exit 1
  fi

  mkdir -p $output_dir && cd $output_dir

  # In case of missing .sdimg name use the default format.
  [ -z $menderimage ] && menderimage=$output_dir/mender_${device_type}.sdimg \
                      || menderimage=$output_dir/$menderimage

  analyse_embedded_image ${embeddedimage} pboot_start pboot_size prootfs_size \
                                          sector_size image_type

  [ -z "${prootfs_size}" ] && \
    { echo "root filesystem size not set. Aborting."; exit 1; }

  local menderimage_size=
  calculate_sdimg_size $pboot_start $pboot_size  \
                       $prootfs_size $data_size  \
                       $sector_size pdata_size menderimage_size

  echo -e "Creating Mender *.sdimg file:\
           \nimage size: ${menderimage_size} bytes\
           \nroot filesystem size: ${prootfs_size} sectors\
           \ndata partition size: $pdata_size sectors\n"

  create_sdimg $menderimage $menderimage_size
  format_sdimg $menderimage $menderimage_size $pboot_start $pboot_size \
               $prootfs_size $pdata_size $sector_size
  verify_sdimg $menderimage partitions_number

  create_device_maps $menderimage sdimgmappings
  make_sdimg_filesystem ${sdimgmappings[@]}

  case "$device_type" in
    "beaglebone")
      do_make_sdimg_beaglebone
      ;;
    "raspberrypi3")
      do_make_sdimg_raspberrypi3
      ;;
  esac

  rc=$?

  echo -e "\nCleaning..."
  # Clean and detach.
  detach_device_maps ${sdimgmappings[@]}
  detach_device_maps ${embedmappings[@]}
  sync
  rm -rf $embedded_base_dir
  rm -rf $sdimg_base_dir

  [ $rc -eq 0 ] && { echo -e "\n$menderimage image created."; } \
                || { echo -e "\n$menderimage image composing failure."; }
}

do_make_sdimg_beaglebone() {
  local ret=0

  create_device_maps $embeddedimage embedmappings

  mount_sdimg ${sdimgmappings[@]}
  mount_embedded ${embedmappings[@]}

  echo -e "\nSetting boot partition..."
  stage_2_args="$sdimg_boot_dir $embedded_rootfs_dir"
  ${tool_dir}/bbb-convert-stage-2.sh ${stage_2_args} || ret=$?
  [[ $ret -ne 0 ]] && { echo "Aborting."; return $ret; }

  echo -e "\nSetting root filesystem..."
  stage_3_args="$sdimg_primary_dir $embedded_rootfs_dir"
  ${tool_dir}/bbb-convert-stage-3.sh ${stage_3_args} || ret=$?
  [[ $ret -ne 0 ]] && { echo "Aborting."; return $ret; }

  set_fstab $device_type

  return $ret
}

do_make_sdimg_raspberrypi3() {
  image_boot_part=$(fdisk -l ${embeddedimage} | grep FAT32)

  boot_part_start=$(echo ${image_boot_part} | awk '{print $2}')
  boot_part_end=$(echo ${image_boot_part} | awk '{print $3}')
  boot_part_size=$(echo ${image_boot_part} | awk '{print $4}')

  extract_file_from_image ${embeddedimage} ${boot_part_start} \
                          ${boot_part_size} "boot.vfat"

  image_rootfs_part=$(fdisk -l ${embeddedimage} | grep Linux)

  rootfs_part_start=$(echo ${image_rootfs_part} | awk '{print $2}')
  rootfs_part_end=$(echo ${image_rootfs_part} | awk '{print $3}')
  rootfs_part_size=$(echo ${image_rootfs_part} | awk '{print $4}')

  extract_file_from_image ${embeddedimage} ${rootfs_part_start} \
                          ${rootfs_part_size} "rootfs.img"

  echo -e "\nSetting boot partition..."
  stage_2_args="$output_dir ${sdimgmappings[0]}"
  ${tool_dir}/rpi3-convert-stage-2.sh ${stage_2_args} || ret=$?
  [[ $ret -ne 0 ]] && { echo "Aborting."; return $ret; }

  echo -e "\nSetting root filesystem..."
  stage_3_args="$output_dir ${sdimgmappings[1]}"
  ${tool_dir}/rpi3-convert-stage-3.sh ${stage_3_args} || ret=$?
  [[ $ret -ne 0 ]] && { echo "Aborting."; return $ret; }

  mount_sdimg ${sdimgmappings[@]}

  # Add mountpoints.
  sudo install -d -m 755 ${sdimg_primary_dir}/uboot
  sudo install -d -m 755 ${sdimg_primary_dir}/data

  set_fstab $device_type
}

do_install_mender() {
  # Mender executables, service and configuration files installer.
  if [ -z "$menderimage" ] || [ -z "$device_type" ] || [ -z "$mender" ] || \
     [ -z "$artifact" ]; then
    show_help
    exit 1
  fi
  # mender-image-1.5.0
  stage_4_args="-i $menderimage -d $device_type -m ${mender} -a ${artifact}"

  if [ -n "$demo_ip" ]; then
    stage_4_args="${stage_4_args} -p ${demo_ip}"
  fi

  if [ -n "$certificate" ]; then
    stage_4_args="${stage_4_args} -c ${certificate}"
  fi

  if [ -n "$production_url" ]; then
    stage_4_args="${stage_4_args} -u ${production_url}"
  fi

  if [ -n "${hosted_token}" ]; then
    stage_4_args="${stage_4_args} -o ${hosted_token}"
  fi

  eval set -- " ${stage_4_args}"

  export -f create_device_maps
  export -f detach_device_maps

  ${tool_dir}/convert-stage-4.sh ${stage_4_args}
}

do_install_bootloader() {
  if [ -z "$menderimage" ] || [ -z "$device_type" ] || \
     [ -z "$toolchain" ]; then
    show_help
    exit 1
  fi

  case "$device_type" in
    "beaglebone")
      stage_5_args="-i $menderimage -d $device_type -t ${toolchain} $keep"
      eval set -- " ${stage_5_args}"
      export -f create_device_maps
      export -f detach_device_maps
      ${tool_dir}/bbb-convert-stage-5.sh ${stage_5_args}
      ;;
    "raspberrypi3")
      stage_5_args="-i $menderimage -d $device_type -t ${toolchain} $keep"
      eval set -- " ${stage_5_args}"
      export -f create_device_maps
      export -f detach_device_maps
      export -f mount_sdimg
      ${tool_dir}/rpi3-convert-stage-5.sh ${stage_5_args}
      ;;
  esac
}

do_make_artifact() {
  if [ -z "${menderimage}" ]; then
    echo "Raw disk .sdimg image not set. Aborting."
    exit 1
  fi

  if [ -z "${device_type}" ]; then
    echo "Target device_type name not set. Aborting."
    exit 1
  fi

  if [ -z "${artifact}" ]; then
    echo "Artifact name not set. Aborting."
    exit 1
  fi

  if [ -z "${rootfs_type}" ]; then
    echo "Artifact name not set. rootfs_a will be used by default."
    rootfs_type="rootfs_a"
  fi

  inarray=$(echo ${rootfs_types[@]} | grep -o $rootfs_type | wc -w)

  [[ $inarray -eq 0 ]] && \
      { echo "Error: invalid rootfs type provided. Aborting."; exit 1; }

  local count=
  local bootstart=
  local rootfs_a_start=
  local rootfs_a_size=
  local rootfs_b_start=
  local rootfs_b_size=
  local rootfs_path=
  local sdimg_device_type=
  local abort=0

  get_sdimg_info $menderimage count sector_size rootfs_a_start rootfs_a_size \
          rootfs_b_start rootfs_b_size
  ret=$?
  [[ $ret -ne 0 ]] && \
      { echo "Error: cannot validate input .sdimg image. Aborting."; exit 1; }

  create_device_maps $menderimage sdimgmappings
  mount_sdimg ${sdimgmappings[@]}

  if [[ $rootfs_type == "rootfs_a" ]]; then
    prootfs_size=$rootfs_a_size
    rootfs_path=$sdimg_primary_dir
  elif [[ $rootfs_type == "rootfs_b" ]]; then
    prootfs_size=$rootfs_b_size
    rootfs_path=$sdimg_secondary_dir
  fi

  # Find .sdimg file's dedicated device type.
  sdimg_device_type=$( cat $sdimg_data_dir/mender/device_type | sed 's/[^=].*=//' | cut -d '"' -f 2 )

  # Set 'artifact name' as passed in the command line.
  sudo sed -i '/^artifact/s/=.*$/='${artifact}'/' "$rootfs_path/etc/mender/artifact_info"

  if [ "$sdimg_device_type" != "$device_type" ]; then
    echo "Error: .mender and .sdimg device type not matching. Aborting."
    abort=1
  fi

  if [[ $(which mender-artifact) = 1 ]]; then
    echo "Error: mender-artifact not found in PATH. Aborting."
    abort=1
  fi

  if [ $abort -eq 0 ]; then
    local rootfs_file=${output_dir}/rootfs.ext4

    echo "Creating a ext4 file-system image from modified root file-system"
    dd if=/dev/zero of=$rootfs_file seek=${prootfs_size} count=0 bs=512 status=none

    sudo mkfs.ext4 -FF $rootfs_file -d $rootfs_path

    fsck.ext4 -fp $rootfs_file

    mender_artifact=${output_dir}/${device_type}_${artifact}.mender
    echo "Writing Mender artifact to: ${mender_artifact}"

    #Create Mender artifact
    mender-artifact write rootfs-image \
      --update ${rootfs_file} \
      --output-path ${mender_artifact} \
      --artifact-name ${artifact} \
      --device-type ${device_type}

    ret=$?
    [[ $ret -eq 0 ]] && \
      { echo "Writing Mender artifact to ${mender_artifact} succeeded."; } || \
      { echo "Writing Mender artifact to ${mender_artifact} failed."; }

    rm $rootfs_file
  fi

  # Clean and detach.
  detach_device_maps ${sdimgmappings[@]}

  rm -rf $sdimg_base_dir
}

do_make_all() {
  do_make_sdimg
  do_install_mender
  do_install_bootloader
}

#read -s -p "Enter password for sudo: " sudoPW
#echo ""

PARAMS=""

# Load necessary functions.
source ${tool_dir}/mender-convert-functions.sh

while (( "$#" )); do
  case "$1" in
    -r | --rootfs-type)
      rootfs_type=$2
      shift 2
      ;;
    -i | --image)
      menderimage=$2
      shift 2
      ;;
    -e | --embedded)
      embeddedimage=$(get_path $2)
      shift 2
      ;;
    -s | --size-data)
      data_size=$2
      shift 2
      ;;
    -d | --device-type)
      device_type=$2
      shift 2
      ;;
    -a | --artifact)
      artifact=$2
      shift 2
      ;;
    -m | --mender)
      mender=$(get_path $2)
      shift 2
      ;;
    -t | --toolchain)
      toolchain=$2
      shift 2
      ;;
    -p | --demo-ip)
      demo_ip=$2
      shift 2
      ;;
    -c | --certificate)
      certificate=$2
      shift 2
      ;;
    -u | --production-url)
      production_url=$2
      shift 2
      ;;
    -o | --hosted-token)
      hosted_token=$2
      shift 2
      ;;
    -k | --keep)
      keep="-k"
      shift 1
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unsupported option $1" >&2
      exit 1
      ;;
    *)
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

[ -z "${data_size}" ] && \
    { echo "Default 'data' partition size set to 128MiB"; data_size=128; }

eval set -- "$PARAMS"

# Some commands expect elevated privileges.
sudo true

case "$1" in
  prepare_image)
    do_prepare_image
    ;;
  make_sdimg)
    do_make_sdimg
    ;;
  install_mender)
    do_install_mender
    ;;
  install_bootloader)
    do_install_bootloader
    ;;
  make_artifact)
    do_make_artifact
    ;;
  make_all)
    do_make_all
    ;;
  *)
    show_help
    ;;
esac

