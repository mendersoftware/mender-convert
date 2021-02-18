#!/bin/bash

set -e

usage() {
  echo "$0 <--all | --only DEVICE_TYPE | --prebuilt-image DEVICE_TYPE IMAGE_NAME>"
  exit 1
}

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" && pwd )
if [ "${root_dir}" != "${PWD}" ]; then
  echo "You must execute $(basename $0) from the root directory: ${root_dir}"
  exit 1
fi

WORKSPACE=./tests

## Auto-update
BBB_DEBIAN_SDCARD_IMAGE_URL="https://debian.beagleboard.org/images/bone-debian-10.3-iot-armhf-2020-04-06-4gb.img.xz"

# Not on official home page, but found via https://elinux.org/Beagleboard:BeagleBoneBlack_Debian:

## Auto-update
BBB_DEBIAN_EMMC_IMAGE_URL="https://rcn-ee.com/rootfs/bb.org/testing/2021-01-11/buster-console/bone-debian-10.7-console-armhf-2021-01-11-1gb.img.xz"

## Auto-update
RASPBIAN_IMAGE_URL="http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/2019-09-26-raspbian-buster-lite.zip"

## Auto-update
TINKER_IMAGE_URL="http://dlcdnet.asus.com/pub/ASUS/mb/Linux/Tinker_Board_2GB/20170417-tinker-board-linaro-stretch-alip-v1.8.zip"

UBUNTU_IMAGE_URL="https://downloads.mender.io/mender-convert/images/Ubuntu-Bionic-x86-64.img.gz"

## Auto-update
UBUNTU_SERVER_RPI_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu/releases/18.04.5/release/ubuntu-18.04.5-preinstalled-server-armhf+raspi3.img.xz"

# Keep common function declarations in separate utils script
UTILS_PATH=${0/$(basename $0)/test-utils.sh}
source $UTILS_PATH

# Some distros do not have /sbin in path for "normal users"
export PATH="${PATH}:/sbin"

mkdir -p ${WORKSPACE}

get_pytest_files

prepare_ssh_keys

if ! [ "$1" == "--all" -o "$1" == "--only" -a -n "$2" -o "$1" == "--prebuilt-image" -a -n "$3" ]; then
  usage
fi

test_result=0

if [ "$1" == "--prebuilt-image" ]; then
  run_tests "$2" "$3" \
            "-k" "'not test_update'" \
            || test_result=$?
  exit $test_result

else
  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "qemux86_64" ]; then
    wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/
    convert_and_test "qemux86_64" \
                     "release-1" \
                     "input/Ubuntu-Bionic-x86-64.img.gz" \
                     "--overlay tests/ssh-public-key-overlay" \
                     "--config configs/qemux86-64_config" \
                     || test_result=$?

    echo >&2 "----------------------------------------"
    echo >&2 "Running the uncompressed test"
    echo >&2 "----------------------------------------"
    rm -rf deploy
    gunzip --force "input/Ubuntu-Bionic-x86-64.img.gz"
    run_convert "release-2" \
                "input/Ubuntu-Bionic-x86-64.img" \
                "--config configs/qemux86-64_config" || test_result=$?
    ret=0
    test -f deploy/Ubuntu-Bionic-x86-64-qemux86_64-mender.img || ret=$?
    assert "${ret}" "0" "Expected uncompressed file deploy/Ubuntu-Bionic-x86-64-qemux86_64-mender.img"
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "raspberrypi3" ]; then
    wget --progress=dot:giga -N ${RASPBIAN_IMAGE_URL} -P input/
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/2019-09-26-raspbian-buster-lite.zip" \
                     "--config configs/raspberrypi3_config" \
                     -- \
                     "-k" "'not test_update'" \
                     || test_result=$?
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "linaro-alip" ]; then
    # MEN-2809: Disabled due broken download link
    #convert_and_test "linaro-alip" \
    #                 "release-1" \
    #                 "${TINKER_IMAGE_URL}" \
    #                 "${TINKER_IMAGE}.img" \
    #                 "${TINKER_IMAGE}.zip" \
    #                 -- \
    #                 "-k" "'not test_update'" \
    #                 || test_result=$?
    true
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "beaglebone" ]; then
    wget --progress=dot:giga -N ${BBB_DEBIAN_SDCARD_IMAGE_URL} -P input/
    # Convert uncompressed images to speed up this job
    unxz --force "input/bone-debian-10.3-iot-armhf-2020-04-06-4gb.img.xz"
    convert_and_test "beaglebone-sdcard" \
                     "release-1" \
                     "input/bone-debian-10.3-iot-armhf-2020-04-06-4gb.img" \
                     "--config configs/beaglebone_black_debian_sdcard_config" \
                     -- \
                     "-k" "'not test_update'" \
                     || test_result=$?

    rm -rf deploy
    wget --progress=dot:giga -N ${BBB_DEBIAN_EMMC_IMAGE_URL} -P input/
    unxz --force "input/bone-debian-10.7-console-armhf-2021-01-11-1gb.img.xz"
    convert_and_test "beaglebone-emmc" \
                     "release-1" \
                     "input/bone-debian-10.7-console-armhf-2021-01-11-1gb.img" \
                     "--config configs/beaglebone_black_debian_emmc_config" \
                     -- \
                     "-k" "'not test_update'" \
                     || test_result=$?
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "ubuntu" ]; then
    wget --progress=dot:giga -N ${UBUNTU_SERVER_RPI_IMAGE_URL} -P input/
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/ubuntu-18.04.5-preinstalled-server-armhf+raspi3.img.xz" \
                     "--config configs/raspberrypi3_config" \
                     -- \
                     "-k" "'not test_update'" \
                     || test_result=$?
  fi

  exit $test_result
fi
