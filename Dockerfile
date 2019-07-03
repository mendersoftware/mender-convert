FROM ubuntu:19.04

ARG MENDER_ARTIFACT_VERSION=3.1.0

RUN apt-get update && apt-get install -y \
# For 'ar' command to unpack .deb
    binutils \
    xz-utils \
# to be able to detect file system types of extracted images
    file \
# to copy files between rootfs directories
    rsync \
# to generate partition table
    parted \
# mkfs.ext4 and family
    e2fsprogs \
# mkfs.xfs and family
    xfsprogs \
# Parallel gzip compression
    pigz \
    sudo \
# mkfs.vfat (required for boot partition)
    dosfstools \
# to download mender-artifact
    wget \
# to download mender-grub-env
    git \
# to compile mender-grub-env
    make \
# to get rid of 'sh: 1: udevadm: not found' errors triggered by parted
    udev \
# to create bmap index file (MENDER_USE_BMAP)
    bmap-tools

RUN wget -q -O /usr/bin/mender-artifact https://d1b0l86ne08fsf.cloudfront.net/mender-artifact/$MENDER_ARTIFACT_VERSION/linux/mender-artifact \
    && chmod +x /usr/bin/mender-artifact

# allow us to keep original PATH variables when sudoing
RUN echo "Defaults        secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$PATH\"" > /etc/sudoers.d/secure_path_override
RUN chmod 0440 /etc/sudoers.d/secure_path_override

WORKDIR /

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
