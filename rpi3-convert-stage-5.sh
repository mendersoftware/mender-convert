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
files_dir=${application_dir}/files
output_dir=${application_dir}/output
uboot_dir=${output_dir}/uboot-mender
bin_base_dir=${output_dir}/bin
bin_dir_pi=${bin_base_dir}/raspberrypi
sdimg_base_dir=$output_dir/sdimg
GCC_VERSION="6.3.1"
build_log=${output_dir}/build.log

declare -a mender_disk_mappings
declare -a mender_disk_partitions=("boot" "primary" "secondary" "data")

version() {
  echo "$@" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }'
}

# Takes following arguments:
#
#  $1 - ARM toolchain
build_uboot_files() {
  local CROSS_COMPILE=${1}-
  local ARCH=arm
  local branch="mender-rpi-2017.09"
  local commit="988e0ec54"
  local uboot_repo_vc_dir=$uboot_dir/.git

  export CROSS_COMPILE=$CROSS_COMPILE
  export ARCH=$ARCH

  mkdir -p $bin_dir_pi

  log "\tBuilding U-Boot related files."

  if [ ! -d $uboot_repo_vc_dir ]; then
    git clone https://github.com/mendersoftware/uboot-mender.git -b $branch >> "$build_log" 2>&1
  fi

  cd $uboot_dir

  git checkout $commit >> "$build_log" 2>&1

  make --quiet distclean >> "$build_log"
  make --quiet rpi_3_32b_defconfig >> "$build_log" 2>&1
  make --quiet >> "$build_log" 2>&1
  make --quiet envtools >> "$build_log" 2>&1

  cat<<-'EOF' >boot.cmd
	fdt addr ${fdt_addr} && fdt get value bootargs /chosen bootargs
	run mender_setup
	mmc dev ${mender_uboot_dev}
	load ${mender_uboot_root} ${kernel_addr_r} /boot/zImage
	bootz ${kernel_addr_r} - ${fdt_addr}
	run mender_try_to_recover
	EOF

  if [ ! -e $uboot_dir/tools/mkimage ]; then
    log "Error: cannot build U-Boot. Aborting"
    return 1
  fi

  $uboot_dir/tools/mkimage -A arm -T script -C none -n "Boot script" -d "boot.cmd" boot.scr >> "$build_log" 2>&1
  cp -t $bin_dir_pi $uboot_dir/boot.scr $uboot_dir/tools/env/fw_printenv $uboot_dir/u-boot.bin

  return 0
}

# Takes following arguments:
#
#  $1 - boot partition mountpoint
#  $2 - primary partition mountpoint
install_files() {
  local boot_dir=$1
  local rootfs_dir=$2

  log "\tInstalling U-Boot related files."

  # Make a copy of Linux kernel arguments and modify.
  sudo cp ${boot_dir}/cmdline.txt ${output_dir}/cmdline.txt

  sed -i 's/\b[ ]root=[^ ]*/ root=\${mender_kernel_root}/' ${output_dir}/cmdline.txt

  # If the the image that we are trying to convert has been booted once on a
  # device, it will have removed the init_resize.sh init argument from cmdline.
  #
  # But we want it to run on our image as well to resize our data part so in
  # case it is missing, add it back to cmdline.txt
  if ! grep -q "init=/usr/lib/raspi-config/init_resize.sh" ${output_dir}/cmdline.txt; then
    cmdline=$(cat ${output_dir}/cmdline.txt)
    sh -c -e "echo '${cmdline} init=/usr/lib/raspi-config/init_resize.sh' > ${output_dir}/cmdline.txt";
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
  sudo install -m 755 ${files_dir}/init_resize.sh \
      ${rootfs_dir}/usr/lib/raspi-config/init_resize.sh
}

do_install_bootloader() {
  if [ -z "${mender_disk_image}" ]; then
    log "Mender raw disk image file not set. Aborting."
    exit 1
  fi

  if [ -z "${bootloader_toolchain}" ]; then
    log "ARM GCC toolchain not set. Aborting."
    exit 1
  fi

  if ! [ -x "$(command -v ${bootloader_toolchain}-gcc)" ]; then
    log "Error: ARM GCC not found in PATH. Aborting."
    exit 1
  fi

  local gcc_version=$(${bootloader_toolchain}-gcc -dumpversion)

  if [ $(version $gcc_version) -ne $(version $GCC_VERSION) ]; then
    log "Error: Invalid ARM GCC version ($gcc_version). Expected $GCC_VERSION. Aborting."
    exit 1
  fi

  [ ! -f $mender_disk_image ] && \
      { log "$mender_disk_image - file not found. Aborting."; exit 1; }

  # Map & mount Mender compliant image.
  create_device_maps $mender_disk_image mender_disk_mappings

  # Change current directory to 'output' directory.
  cd $output_dir

  # Build patched U-Boot files.
  build_uboot_files $bootloader_toolchain
  rc=$?
  cd $output_dir

  if [ $rc -eq 0 ]; then
    mount_mender_disk ${mender_disk_mappings[@]}
    install_files ${output_dir}/sdimg/boot ${output_dir}/sdimg/primary
  fi

  detach_device_maps ${mender_disk_mappings[@]}
  rm -rf $sdimg_base_dir

  [[ $keep -eq 0 ]] && { rm -f ${output_dir}/config.txt ${output_dir}/cmdline.txt;
     rm -rf $uboot_dir $bin_base_dir; }

  [[ "$rc" -ne 0 ]] && { exit 1; } || { log "\tDone."; }
}

# Conditional once we support other boards
PARAMS=""

while (( "$#" )); do
  case "$1" in
    -m | --mender-disk-image)
      mender_disk_image=$2
      shift 2
      ;;
    -b | --bootloader-toolchain)
      bootloader_toolchain=$2
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
      log "Error: unsupported option $1"
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
