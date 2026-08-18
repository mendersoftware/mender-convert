## mender-convert test images creation

This directory contains set of configuration files for mkosi.
It allows to build test images for mender-convert conversion testing.

Development platform where image has been created was Ubuntu 26.04
with mkosi version 26. This is important as mkosi is changing frequently
and it is well known to not be backward compatible with its options
and produced images.

### mkosi image creation

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

Legacy mkosi image creation script can be find in `scripts/test/generate-image.sh`

### Manual image creation

Some time mkosi image creation may fail or created image will be incompatible
with the mender-convert "assumptions". This may happen during mkosi main version
bumps and it happened already in the past.

The alternative is a manual image creation. It has been done now for Debian
family images (Debian 12, Debian 13) as the mkosi based image has
issues with the grub update due to kernel placement in /boot/efi.

For manual image conversion:
1) Select the source image. For Debian the source was nocloud cloud images:
   https://cloud.debian.org/images/cloud/bookworm/20260806-2562/debian-12-nocloud-amd64-20260806-2562.raw
2) Make sure image is compatible with grub (we do not suport systemd-boot yet)
3) Boot the image using qemu. There are two scripts helping with that:
   * run-vm.sh (for EFI requiring images)
   * run-vm-no-ovmf.sh (for basic qemu support).
4) Install the same packages which mkosi.conf would install

[Debian 12]
grub-efi-amd64-signed \
shim-signed \
openssh-server \
dhcpcd5 \
liblmdb0 \
libarchive13 \
libboost-log1.74.0 \
lsb-release

[Debian 13]
grub-efi-amd64-signed \
shim-signed \
openssh-server \
dhcpcd5 \
liblmdb0 \
libarchive13 \
libboost-log1.83.0 \
lsb-release

5) Make sure root password is `password`
5) Make sure ssh server is running
6) Make sure ssh has root and password login enabled

```
sed -E -i \
's/^#? *PermitRootLogin .*/PermitRootLogin yes/' \
"/etc/ssh/sshd_config"

sed -E -i \
's/^#? *PasswordAuthentication .*/PasswordAuthentication yes/' \
"/etc/ssh/sshd_config"
```
7) Try to ssh to machine as root using qemu port forwarding (heler script
   exposes ssh on port 8822)
8) Shut down the machine
9) Rename disk image to *.img (or convert if needed)
10) gzip the disk image to final form NAME.tar.gz
11) Upload to S3
12) Update download link in the scripts/test/run-tests.sh

