#!/bin/sh

set -e

MENDER_CLIENT_VERSION="1.6.0"  # TODO: Default, support input as env variable


echo "Cross-compiling Mender client $MENDER_CLIENT_VERSION"
# NOTE: we are assuming generic ARM board here, needs to be extended later

export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin

go get github.com/mendersoftware/mender
cd $GOPATH/src/github.com/mendersoftware/mender
git checkout $MENDER_CLIENT_VERSION

env CGO_ENABLED=1 \
    CC=arm-linux-gnueabihf-gcc \
    GOOS=linux \
    GOARCH=arm make build

cp $GOPATH/src/github.com/mendersoftware/mender/mender /


# run conversion, args provided to container (end of docker run ...)

cd /mender-convert

echo "Running mender-convert "$@""

./mender-convert "$@"
