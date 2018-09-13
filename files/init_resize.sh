#!/bin/sh

reboot_pi () {
  umount /uboot
  sync
  echo b > /proc/sysrq-trigger
  sleep 5
  exit 0
}

check_commands () {
  if ! command -v whiptail > /dev/null; then
      FAIL_REASON="whiptail not found"
      sleep 5
      return 1
  fi
  for COMMAND in grep cut sed parted fdisk; do
    if ! command -v $COMMAND > /dev/null; then
      FAIL_REASON="$COMMAND not found"
      return 1
    fi
  done
  return 0
}

get_variables () {
  # /sys/block/mmcblk0/mmcblk0p4/
  ROOT_PART_NAME="mmcblk0p4"
  ROOT_DEV_NAME="mmcblk0"
  ROOT_DEV="/dev/${ROOT_DEV_NAME}"
  ROOT_PART_NUM=`cat /sys/block/${ROOT_DEV_NAME}/${ROOT_PART_NAME}/partition`

  BOOT_PART_DEV=`cat /proc/mounts | grep " /uboot " | cut -d " " -f 1`
  BOOT_PART_NAME=`echo $BOOT_PART_DEV | cut -d "/" -f 3`
  BOOT_DEV_NAME=`echo /sys/block/*/${BOOT_PART_NAME} | cut -d "/" -f 4`
  BOOT_PART_NUM=`cat /sys/block/${BOOT_DEV_NAME}/${BOOT_PART_NAME}/partition`

  ROOT_DEV_SIZE=`cat /sys/block/${ROOT_DEV_NAME}/size`
  TARGET_END=`expr $ROOT_DEV_SIZE - 1`

  PARTITION_TABLE=`parted -m $ROOT_DEV unit s print | tr -d 's'`

  LAST_PART_NUM=`echo "$PARTITION_TABLE" | tail -n 1 | cut -d ":" -f 1`

  ROOT_PART_LINE=`echo "$PARTITION_TABLE" | grep -e "^${ROOT_PART_NUM}:"`
  ROOT_PART_START=`echo $ROOT_PART_LINE | cut -d ":" -f 2`
  ROOT_PART_END=`echo $ROOT_PART_LINE | cut -d ":" -f 3`
}

check_variables () {
  if [ $ROOT_PART_NUM -ne $LAST_PART_NUM ]; then
    FAIL_REASON="Data partition should be last partition"
    return 1
  fi

  if [ $ROOT_PART_END -gt $TARGET_END ]; then
    FAIL_REASON="Data partition runs past the end of device"
    return 1
  fi

  if [ ! -b $ROOT_DEV ] || [ ! -b $ROOT_PART_DEV ] || [ ! -b $BOOT_PART_DEV ] ; then
    FAIL_REASON="Could not determine partitions"
    return 1
  fi
}

main () {
  get_variables

  if ! check_variables; then
    return 1
  fi

  if [ $ROOT_PART_END -eq $TARGET_END ]; then
    reboot_pi
  fi

if ! parted -m $ROOT_DEV u s resizepart $ROOT_PART_NUM $TARGET_END; then
    FAIL_REASON="Data partition resize failed"
    return 1
  fi

  return 0
}

mount -t proc proc /proc
mount -t sysfs sys /sys

mount /uboot
sed -i 's| init=/usr/lib/raspi-config/init_resize.sh||' /uboot/cmdline.txt
mount /uboot -o remount,ro
sync

echo 1 > /proc/sys/kernel/sysrq

if ! check_commands; then
  reboot_pi
fi

if main; then
  whiptail --infobox "Resized data partition. Rebooting in 5 seconds..." 20 60
  sleep 5
else
  sleep 5
  whiptail --msgbox "Could not expand filesystem, please try raspi-config.\n${FAIL_REASON}" 20 60
fi

reboot_pi
