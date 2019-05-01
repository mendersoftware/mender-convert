#!/bin/sh
set -e

ROOTFS_OUTPUT_FILE_NAME=$1
ARTIFACT_NAME=$2
DEVICE_TYPE=$3

mkdir /root_system

mount /root_images/$ROOTFS_OUTPUT_FILE_NAME /root_system

if [ -f /root_system/usr/bin/qemu-arm-static ]; then
  echo "WARNING: /usr/bin/qemu-arm-static already exists in image. Using this but may be of incompatible version."
  QEMU_STATIC_COPIED=false
else
  # trick to make chroot into ARM image work
  cp /usr/bin/qemu-arm-static /root_system/usr/bin
  QEMU_STATIC_COPIED=true
fi

echo "Entering emulated shell in device image. All commands are run as the root user of the device image."
echo "Make changes (e.g. apt update, apt upgrade, wget ...) and press Ctrl-D when done."

# Using bash for command completion support and other conveniences
chroot /root_system /bin/bash

# Mender Artifact name must also be present inside
echo artifact_name=$ARTIFACT_NAME > /root_system/etc/mender/artifact_info

if [ "$QEMU_STATIC_COPIED" = true ]; then
  rm /root_system/usr/bin/qemu-arm-static
fi

umount /root_system

echo "Creating Mender Artifact. This may take 10-20 minutes (using LZMA)..."
mender-artifact --compression lzma write rootfs-image -t $DEVICE_TYPE -n $ARTIFACT_NAME -f /root_images/$ROOTFS_OUTPUT_FILE_NAME -o /root_images/$ARTIFACT_NAME.mender
sync
