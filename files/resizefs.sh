#!/bin/sh
### BEGIN INIT INFO
# Provides: resizefs
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the data filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "$1" in
  start)
    log_daemon_msg "Starting resizefs service (once)"
    DISK=$(lsblk -f | sed -n '2{p;q}')
    DISK_DEV="/dev/$DISK"
    DISK_SIZE=$(blockdev --getsize $DISK_DEV)
    DATA_PART_DEV=$(findmnt /data -o source -n)
    DATA_PART=$(basename $DATA_PART_DEV)
    DATA_PART_START=$(parted -m $DISK_DEV unit s print | tr -d 's' | tail -n 1 | cut -d ":" -f 2)
    DATA_PART_SIZE=$(blockdev --getsize $DATA_PART_DEV)
    FREE_SPACE=`expr $DISK_SIZE - $DATA_PART_START - $DATA_PART_SIZE`

    if [ $FREE_SPACE -eq 0 ]; then
      log_daemon_msg "Data partition already resized, aborting"
    else
      resize2fs $DATA_PART_DEV
      FSSIZEMEG=`expr $FREE_SPACE + $DATA_PART_SIZE`
      FSSIZEMEG=`expr $FSSIZEMEG / 2 / 1024`"M"
      log_daemon_msg "Resizing $DATA_PART finished, new size is $FSSIZEMEG"
    fi

    systemctl --no-reload disable resizefs.service
    log_end_msg $?
    ;;
  *)
    echo "Usage: $0 start" >&2
    exit 3
    ;;
esac
