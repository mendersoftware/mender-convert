#!/bin/sh

set -e

IMAGE_NAME=mender-convert

docker build . -t $IMAGE_NAME
