#!/usr/bin/env bash
# Copyright 2024 Northern.tech AS
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

# Takes a directory to set up for chroot and a name of a function to run. Note that this function
# does not run *inside* the chroot, it just runs with chroot set up. To actually run commands, use
# one of the `run_in_chroot` functions individually for each command.
function run_with_chroot_setup() {
    local directory="$1"
    shift
    # The rest of the arguments are the command arguments.

    # Keep a copy of the resolv.conf, and copy in our own, we will need it during chroot
    # execution. We need to check for link specifically, because we want to treat a broken symlink
    # (which it often will be) as existing, but the normal check treats it as non-existing.
    if [ -e "$directory/etc/resolv.conf" -o -h "$directory/etc/resolv.conf" ]; then
        mv "$directory/etc/resolv.conf" "$directory/etc/resolv.conf.orig"
    fi
    cp /etc/resolv.conf "$directory/etc/resolv.conf"

    local ret=0
    (   
        # Mender-convert usually runs in a container. It's difficult to launch additional containers
        # from within an existing one, but we need to run some commands on a simulated device using
        # some sort of container. Use good old `chroot`, which doesn't provide perfect containment,
        # but it is good enough for our purposes, and doesn't require special containment
        # capabilities. This will not work for foreign architectures, but we could probably use
        # something like qemu-aarch64-static to get around that.
        run_and_log_cmd "sudo mount work/boot $directory/boot/efi -o bind"
        run_and_log_cmd "sudo mount /dev $directory/dev -o bind,ro"
        run_and_log_cmd "sudo mount /proc $directory/proc -o bind,ro"
        run_and_log_cmd "sudo mount /sys $directory/sys -o bind,ro"

        # Run command.
        "$@"
    ) || ret=$?

    # Very important that these are unmounted, otherwise Docker may start to remove files inside
    # them while tearing down the container. You can guess how I found that out... We run without
    # the logger because otherwise the message from the previous command, which is the important
    # one, is lost.
    sudo umount -l $directory/boot/efi || true
    sudo umount -l $directory/dev || true
    sudo umount -l $directory/proc || true
    sudo umount -l $directory/sys || true

    rm -f "$directory/etc/resolv.conf"
    if [ -e "$directory/etc/resolv.conf.orig" -o -h "$directory/etc/resolv.conf.orig" ]; then
        mv "$directory/etc/resolv.conf.orig" "$directory/etc/resolv.conf"
    fi

    return $ret
}

function run_in_chroot_and_log_cmd() {
    local directory="$1"
    shift
    # The rest of the arguments are the command arguments.

    run_and_log_cmd "sudo chroot $directory $@"
}

function run_in_chroot_and_log_cmd_noexit() {
    local directory="$1"
    shift
    # The rest of the arguments are the command arguments.

    local ret=0
    run_and_log_cmd_noexit "sudo chroot $directory $@" || ret=$?
    return $ret
}
