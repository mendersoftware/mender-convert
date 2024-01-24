# Build pxz in separate image to avoid big image size
FROM ubuntu:20.04 AS build
RUN apt-get update && env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    git \
    liblzma-dev

# Parallel xz (LZMA) compression
RUN git clone https://github.com/jnovy/pxz.git /root/pxz
RUN cd /root/pxz && make

FROM ubuntu:20.04

ARG MENDER_ARTIFACT_VERSION=master

RUN apt-get update && env DEBIAN_FRONTEND=noninteractive apt-get install -y \
# For 'ar' command to unpack .deb
    binutils \
    xz-utils \
    zstd \
# to be able to detect file system types of extracted images
    file \
# to copy files between rootfs directories
    rsync \
# to generate partition table and alter partitions
    parted \
    gdisk \
# mkfs.ext4 and family
    e2fsprogs \
# mkfs.xfs and family
    xfsprogs \
# mkfs.btrfs and family
    btrfs-progs \
# Parallel gzip compression
    pigz \
    sudo \
# mkfs.vfat (required for boot partition)
    dosfstools \
# to download Mender binaries
    wget \
# to compile mender-grub-env
    make \
# to get rid of 'sh: 1: udevadm: not found' errors triggered by parted
    udev \
# to create bmap index file (MENDER_USE_BMAP)
    bmap-tools \
# to regenerate the U-Boot boot.scr on platforms that need customization
    u-boot-tools \
# needed to run pxz
    libgomp1  \
# zip and unzip archive
    zip  \
    unzip \
# manipulate binary and hex
    xxd \
# JSON power tool
    jq \
# GRUB command line tools, primarily grub-probe
    grub-common \
# to be able to run package installations on foreign architectures
    qemu-user-static

COPY --from=build /root/pxz/pxz /usr/bin/pxz

# allow us to keep original PATH variables when sudoing
RUN echo "Defaults        secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$PATH\"" > /etc/sudoers.d/secure_path_override
RUN chmod 0440 /etc/sudoers.d/secure_path_override

RUN wget -q -O /usr/bin/mender-artifact https://downloads.mender.io/mender-artifact/$MENDER_ARTIFACT_VERSION/linux/mender-artifact \
    && chmod +x /usr/bin/mender-artifact

WORKDIR /

COPY . /mender-convert

RUN mkdir -p /mender-convert/work
RUN mkdir -p /mender-convert/input
RUN mkdir -p /mender-convert/deploy
RUN mkdir -p /mender-convert/logs

VOLUME ["/mender-convert/configs"]
VOLUME ["/mender-convert/input"]
VOLUME ["/mender-convert/deploy"]
VOLUME ["/mender-convert/logs"]
VOLUME ["/mender-convert/work"]

ENTRYPOINT ["/mender-convert/docker-entrypoint.sh"]
