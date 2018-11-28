FROM ubuntu:18.04

ARG MENDER_ARTIFACT_VERSION=2.3.0
ARG MENDER_CONVERT_VERSION=1.0.0
ARG GOLANG_VERSION=1.11.2

RUN apt-get update && apt-get install -y \
    kpartx \
    bison \
    flex \
    mtools \
    parted \
    mtd-utils \
    e2fsprogs \
    u-boot-tools \
    pigz \
    device-tree-compiler \
    autoconf \
    autotools-dev \
    libtool \
    pkg-config \
    python \
# for mender-convert to run (mkfs.vfat is required for boot partition)
    sudo \
    dosfstools \
# to compile U-Boot
    bc \
# to download gcc toolchain and mender-artifact
    wget \
# to extract gcc toolchain
    xz-utils \
# to download mender-convert and U-Boot sources
    git

# Disable sanity checks made by mtools. These checks reject copy/paste operations on converted disk images.
RUN echo "mtools_skip_check=1" >> $HOME/.mtoolsrc

# Needed while we use older U-Boot version for Raspberry Pi
# https://tracker.mender.io/browse/MEN-2198
# Assumes $(pwd) is /
RUN wget -nc -q http://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz \
    && tar -xJf gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz \
    && rm gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz \
    && echo export PATH=$PATH:/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin >> /root/.bashrc


RUN wget -q -O /usr/bin/mender-artifact https://d1b0l86ne08fsf.cloudfront.net/mender-artifact/$MENDER_ARTIFACT_VERSION/mender-artifact \
    && chmod +x /usr/bin/mender-artifact

# Golang environment, for cross-compiling the Mender client
RUN wget https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go$GOLANG_VERSION.linux-amd64.tar.gz \
    && echo export PATH=$PATH:/usr/local/go/bin >> /root/.bashrc

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
