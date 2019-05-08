FROM ubuntu:18.04

ARG MENDER_ARTIFACT_VERSION=3.0.0
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
    jq \
# for mender-convert to run (mkfs.vfat is required for boot partition)
    sudo \
    dosfstools \
# to compile U-Boot
    bc \
# to download mender-artifact
    wget \
# to download mender-convert and U-Boot sources
    git

# Disable sanity checks made by mtools. These checks reject copy/paste operations on converted disk images.
RUN echo "mtools_skip_check=1" >> $HOME/.mtoolsrc

# To provide support for Raspberry Pi Zero W a toolchain tuned for ARMv6 architecture must be used.
# https://tracker.mender.io/browse/MEN-2399
# Assumes $(pwd) is /
RUN wget -nc -q https://toolchains.bootlin.com/downloads/releases/toolchains/armv6-eabihf/tarballs/armv6-eabihf--glibc--stable-2018.11-1.tar.bz2 \
    && tar -xjf armv6-eabihf--glibc--stable-2018.11-1.tar.bz2 \
    && rm armv6-eabihf--glibc--stable-2018.11-1.tar.bz2 \
    && echo 'export PATH=$PATH:/armv6-eabihf--glibc--stable-2018.11-1/bin' >> /root/.bashrc

RUN wget -q -O /usr/bin/mender-artifact https://d1b0l86ne08fsf.cloudfront.net/mender-artifact/$MENDER_ARTIFACT_VERSION/mender-artifact \
    && chmod +x /usr/bin/mender-artifact

# Golang environment, for cross-compiling the Mender client
RUN wget https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go$GOLANG_VERSION.linux-amd64.tar.gz \
    && echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc

ENV PATH "$PATH:/usr/local/go/bin:/armv6-eabihf--glibc--stable-2018.11-1/bin"
ENV GOPATH "/root/go"

# Download Mender client
ARG mender_client_version
RUN test -n "$mender_client_version" || (echo "Argument 'mender_client_version' is mandatory." && exit 1)
ENV MENDER_CLIENT_VERSION=$mender_client_version

RUN go get -d github.com/mendersoftware/mender
WORKDIR $GOPATH/src/github.com/mendersoftware/mender
RUN git checkout $MENDER_CLIENT_VERSION

ENV CC "arm-buildroot-linux-gnueabihf-gcc"

# Build liblzma from source
RUN wget -q https://tukaani.org/xz/xz-5.2.4.tar.gz \
    && tar -C /root -xzf xz-5.2.4.tar.gz \
    && cd /root/xz-5.2.4 \
    && ./configure --host=arm-buildroot-linux-gnueabihf --prefix=/root/xz-5.2.4/install \
    && make \
    && make install

ENV LIBLZMA_INSTALL_PATH "/root/xz-5.2.4/install"

# NOTE: we are assuming generic ARM board here, needs to be extended later
RUN env CGO_ENABLED=1 \
    CGO_CFLAGS="-I${LIBLZMA_INSTALL_PATH}/include" \
    CGO_LDFLAGS="-L${LIBLZMA_INSTALL_PATH}/lib" \
    CC=$CC \
    GOOS=linux \
    GOARM=6 GOARCH=arm make build

# allow us to keep original PATH variables when sudoing
RUN echo "Defaults        secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$PATH\"" > /etc/sudoers.d/secure_path_override
RUN chmod 0440 /etc/sudoers.d/secure_path_override

WORKDIR /

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
