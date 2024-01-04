#!/bin/bash
# Copyright 2023 Northern.tech AS
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

set -e

usage() {
    cat 1>&2 <<EOF
Please run with either "debian" or "ubuntu" as argument.
EOF
}

if [ "$UID" -ne 0 ]; then
    echo "We'll need root for this..." 1>&2
    exec sudo "$0" "$@"
fi

DEBIAN_CODENAME="bullseye"
DEBIAN_IMAGE_ID="Debian-11"

UBUNTU_CODENAME="jammy"
UBUNTU_IMAGE_ID="Ubuntu-Jammy"

while [ -n "$1" ]; do
    case "$1" in
        "ubuntu")
            GENERATE_VARIANT=generate_ubuntu
            ;;
        "debian")
            GENERATE_VARIANT=generate_debian
            ;;
        *)
            usage
            exit 1
            ;;
    esac
    shift
done

if [ -z "$GENERATE_VARIANT" ]; then
    usage
    exit 1
fi

cleanup_losetup() {
    set +e
    for dev in ${LO_DEVICE}p*; do
        umount $dev
    done
    losetup -d $LO_DEVICE
    rmdir tmp-p1
    rmdir tmp-p2
}

generate_debian() {
    local -r image="${DEBIAN_IMAGE_ID}-x86-64.img"

    mkosi --distribution=debian \
          --release="$DEBIAN_CODENAME" \
          --output="$image" \
          --root-size=2G \
          --format=gpt_ext4 \
          --bootable \
          --checksum \
          --password password \
          --package openssh-server \
          --package dhcpcd5 \
          --package liblmdb0 \
          --package libarchive13 \
          --package libboost-log1.74.0 \
          --package grub-efi-amd64-signed \
          --package shim-signed \
          --package lsb-release \
          build

    post_process_image "$image"

    echo "Image successfully generated!" 1>&2
}

generate_ubuntu() {
    local -r image="${UBUNTU_IMAGE_ID}-x86-64.img"

    mkosi --distribution=ubuntu \
          --release="$UBUNTU_CODENAME"  \
          --output="$image" \
          --root-size=2G \
          --format=gpt_ext4 \
          --bootable \
          --checksum \
          --password password \
          --package openssh-server \
          --package dhcpcd5 \
          --package liblmdb0 \
          --package libarchive13 \
          --package libboost-log1.74.0 \
          --package grub-efi-amd64-signed \
          --package shim-signed \
          --package lsb-release \
          build

    post_process_image "$image"

    echo "Image successfully generated!" 1>&2
}

post_process_image() {
    local -r image="$1"

    mkdir -p tmp-p1
    mkdir -p tmp-p2

    LO_DEVICE=$(losetup --find --show --partscan "$image")
    trap cleanup_losetup EXIT
    mount ${LO_DEVICE}p1 tmp-p1
    mount ${LO_DEVICE}p2 tmp-p2

    pre_tweaks tmp-p1 tmp-p2

    create_grub_regeneration_service tmp-p1 tmp-p2
    umount tmp-p1
    umount tmp-p2
    regenerate_grub_live "$image"
    mount ${LO_DEVICE}p1 tmp-p1
    mount ${LO_DEVICE}p2 tmp-p2
}

pre_tweaks() {
    local -r boot="$1"
    local -r root="$2"

    # Fstab is missing for some reason. I'm not exactly sure why systemd-boot
    # works without this, and GRUB doesn't.
    cat > "$root/etc/fstab" <<EOF
/dev/root / auto defaults 0 0
/dev/sda1 /boot/efi auto defaults 0 0
EOF

    # Real installers create a /etc/default/grub file with a distributor in
    # them.
    if [ ! -e "$root/etc/default/grub" ]; then
        mkdir -p $root/etc/default
        echo 'GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null`' > $root/etc/default/grub
    fi

    sed -E -i -e 's/^#? *PermitRootLogin .*/PermitRootLogin yes/' $root/etc/ssh/sshd_config
}

# Unfortunately installing grub scripts is something which is not really
# possible when offline. This is something which is easier with systemd-boot, so
# longterm GRUB will probably follow, or systemd-boot will take over. Anyway,
# let's do it by using a systemd service to perform the job, and then shut down.
create_grub_regeneration_service() {
    local -r boot="$1"
    local -r root="$2"

    cat > "$root/etc/systemd/system/mender-regenerate-grub-and-shutdown.service" <<EOF
[Unit]
Description=Regenerate grub scripts, disable itself and then shut down.

[Service]
Type=oneshot
ExecStart=sh -c "grub-install && grub-install --removable && update-grub && systemctl disable mender-regenerate-grub-and-shutdown.service && poweroff"
EOF

    ln -sf "$root/etc/systemd/system/mender-regenerate-grub-and-shutdown.service" "$root/etc/systemd/system/multi-user.target.wants/"
}

regenerate_grub_live() {
    local -r image="$1"

    local -r nvvars=$(mktemp)
    dd if=/dev/zero of="$nvvars" bs=1M count=1

    local ret=0
    for maybe_kvm in -enable-kvm ""; do
        ret=0
        echo "Generating GRUB boot files live..." 1>&2
        qemu-system-x86_64 \
            $maybe_kvm \
            -drive file="$image",if=ide,format=raw \
            -drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
            -drive file="$nvvars",if=pflash,format=raw,unit=1 \
            -display vnc=:23 \
            -m 512 \
            || ret=$?
        [ $ret -eq 0 ] && break
    done

    return $ret
}

$GENERATE_VARIANT
