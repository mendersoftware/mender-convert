# QA-1780 qemu-user 8.2 and later refuses brk() growth for arm64 guests
# which makes apt fail with ENOMEM. Take the static qemu-user binaries from
# Debian 12 (qemu 7.2, which grants brk) and copy them over the ones of the
# Ubuntu qemu-user-static package in the final image. The build fails if
# Debian 12 ever ships another qemu series.
FROM debian:12 AS qemu
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes --no-install-recommends \
    qemu-user-static && \
    version="$(qemu-aarch64-static --version | head -n 1)" && \
    case "$version" in \
      "qemu-aarch64 version 7.2."*) ;; \
      *) echo >&2 "ERROR: expected qemu 7.2 from Debian 12, got: $version (see QA-1780)"; exit 1 ;; \
    esac && \
    mkdir /out && \
    for f in /usr/bin/qemu-*-static; do cp -L "$f" /out/; done

FROM ubuntu:24.04
ARG TARGETARCH
ARG MENDER_ARTIFACT_VERSION
RUN if [ "$MENDER_ARTIFACT_VERSION" = "" ]; then echo "MENDER_ARTIFACT_VERSION must be set!" 1>&2; exit 1; fi

RUN apt-get update && env DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes \
    sudo \
# to extract binaries from .deb
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
# parallel gzip compression
    pigz \
# mkfs.vfat (required for boot partition)
    dosfstools \
# to download Mender binaries
    wget \
# to be able to connect to Mender repo servers
    ca-certificates \
# to compile mender-grub-env
    make \
# to get rid of 'sh: 1: udevadm: not found' errors triggered by parted
    udev \
# to create bmap index file (MENDER_USE_BMAP)
    bmap-tools \
# to regenerate the U-Boot boot.scr on platforms that need customization
    u-boot-tools \
# artifact compression
    zip  \
    unzip \
    xz-utils \
# manipulate binary and hex
    xxd \
# JSON power tool
    jq \
# GRUB command line tools, primarily grub-probe
    grub-common \
# to be able to run package installations on foreign architectures
    binfmt-support \
    qemu-user-static

COPY --from=qemu /out/ /usr/bin/

# allow us to keep original PATH variables when sudoing
RUN echo "Defaults        secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$PATH\"" > /etc/sudoers.d/secure_path_override
RUN chmod 0440 /etc/sudoers.d/secure_path_override

RUN deb_filename=mender-artifact_${MENDER_ARTIFACT_VERSION}-1%2Bubuntu%2Bnoble_${TARGETARCH}.deb && \
    wget "https://downloads.mender.io/repos/workstation-tools/pool/main/m/mender-artifact/${deb_filename}" \
    --output-document=/mender-artifact.deb && apt -y --fix-broken install /mender-artifact.deb && rm /mender-artifact.deb

WORKDIR /

COPY . /mender-convert

RUN mkdir -p /mender-convert/work
RUN mkdir -p /mender-convert/input
RUN mkdir -p /mender-convert/deploy
RUN mkdir -p /mender-convert/logs

# It was discovered by accident that the Gitlab CI tends to give the clones full write permissions
# for everyone. But instead of fixing it in the CI build file, let's just fix it everywhere.
RUN chmod -R go-w /mender-convert

VOLUME ["/mender-convert/configs"]
VOLUME ["/mender-convert/input"]
VOLUME ["/mender-convert/deploy"]
VOLUME ["/mender-convert/logs"]
VOLUME ["/mender-convert/work"]

ENTRYPOINT ["/mender-convert/docker-entrypoint.sh"]
