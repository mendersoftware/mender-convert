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
        if [ -L work/rootfs/${location} ]; then
            location=$(readlink work/rootfs/${location})
        fi
        if [ -e work/rootfs/${location} ]; then
            file_info=$(file -b --dereference work/rootfs/${location})
            break
        fi
    done

    if [ -z "${file_info}" ]; then
        log_fatal "Sorry, not able to determine target architecture"
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
            ;;
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
            ;;
    esac
    echo "${deb_arch}"
}

# Prints Debian distro name based on ID from /etc/os-release
#
# Special handling for raspbian, where ID_LIKE is used instead
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_debian_distro_name() {
    distro_name="$(. work/rootfs/etc/os-release && echo "$ID")"
    if [[ "$distro_name" == "raspbian" ]]; then
        distro_name="$(. work/rootfs/etc/os-release && echo "$ID_LIKE")"
    fi
    echo "${distro_name}"
}

# Prints Debian distro codename based on VERSION_CODENAME from /etc/os-release
#
# No input parameters and these work on the assumption that boot and root parts
# are mounted at work/boot and work/rootfs
probe_debian_distro_codename() {
    distro_codename="$(. work/rootfs/etc/os-release && echo "$VERSION_CODENAME")"
    echo "${distro_codename}"
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
            ;;
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
        #Search for kernels, resolve symlinks, ignore invalid and select the latest if many
        kernels=$(sudo find ${1} -name ${image}* ! -name '*-rescue-*' ! -name '*.old' \
              -exec readlink -f {} \; | awk -F '/' '{print $NF,$0}' | sort -k1rV | uniq)
        kernel_image_path=$(head -n 1 <<< "$kernels" | cut -f2- -d' ')
        n=$(wc -l <<< "$kernels")

        if [ "$n" -gt "1" ]; then
            msg=$(awk '{printf "    %s\n", $2}' <<< ${kernels})
            log_warn "Found multiple kernel images: \n\n${msg}\n"
            log_warn "Selecting newest kernel image: \n\n    ${kernel_image_path}\n"
            log_warn "Set MENDER_GRUB_KERNEL_IMAGETYPE to override selected kernel"
        fi

        #kernel_image_path=$(sudo find ${1} -name ${image}*  ! -name '*-rescue-*' | sort -rV | head -n 1 )
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
        #Search for initrd, resolve symlinks, ignore invalid and select the latest if many
        initrds=$(sudo find ${1} -name ${image}* ! -name '*-rescue-*' ! -name '*.old' \
              -exec readlink -f {} \; | awk -F '/' '{print $NF,$0}' | sort -k1rV | uniq)
        initrd_image_path=$(head -n 1 <<< "$initrds" | cut -f2- -d' ')
        n=$(wc -l <<< "$initrds")

        if [ "$n" -gt "1" ]; then
            msg=$(awk '{printf "    %s\n", $2}' <<< ${initrds})
            log_warn "Found multiple initrd images: \n\n${msg}\n"
            log_warn "Selecting newest initrd: \n\n    ${initrd_image_path}\n"
            log_warn "Set MENDER_GRUB_INITRD_IMAGETYPE to override selected initrd"
        fi

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
            break
        elif [ -n "${kernel_imagetype_path}" ]; then
            break
        fi
    done

    if [ -z "${kernel_imagetype_path}" ]; then
        log_warn "Unfortunately we where not able to find the Linux kernel image."
        log_fatal "Please specify the image name using MENDER_GRUB_KERNEL_IMAGETYPE"
    fi

    log_info "Found Linux kernel image: \n\n\t${kernel_imagetype_path}\n"
    kernel_imagetype=$(basename ${kernel_imagetype_path})

    if [ "${MENDER_GRUB_EFI_INTEGRATION}" == "y" ]; then
        check_efi_compatible_kernel ${kernel_imagetype_path}
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
            sudo cp ${initrd_image_path} work/rootfs/boot
            break
        elif [ -n "${initrd_image_path}" ]; then
            break
        fi
    done

    if [ -n "${initrd_image_path}" ]; then
        log_info "Found initramfs image: \n\n\t${initrd_image_path}\n"
        initrd_imagetype=$(basename ${initrd_image_path})
    else
        log_info "Unfortunately we where not able to find the initrd image."
        log_info "Please specify the image name using MENDER_GRUB_INITRD_IMAGETYPE \
(only required if your board is using this)"
        initrd_imagetype=""
    fi

    echo "${initrd_imagetype}"
}

check_for_broken_uboot_uefi_support() {
    if ! is_uboot_with_uefi_support "$@"; then
        local log_level=log_fatal
        if [ "$MENDER_IGNORE_UBOOT_BROKEN_UEFI" = 1 ]; then
            log_level=log_warn
        fi
        $log_level 'Detected a U-Boot version in the range v2018.09 - v2019.07. These U-Boot versions are known to have broken UEFI support, and therefore the MENDER_GRUB_EFI_INTEGRATION feature is unlikely to work. This only affects newly flashed devices using the partition image (extension ending in "img"). The Mender artifact should still work to upgrade an existing, working device. There are two possible workarounds for this issue: 1) Use either an older or a newer image that works, and use a Mender artifact afterwards to up/down-grade it to the version you want. 2) If the device has a non-UEFI U-Boot port in mender-convert, use that (look for a board specific file in `configs`) . If you want to ignore this error and force creation of the image, set the MENDER_IGNORE_UBOOT_BROKEN_UEFI=1 config option.'
    fi
}

is_uboot_with_uefi_support() {
    local path="$1"

    # Broken UEFI support in range v2018.09 - v2019.07 (see MEN-2404)
    local regex='U-Boot 20(18\.(09|1[0-2])|19\.0[1-7])'

    if egrep -qr "$regex" "$path"; then
        return 1
    fi
    return 0
}

check_efi_compatible_kernel() {
    if ! is_efi_compatible_kernel "$@"; then
        local log_level=log_fatal
        if [ "$MENDER_IGNORE_MISSING_EFI_STUB" = 1 ]; then
            log_level=log_warn
        fi
        $log_level 'Detected a kernel which does not have an EFI stub. This kernel is not supported when booting with UEFI. Please consider using a U-Boot port if the board has one (look for a board specific file in `configs`), or find a kernel which has the CONFIG_EFI_STUB turned on. To ignore this message and proceed anyway, set the MENDER_IGNORE_MISSING_EFI_STUB=1 config option.'
    fi
}

is_efi_compatible_kernel() {
    kernel_path="$1"

    case "$(probe_arch)" in
        arm | aarch64)
            # On ARM, as of version 2.04, GRUB can only boot kernels which have an EFI
            # stub in them. See MEN-2404.
            if ! file -k $kernel_path | fgrep -q 'EFI application'; then
                return 1
            fi
            ;;
        *)
            # Other platforms are fine.
            :
            ;;
    esac
    return 0
}
