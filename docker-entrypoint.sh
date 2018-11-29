#!/bin/sh

set -e

# run conversion, args provided to container (end of docker run ...)

cd /mender-convert

echo "Running mender-convert "$@""

./mender-convert "$@"
