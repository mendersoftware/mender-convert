#!/bin/bash

#    Copyright 2018 Northern.tech AS
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

application_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
output_dir=${application_dir}/output
bin_dir_pi=${output_dir}/bin/raspberrypi
sdimg_base_dir=$output_dir/sdimg

echo "Running: $(basename $0)"
declare -a sdimgmappings
declare -a sdimg_partitions=("boot" "primary" "secondary" "data")

build_uboot_files() {
  mkdir -p $bin_dir_pi

  echo -e "Downloading U-Boot related files..."

  wget -q -O $bin_dir_pi/boot.scr \
    https://github.com/mirzak/mender-conversion-tools/raw/mirza/wip/bin/raspberrypi/boot.scr
  wget -q -O $bin_dir_pi/fw_printenv \
    https://github.com/mirzak/mender-conversion-tools/raw/mirza/wip/bin/raspberrypi/fw_printenv
  wget -q -O $bin_dir_pi/init_resize.sh \
    https://raw.githubusercontent.com/mirzak/mender-conversion-tools/mirza/wip/bin/raspberrypi/init_resize.sh
  wget -q -O $bin_dir_pi/u-boot.bin \
    https://github.com/mirzak/mender-conversion-tools/raw/mirza/wip/bin/raspberrypi/u-boot.bin
}

# Takes following arguments:
#
#  $1 - boot partition mountpoint
#  $2 - primary partition mountpoint
install_files() {
  local boot_dir=$1
  local rootfs_dir=$2

  # Make a copy of Linux kernel arguments and modify.
  cp ${boot_dir}/cmdline.txt ${output_dir}/cmdline.txt

  sed -i 's/\b[ ]root=[^ ]*/ root=\${mender_kernel_root}/' ${output_dir}/cmdline.txt

  # If the the image that we are trying to convert has been booted once on a
  # device, it will have removed the init_resize.sh init argument from cmdline.
  #
  # But we want it to run on our image as well to resize our data part so in
  # case it is missing, add it back to cmdline.txt
  if ! grep "init=/usr/lib/raspi-config/init_resize.sh" ${output_dir}/cmdline.txt; then
    cmdline=$(cat ${output_dir}/cmdline.txt)
    echo "${cmdline} init=/usr/lib/raspi-config/init_resize.sh" > ${output_dir}/cmdline.txt
  fi

  # Update Linux kernel command arguments with our custom configuration
  sudo cp ${output_dir}/cmdline.txt ${boot_dir}

  # Mask udisks2.service, otherwise it will mount the inactive part and we
  # might write an update while it is mounted which often result in
  # corruptions.
  #
  # TODO: Find a way to only blacklist mmcblk0pX devices instea of masking
  # the service.
  sudo ln -sf /dev/null ${rootfs_dir}/etc/systemd/system/udisks2.service

  # Extract Linux kernel and install to /boot directory on rootfs
  sudo cp ${boot_dir}/kernel7.img ${rootfs_dir}/boot/zImage

  # Replace kernel with U-boot and add boot script
  sudo mkdir -p ${rootfs_dir}/uboot

  sudo cp ${bin_dir_pi}/u-boot.bin ${boot_dir}/kernel7.img
  sudo cp ${bin_dir_pi}/boot.scr ${boot_dir}
  sudo cp ${bin_dir_pi}/init_resize.sh  ${rootfs_dir}/usr/lib/raspi-config/init-resize.sh

  sudo cp ${boot_dir}/config.txt ${output_dir}/config.txt

  # dtoverlays seems to break U-boot for some reason, simply remove all of
  # them as they do not actually work when U-boot is used.
  sed -i /^dtoverlay=/d ${output_dir}/config.txt

  sudo cp ${output_dir}/config.txt ${boot_dir}/config.txt

  # Raspberry Pi configuration files, applications expect to find this on
  # the device and in some cases parse the options to determinate
  # functionality.
  sudo ln -fs /uboot/config.txt ${rootfs_dir}/boot/config.txt

  sudo install -m 755 ${bin_dir_pi}/fw_printenv ${rootfs_dir}/sbin/fw_printenv
  sudo ln -fs /sbin/fw_printenv ${rootfs_dir}/sbin/fw_setenv

  # Override init script to expand the data part instead of rootfs, which it
  # normally expands in standard Raspberry Pi distributions.
  sudo install -m 755 ${bin_dir_pi}/init_resize.sh \
      ${rootfs_dir}/usr/lib/raspi-config/init_resize.sh
}

do_install_bootloader() {
  echo "Setting bootloader..."

  if [ -z "${image}" ]; then
    echo ".sdimg image file not set. Aborting."
    exit 1
  fi

  [ ! -f $image ] && { echo "$image - file not found. Aborting."; exit 1; }

  # Map & mount Mender compliant image.
  create_device_maps $image sdimgmappings

  mkdir -p $output_dir && cd $output_dir

  # Build patched U-Boot files.
  build_uboot_files

  mount_sdimg ${sdimgmappings[@]}

  install_files ${output_dir}/sdimg/boot ${output_dir}/sdimg/primary

  detach_device_maps ${sdimgmappings[@]}

  echo -e "\nStage done."
}

# Conditional once we support other boards
PARAMS=""

while (( "$#" )); do
  case "$1" in
    -i | --image)
      image=$2
      shift 2
      ;;
    -t | --toolchain)
      toolchain=$2
      shift 2
      ;;
    -d | --device-type)
      device_type=$2
      shift 2
      ;;
    -k | --keep)
      keep=1
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

eval set -- "$PARAMS"

# Some commands expect elevated privileges.
sudo true

do_install_bootloader
