#!/bin/bash

set -e

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" && pwd )
if [ "${root_dir}" != "${PWD}" ]; then
  echo "You must execute $(basename $0) from the root directory: ${root_dir}"
  exit 1
fi

WORKSPACE=./tests

BBB_DEBIAN_IMAGE="bone-debian-9.5-iot-armhf-2018-10-07-4gb.img"
BBB_DEBIAN_IMAGE_URL="http://debian.beagleboard.org/images/${BBB_DEBIAN_IMAGE}.xz"

RASPBIAN_IMAGE="2019-04-08-raspbian-stretch-lite"
RASPBIAN_IMAGE_URL="https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/${RASPBIAN_IMAGE}.zip"

TINKER_IMAGE="20170417-tinker-board-linaro-stretch-alip-v1.8"
TINKER_IMAGE_URL="http://dlcdnet.asus.com/pub/ASUS/mb/Linux/Tinker_Board_2GB/${TINKER_IMAGE}.zip"

UBUNTU_IMAGE="Ubuntu-Bionic-x86-64.img"
UBUNTU_IMAGE_URL="https://d1b0l86ne08fsf.cloudfront.net/mender-convert/images/${UBUNTU_IMAGE}.gz"

UBUNTU_SERVER_RPI_IMAGE="ubuntu-18.04.3-preinstalled-server-armhf+raspi3.img"
UBUNTU_SERVER_RPI_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu/releases/bionic/release/${UBUNTU_SERVER_RPI_IMAGE}.xz"

# Keep common function declarations in separate utils script
UTILS_PATH=${0/$(basename $0)/test-utils.sh}
source $UTILS_PATH

# Some distros do not have /sbin in path for "normal users"
export PATH="${PATH}:/sbin"

if [ ! -d ${WORKSPACE}/mender-image-tests ]; then
  git clone https://github.com/mendersoftware/mender-image-tests ${WORKSPACE}/mender-image-tests
else
  cd ${WORKSPACE}/mender-image-tests
  git pull
  cd -
fi

mkdir -p ${WORKSPACE}

get_pytest_files

test_result=0

convert_and_test "qemux86_64" \
  "release-1" \
  "${UBUNTU_IMAGE_URL}" \
  "${UBUNTU_IMAGE}" \
  "${UBUNTU_IMAGE}.gz" \
  "configs/qemux86-64_config" || test_result=$?

convert_and_test "raspberrypi" \
  "release-1" \
  "${RASPBIAN_IMAGE_URL}" \
  "${RASPBIAN_IMAGE}.img" \
  "${RASPBIAN_IMAGE}.zip" \
  "configs/raspberrypi3_config" || test_result=$?

# MEN-2809: Disabled due broken download link
#convert_and_test "linaro-alip" \
#                 "release-1" \
#                 "${TINKER_IMAGE_URL}" \
#                 "${TINKER_IMAGE}.img" \
#                 "${TINKER_IMAGE}.zip" || test_result=$?

convert_and_test "beaglebone" \
  "release-1" \
  "${BBB_DEBIAN_IMAGE_URL}" \
  "${BBB_DEBIAN_IMAGE}" \
  "${BBB_DEBIAN_IMAGE}.xz" || test_result=$?

convert_and_test "ubuntu" \
  "release-1" \
  "${UBUNTU_SERVER_RPI_IMAGE_URL}" \
  "${UBUNTU_SERVER_RPI_IMAGE}" \
  "${UBUNTU_SERVER_RPI_IMAGE}.xz" \
  "configs/raspberrypi3_config" || test_result=$?

exit $test_result
