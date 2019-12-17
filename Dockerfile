# Build pxz in separate image to avoid big image size
FROM ubuntu:19.04 AS build
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    liblzma-dev

# Parallel xz (LZMA) compression
RUN git clone https://github.com/jnovy/pxz.git /root/pxz
RUN cd /root/pxz && make

FROM ubuntu:19.04

ARG MENDER_ARTIFACT_VERSION=3.2.1

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
    bmap-tools \
# needed to run pxz
    libgomp1

COPY --from=build /root/pxz/pxz /usr/bin/pxz

# allow us to keep original PATH variables when sudoing
RUN echo "Defaults        secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$PATH\"" > /etc/sudoers.d/secure_path_override
RUN chmod 0440 /etc/sudoers.d/secure_path_override

# Turn off default filesystem feature which is supported in newer mke2fs tools,
# but not in Ubuntu 16.04. The result is that mender-artifact can not be used to
# modify the artifact. Once 16.04 goes out of support, this can probably be
# removed.
RUN sed -i -e 's/,metadata_csum//' /etc/mke2fs.conf

RUN wget -q -O /usr/bin/mender-artifact https://d1b0l86ne08fsf.cloudfront.net/mender-artifact/$MENDER_ARTIFACT_VERSION/linux/mender-artifact \
    && chmod +x /usr/bin/mender-artifact

WORKDIR /

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
