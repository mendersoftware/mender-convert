#!/usr/bin/env bash
# Copyright 2025 Northern.tech AS
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

source modules/probe.sh

# Setup the chroot for running commands inside it.
# $1 - chroot directory
# Note: Must be followed up by chroot_teardown()!
function chroot_setup() {
    local -r directory="$1"

    # Keep a copy of the resolv.conf, and copy in our own, we will need it during chroot
    # execution. We need to check for link specifically, because we want to treat a broken symlink
    # (which it often will be) as existing, but the normal check treats it as non-existing.
    if [ -e "$directory/etc/resolv.conf" -o -h "$directory/etc/resolv.conf" ]; then
        mv "$directory/etc/resolv.conf" "$directory/etc/resolv.conf.orig"
    fi
    cp /etc/resolv.conf "$directory/etc/resolv.conf"

    # 'ls -1d' to avoid the expansion of * doing nothing (and keeping the * in
    # place)
    for cert_item in $(ls -1d "$directory/etc/ca-certificates"* "$directory/etc/ssl/certs" 2> /dev/null); do
        cp -a "$cert_item"{,.orig}
    done
    mkdir -p "$directory/etc/ssl"
    cp -a /etc/ssl/certs "$directory/etc/ssl/"
    cp -a /etc/ca-certificates* "$directory/etc/"

    local -r arch="$(probe_arch)"
    if [ "$arch" != "$(uname -m)" ]; then
        # Foreign architecture, we need to use QEMU.
        cp "$(which "qemu-$arch-static")" "$directory/tmp/"

        # A note about this next section, because there is high breakage potential here in later OS
        # versions. This enables binfmt integration, which means foreign binaries can be
        # run. Between Ubuntu 22 and 24, the framework for how this is set up changed. Previously
        # the "binfmt-support" package and its associated `update-binfmts` tool was used. In Ubuntu
        # 24, this was replaced with `systemd-binfmt`. However, the binfmt-support package is still
        # available. The problem with `systemd-binfmt` is that it requires the "binfmt_misc"
        # filesystem to be mounted on `/proc/sys/fs/binfmt_misc`. Normally this is provided by
        # systemd itself, but it is not running inside a container. The `update-binfmts` by itself
        # does not work anymore in Ubuntu 24, because the format of the binfmt config files has
        # changed, but it does mount/unmount the binfmt_misc filesystem when calling with
        # `--enable/--disable`, so we use that to be able to run systemd-binfmt after it. But this
        # might stop working if the "binfmt-support" package is later removed from the package
        # repos. Perhaps then the filesystem needs to be mounted manually.
        update-binfmts --enable
        if [ -x /usr/lib/systemd/systemd-binfmt ]; then
            /usr/lib/systemd/systemd-binfmt
        fi
    fi

    # Mender-convert usually runs in a container. It's difficult to launch additional containers
    # from within an existing one, but we need to run some commands on a simulated device using
    # some sort of container. Use good old `chroot`, which doesn't provide perfect containment,
    # but it is good enough for our purposes, and doesn't require special containment
    # capabilities. This will not work for foreign architectures, but we could probably use
    # something like qemu-aarch64-static to get around that.
    if [ "$MENDER_GRUB_EFI_INTEGRATION" = "y" -a -d "$directory/boot/efi" ]; then
        run_and_log_cmd "sudo mount work/boot $directory/boot/efi -o bind"
        # Could mount the boot partition somewhere else, but we don't have a standard way to
        # specify where it should be mounted when EFI integration is off, so let's not, for now.
    fi
    run_and_log_cmd "sudo mount /dev $directory/dev -o bind,ro"
    # Bind mounting does not work recursively, so we still need this mount.
    run_and_log_cmd "sudo mount /dev/pts $directory/dev/pts -o bind,ro"
    run_and_log_cmd "sudo mount /proc $directory/proc -o bind,ro"
    run_and_log_cmd "sudo mount /sys $directory/sys -o bind,ro"
}

# Teardown the chroot after setting it up and running all commands in it.
# $1 - chroot directory
function chroot_teardown() {
    local -r directory="$1"

    # Very important that these are unmounted, otherwise Docker may start to remove files inside
    # them while tearing down the container. You can guess how I found that out... We run without
    # the logger because otherwise the message from the previous command, which is the important
    # one, is lost.
    if [ "$MENDER_GRUB_EFI_INTEGRATION" = "y" -a -d "$directory/boot/efi" ]; then
        sudo umount -l $directory/boot/efi || true
    fi
    sudo umount -l $directory/dev/pts || true
    sudo umount -l $directory/dev || true
    sudo umount -l $directory/proc || true
    sudo umount -l $directory/sys || true

    local -r arch="$(probe_arch)"
    if [ "$arch" != "$(uname -m)" ]; then
        rm -f "$directory/tmp/qemu-$arch-static"
    fi

    rm -f "$directory/etc/resolv.conf"
    if [ -e "$directory/etc/resolv.conf.orig" -o -h "$directory/etc/resolv.conf.orig" ]; then
        mv "$directory/etc/resolv.conf.orig" "$directory/etc/resolv.conf"
    fi

    rm -rf "$directory/etc/ssl/certs"
    rm -rf "$directory/etc/ca-certificates"*
    for cert_item in $(ls -1d "$directory/etc/ssl/certs" "$directory/etc/ca-certificates"*.orig 2> /dev/null); do
        mv "$cert_item"{.orig,}
    done
}

# Takes a directory to set up for chroot and a name of a function to run. Note
# that this function does not run *inside* the chroot, it just runs with chroot
# set up. To actually run commands inside the chroot, use one of the
# `run_in_chroot` functions individually for each command.
# $1 - chroot directory; shift
# $@ - command to run (should use `run_in_chroot_*()` functions)
function run_with_chroot_setup() {
    local -r directory="$1"
    shift
    # The rest of the arguments are the command arguments.

    chroot_setup "$directory"
    # Run command.
    "$@"
    local ret=$?
    chroot_teardown "$directory"

    return $ret
}

function run_in_chroot_and_log_cmd() {
    local -r directory="$1"
    shift
    # The rest of the arguments are the command arguments.

    local -r arch="$(probe_arch)"
    local maybe_qemu=
    if [ "$arch" != "$(uname -m)" ]; then
        # Use env, because qemu does not look in PATH.
        maybe_qemu="/tmp/qemu-$arch-static /usr/bin/env"
    fi

    run_and_log_cmd "sudo chroot $directory $maybe_qemu $@"
}

function run_in_chroot_and_log_cmd_with_output() {
    local -r directory="$1"
    shift
    # The rest of the arguments are the command arguments.

    local -r arch="$(probe_arch)"
    local maybe_qemu=
    if [ "$arch" != "$(uname -m)" ]; then
        # Use env, because qemu does not look in PATH.
        maybe_qemu="/tmp/qemu-$arch-static /usr/bin/env"
    fi

    run_and_log_cmd_with_output "sudo chroot $directory $maybe_qemu $@"
}

function run_in_chroot_and_log_cmd_noexit() {
    local -r directory="$1"
    shift
    # The rest of the arguments are the command arguments.

    local -r arch="$(probe_arch)"
    local maybe_qemu=
    if [ "$arch" != "$(uname -m)" ]; then
        # Use env, because qemu does not look in PATH.
        maybe_qemu="/tmp/qemu-$arch-static /usr/bin/env"
    fi

    local ret=0
    run_and_log_cmd_noexit "sudo chroot $directory $maybe_qemu $@" || ret=$?
    return $ret
}
