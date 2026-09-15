This directory contains set of configuration files for mkosi.
It allows to build test images for mender-convert conversion testing.

Development platform where image has been created was Ubuntu 26.04
with mkosi version 26. This is important as mkosi is changing frequently
and it is well known to not be backward compatible with its options
and produced images.

To create image enter the directory containing mkosi.conf and execute:
```
mkosi build
```

Images can be run with a helper qemu wrapper:
```
./run-vm.sh debian-12/out/debian-12-x86-64.img
```

To test image conversion copy it to input/images in main directory and call
(example for ubuntu, which uses configs/ubuntu-qemux86-64_config):
```
MENDER_ARTIFACT_NAME=release-1 ./docker-mender-convert --disk-image input/image/ubuntu-26.04-x86-64.img --config configs/ubuntu-qemux86-64_config --overlay input/rootfs_overlay_demo
```

If everything is fine:
* gzip the img file
* push it to S3 (https://downloads.mender.io/mender-convert/images/*)
* update link to image in scripts/test/run-tests.sh
* pray it will work out of the box

Notes:
* old images which were working fine had an empty /etc/fstab (placeholder)
* mkosi mixes predefined system configs with user confis so value which is
  a default today may be an option tomorrow...
* mkosi cat-config should show final merged configuration
* a lot of default config is happening in the Include=mkosi-vm, without it
  user may need to do things like manual systemd config
* mender-convert internaly uses binaries like `file` etc. If they are missing
  first try to add them to mkosi.conf before creating workaround
* if you are reading this, well, good luck!


Bellow a legacy mkosi calls which were starting points for the config files.

```
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
          --root-size=2300M \
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
```
