#!/usr/bin/env bash
#
# Copyright 2022 Northern.tech AS
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

# grub_create_grub_config
#
#
function grub_create_grub_config() {

    run_and_log_cmd "wget -Nq '${MENDER_GRUBENV_URL}' -P work/"
    run_and_log_cmd "tar xzvf work/${MENDER_GRUBENV_VERSION}.tar.gz -C work/"

    cat <<- EOF > work/grub-mender-grubenv-${MENDER_GRUBENV_VERSION}/mender_grubenv_defines
mender_rootfsa_part=${MENDER_ROOTFS_PART_A_NUMBER}
mender_rootfsb_part=${MENDER_ROOTFS_PART_B_NUMBER}
mender_grub_storage_device=${MENDER_GRUB_STORAGE_DEVICE}
kernel_imagetype=kernel
initrd_imagetype=initrd
EOF

    # For partuuid support grub.cfg expects dedicated variables to be added
    if [ "${MENDER_ENABLE_PARTUUID}" == "y" ]; then
        rootfsa_partuuid=$(disk_get_partuuid_from_device "${root_part_a_device}")
        rootfsb_partuuid=$(disk_get_partuuid_from_device "${root_part_b_device}")
        log_info "Using root partition A partuuid in grubenv: $rootfsa_partuuid"
        log_info "Using root partition B partuuid in grubenv: $rootfsb_partuuid"
        cat <<- EOF >> work/grub-mender-grubenv-${MENDER_GRUBENV_VERSION}/mender_grubenv_defines
mender_rootfsa_uuid=${rootfsa_partuuid}
mender_rootfsb_uuid=${rootfsb_partuuid}
EOF
    else
        cat <<- EOF >> work/grub-mender-grubenv-${MENDER_GRUBENV_VERSION}/mender_grubenv_defines
mender_kernel_root_base=${MENDER_STORAGE_DEVICE_BASE}
EOF
    fi
}

# grub_install_standalone_grub_config
#
#
function grub_install_standalone_grub_config() {
    if [ -n "${MENDER_GRUB_KERNEL_BOOT_ARGS}" ]; then
        cat <<- EOF > work/grub-mender-grubenv-${MENDER_GRUBENV_VERSION}/11_bootargs_grub.cfg
set bootargs="${MENDER_GRUB_KERNEL_BOOT_ARGS}"
EOF
    fi

    (   
        cd work/grub-mender-grubenv-${MENDER_GRUBENV_VERSION}
        run_and_log_cmd "make 2>&1"
        run_and_log_cmd "sudo make DESTDIR=$PWD/../ BOOT_DIR=boot install-standalone-boot-files"
        run_and_log_cmd "sudo make DESTDIR=$PWD/../rootfs install-tools"
    )

}

# grub_install_grub_d_config
#
#
function grub_install_grub_d_config() {
    if [ -n "${MENDER_GRUB_KERNEL_BOOT_ARGS}" ]; then
        log_warn "MENDER_GRUB_KERNEL_BOOT_ARGS is ignored when MENDER_GRUB_D_INTEGRATION is enabled. Set it in the GRUB configuration instead."
    fi

    # When using grub.d integration, /boot/efi must point to the boot partition,
    # and /boot/grub must point to grub-mender-grubenv on the boot partition.
    if [ ! -d work/rootfs/boot/efi ]; then
        run_and_log_cmd "sudo mkdir work/rootfs/boot/efi"
    fi
    run_and_log_cmd "sudo mkdir work/boot/grub-mender-grubenv"
    run_and_log_cmd "sudo mv work/rootfs/boot/grub/* work/boot/grub-mender-grubenv/"
    run_and_log_cmd "sudo rmdir work/rootfs/boot/grub"
    run_and_log_cmd "sudo ln -s efi/grub-mender-grubenv work/rootfs/boot/grub"

    (   
        cd work/grub-mender-grubenv-${MENDER_GRUBENV_VERSION}
        run_and_log_cmd "make 2>&1"
        run_and_log_cmd "sudo make DESTDIR=$PWD/../ BOOT_DIR=boot install-boot-env"
        run_and_log_cmd "sudo make DESTDIR=$PWD/../rootfs install-grub.d-boot-scripts"
        run_and_log_cmd "sudo make DESTDIR=$PWD/../rootfs install-tools"
        # We need this for running the scripts once.
        run_and_log_cmd "sudo make DESTDIR=$PWD/../rootfs install-offline-files"
    )

    # Mender-convert usually runs in a container. It's difficult to launch
    # additional containers from within an existing one, but we need to run
    # `update-grub` on a simulated device using some sort of container. Use good
    # old `chroot`, which doesn't provide perfect containment, but it is good
    # enough for our purposes, and doesn't require special containment
    # capabilities. This will not work for foreign architectures, but we could
    # probably use something like qemu-aarch64-static to get around that.
    run_and_log_cmd "sudo mount work/boot work/rootfs/boot/efi -o bind"
    run_and_log_cmd "sudo mount /dev work/rootfs/dev -o bind,ro"
    run_and_log_cmd "sudo mount /proc work/rootfs/proc -o bind,ro"
    run_and_log_cmd "sudo mount /sys work/rootfs/sys -o bind,ro"

    local ret=0

    # Use `--no-nvram`, since we cannot update firmware memory in an offline
    # build. Instead, use `--removable`, which creates entries that automate
    # booting if you put the image into a new device, which you almost certainly
    # will after using mender-convert.
    run_and_log_cmd_noexit "sudo chroot work/rootfs grub-install --removable --no-nvram" || ret=$?
    if [ $ret -eq 0 ]; then
        run_and_log_cmd_noexit "sudo chroot work/rootfs grub-install --no-nvram" || ret=$?
    fi

    if [ $ret -eq 0 ]; then
        run_and_log_cmd_noexit "sudo chroot work/rootfs update-grub" || ret=$?
    fi

    # Very important that these are unmounted, otherwise Docker may start to
    # remove files inside them while tearing down the container. You can guess
    # how I found that out... We run without the logger because otherwise the
    # message from the previous command, which is the important one, is lost.
    sudo umount -l work/rootfs/boot/efi || true
    sudo umount -l work/rootfs/dev || true
    sudo umount -l work/rootfs/proc || true
    sudo umount -l work/rootfs/sys || true

    [ $ret -ne 0 ] && exit $ret

    (   
        cd work/grub-mender-grubenv-${MENDER_GRUBENV_VERSION}
        # Should be removed after running.
        run_and_log_cmd "sudo make DESTDIR=$PWD/../rootfs uninstall-offline-files"
    )
}

# grub_install_grub_editenv_binary
#
# Install the editenv binary
function grub_install_grub_editenv_binary() {
    log_info "Installing the GRUB editenv binary"

    arch=$(probe_arch)

    run_and_log_cmd "wget -Nq ${MENDER_GRUB_BINARY_STORAGE_URL}/${arch}/grub-editenv -P work/"
    run_and_log_cmd "sudo install -m 751 work/grub-editenv work/rootfs/usr/bin/"

}

# grub_install_mender_grub
#
# Install mender-grub on the converted boot partition
function grub_install_mender_grub() {
    kernel_imagetype=${MENDER_GRUB_KERNEL_IMAGETYPE:-$(probe_kernel_in_boot_and_root)}
    initrd_imagetype=${MENDER_GRUB_INITRD_IMAGETYPE:-$(probe_initrd_in_boot_and_root)}

    run_and_log_cmd "sudo ln -s ${kernel_imagetype} work/rootfs/boot/kernel"
    if [ "${initrd_imagetype}" != "" ]; then
        run_and_log_cmd "sudo ln -s ${initrd_imagetype} work/rootfs/boot/initrd"
    fi

    # Remove conflicting boot files. These files do not necessarily effect the
    # functionality, but lets get rid of them to avoid confusion.
    #
    # There is no Mender integration for EFI boot or systemd-boot.
    sudo rm -rf work/boot/loader work/rootfs/boot/loader
    sudo rm -rf work/boot/EFI/Linux
    sudo rm -rf work/boot/EFI/systemd
    sudo rm -rf work/boot/NvVars
    for empty_dir in $(
                     cd work/boot && find . -maxdepth 1 -type d -empty -not -name .
    ); do
        sudo rmdir work/boot/$empty_dir
    done

    log_info "Installing GRUB..."

    log_info "Installing mender-grub-editenv"
    grub_install_grub_editenv_binary

    local -r arch=$(probe_arch)
    local -r efi_name=$(probe_grub_efi_name)
    local -r efi_target_name=$(probe_grub_efi_target_name)

    log_info "GRUB EFI: ${efi_target_name}"

    run_and_log_cmd "wget -Nq ${MENDER_GRUB_BINARY_STORAGE_URL}/${arch}/${efi_name} -P work/"
    run_and_log_cmd "sudo mkdir -p work/boot/EFI/BOOT"
    run_and_log_cmd "sudo cp work/${efi_name} -P work/boot/EFI/BOOT/${efi_target_name}"

    # Copy dtb directory to the boot partition for use by the bootloader.
    if [ -d work/rootfs/boot/dtbs ]; then
        # Look for the first directory that has dtb files. First check the base
        # folder, then any subfolders in versioned order.
        for candidate in work/rootfs/boot/dtbs $(find work/rootfs/boot/dtbs/ -maxdepth 1 -type d | sort -V -r); do
            if [ $(find $candidate -maxdepth 1 -name '*.dtb' | wc -l) -gt 0 ]; then
                run_and_log_cmd "sudo cp -r $candidate work/boot/dtb"
                break
            fi
        done
    fi
}
