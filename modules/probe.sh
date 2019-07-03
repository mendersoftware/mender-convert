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

# Prints target architecture
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_arch() {
    # --dereference, means to follow symlinks because 'ls' could be a symlink
    # to busybox
    file_info=""
    for location in bin/ls usr/bin/ls; do
      if [ -e work/rootfs/${location} ]; then
        file_info=$(file -b --dereference work/rootfs/${location})
        break
      fi
    done

    if [ -z "${file_info}" ]; then
        log_fatal "Sorry, where not able to determinate target architecture"
    fi

    target_arch="unknown"
    if grep -q x86-64 <<< "${file_info}"; then
        target_arch="x86-64"
    elif grep -Eq "ELF 32-bit.*ARM" <<< "${file_info}"; then
        target_arch="arm"
    elif grep -Eq "ELF 64-bit.*aarch64" <<< "${file_info}"; then
        target_arch="aarch64"
    else
        log_fatal "Unsupported architecture: ${file_info}"
    fi
    echo "${target_arch}"
}

# Prints GRUB EFI name depending on target architecture
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_grub_efi_name() {
  efi_name=""
  arch=$(probe_arch)
  case "${arch}" in
    "x86-64")
      efi_name="grub-efi-bootx64.efi"
      ;;
    "arm")
      efi_name="grub-efi-bootarm.efi"
      ;;
    "aarch64")
      efi_name="grub-efi-bootaa64.efi"
      ;;
    *)
    log_fatal "Unknown arch: ${arch}"
  esac
  echo "$efi_name"
}

# Prints Debian arch name depending on target architecture
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_debian_arch_name() {
  deb_arch=""
  arch=$(probe_arch)
  case "${arch}" in
    "x86-64")
      deb_arch="amd64"
      ;;
    "arm")
      deb_arch="armhf"
      ;;
    "aarch64")
      deb_arch="arm64"
      ;;
    *)
    log_fatal "Unknown arch: ${arch}"
  esac
  echo "${deb_arch}"
}

# Prints GRUB EFI target name depending on target architecture
#
# This is what the file name should be when put on target boot part.
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_grub_efi_target_name() {
  efi_target_name=""
  arch=$(probe_arch)
  case "$arch" in
    "x86-64")
      efi_target_name="bootx64.efi"
      ;;
    "arm")
      efi_target_name="bootarm.efi"
      ;;
    "aarch64")
      efi_target_name="bootaa64.efi"
      ;;
    *)
    log_fatal "Unknown arch: ${arch}"
  esac
  echo "$efi_target_name"
}

# Prints path to the Linux kernel image
#
#  $1 - directory in which the search is performed
#
probe_kernel_image() {
  kernel_image_path=""
  for image in vmlinuz zImage bzImage; do
    # Linux kernel image type and naming varies between different platforms.
    #
    # The wildcard at the end is important, because it is common to suffix the
    # Linux kernel version to the image type/name, e.g:
    #
    #    vmlinuz-4.14-x86_64
    #    vmlinuz-3.10.0-862.el7.x86_64
    #    vmlinuz-4.15.0-20-generic
    #
    kernel_image_path=$(sudo find ${1} -name ${image}* ! -name '*-rescue-*')
    if [ -n "${kernel_image_path}" ]; then
      break
    fi
  done
  echo "${kernel_image_path}"
}

# Prints path to the initrd/initramfs image
#
#  $1 - directory in which the search is performed
#
probe_initrd_image() {
  initrd_image_path=""
  for image in initramfs initrd; do
    # initrd/initramfs naming varies between different platforms.
    #
    # The wildcard at the end is important, because it is common to suffix the
    # Linux kernel version to the image name, e.g:
    #
    #    initrd.img-4.15.0-20-generic
    #
    initrd_image_path=$(sudo find ${1} -name ${image}* ! -name '*-rescue-*')
    if [ -n "${initrd_image_path}" ]; then
      break
    fi
  done
  echo "${initrd_image_path}"
}


# Prints Linux kernel image name
#
# It will look for it in both boot and rootfs parts. If image is only present
# in boot part, it will move it to rootfs/boot
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_kernel_in_boot_and_root() {
  kernel_imagetype_path=""

  # Important to check rootfs/boot first, because it might be possible that
  # they are stored in both partitions, and in this case we want to find the
  # image in the rootfs first and use that, to avoid copying it over from
  # boot part when it is already there.
  for boot in work/rootfs/boot work/boot; do
    kernel_imagetype_path=$(probe_kernel_image ${boot})
    if [ -n "${kernel_imagetype_path}" ] && [ "${boot}" == "work/boot" ]; then
      log_info "Found Linux kernel image in boot part, moving to rootfs/boot"
      sudo cp ${kernel_imagetype_path} work/rootfs/boot
      break;
    elif [ -n "${kernel_imagetype_path}" ]; then
      break;
    fi
  done

  if [ -n "${kernel_imagetype_path}" ]; then
    log_info "Found Linux kernel image: \n\n\t${kernel_imagetype_path}\n"
    kernel_imagetype=$(basename ${kernel_imagetype_path})
  else
    log_warn "Unfortunatly we where not able to find the Linux kernel image."
    log_fatal "Please specifc the image name using MENDER_GRUB_KERNEL_IMAGETYPE"
  fi
  echo "${kernel_imagetype}"
}

# Prints initrd/initramfs image name
#
# It will look for it in both boot and rootfs parts. If image is only present
# in boot part, it will move it to rootfs/boot
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_initrd_in_boot_and_root() {
  initrd_image_path=""

  # Important to check rootfs/boot first, because it might be possible that
  # they are stored in both partitions, and in this case we want to find the
  # image in the rootfs first and use that, to avoid copying it over from
  # boot part when it is already there.
  for boot in work/rootfs/boot work/boot; do
    initrd_image_path=$(probe_initrd_image ${boot})
    if [ -n "${initrd_image_path}" ] && [ "${boot}" == "work/boot" ]; then
      sudo cp ${initrd_image_path} ${target_rootfs_dir}/boot
      break;
    elif [ -n "${initrd_image_path}" ]; then
      break;
    fi
  done

  if [ -n "${initrd_image_path}" ]; then
    log_info "Found initramfs image: \n\n\t${initrd_image_path}\n"
    initrd_imagetype=$(basename ${initrd_image_path})
  else
    log_info "Unfortunatly we where not able to find the initrd image."
    log_info "Please specifc the image name using MENDER_GRUB_INITRD_IMAGETYPE \
(only required if your board is using this)"
    initrd_imagetype=""
  fi

  echo "${initrd_imagetype}"
}
