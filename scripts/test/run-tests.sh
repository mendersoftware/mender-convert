# Copyright 2022 Northern.tech AS
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

set -e

usage() {
  echo "$0 [--config EXTRA_CONFIG_FILE] <--all | --only DEVICE_TYPE | --prebuilt-image DEVICE_TYPE IMAGE_NAME>"
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
BBB_DEBIAN_EMMC_IMAGE_URL="https://rcn-ee.com/rootfs/bb.org/testing/2022-10-10/bullseye-minimal-arm64/bbai64-debian-11.5-minimal-arm64-2022-10-10-4gb.img.xz"

## Auto-update
RASPBIAN_IMAGE_URL="http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2020-02-14/2020-02-13-raspbian-buster-lite.zip"

UBUNTU_IMAGE_URL="https://downloads.mender.io/mender-convert/images/Ubuntu-Focal-x86-64.img.gz"

DEBIAN_IMAGE_URL="https://downloads.mender.io/mender-convert/images/Debian-11-x86-64.img.gz"

## Auto-update
UBUNTU_SERVER_RPI_IMAGE_URL="https://cdimage.ubuntu.com/ubuntu/releases/22.04.1/release/ubuntu-22.04.1-preinstalled-server-armhf+raspi.img.xz"

# Keep common function declarations in separate utils script
UTILS_PATH=${0/$(basename $0)/test-utils.sh}
source $UTILS_PATH

# Some distros do not have /sbin in path for "normal users"
export PATH="${PATH}:/sbin"

mkdir -p ${WORKSPACE}

get_pytest_files

prepare_ssh_keys

usage_if_empty() {
  if [ -z "$1" ]; then
    usage
  fi
}

PREBUILT_IMAGE=
TEST_PLATFORM=
TEST_ALL=0
EXTRA_CONFIG=
while [ -n "$1" ]; do
  case "$1" in
    --prebuilt-image)
      usage_if_empty "$3"
      PREBUILT_IMAGE="$2 $3"
      ;;
    --all)
      TEST_ALL=1
      ;;
    --only)
      usage_if_empty "$2"
      TEST_PLATFORM="$2"
      shift
      ;;
    --config)
      usage_if_empty "$2"
      EXTRA_CONFIG="$EXTRA_CONFIG --config $2"
      shift
      ;;
  esac
  shift
done

test_result=0

if [ -n "$PREBUILT_IMAGE" ]; then
  run_tests $PREBUILT_IMAGE \
            || test_result=$?
  exit $test_result

else
  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "ubuntu-qemux86-64" ]; then
    wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/image/
    mkdir -p input/tests
    sudo cp -r "tests/ssh-public-key-overlay" "input/tests/"
    convert_and_test "qemux86-64" \
                     "release-1" \
                     "input/image/Ubuntu-Focal-x86-64.img.gz" \
                     "--overlay input/tests/ssh-public-key-overlay" \
                     "--config configs/ubuntu-qemux86-64_config $EXTRA_CONFIG" \
                     || test_result=$?

    echo >&2 "----------------------------------------"
    echo >&2 "Running the uncompressed test"
    echo >&2 "----------------------------------------"
    rm -rf deploy
    gunzip --force "input/image/Ubuntu-Focal-x86-64.img.gz"
    run_convert "release-2" \
                "input/image/Ubuntu-Focal-x86-64.img" \
                "--config configs/ubuntu-qemux86-64_config $EXTRA_CONFIG" || test_result=$?
    ret=0
    test -f deploy/Ubuntu-Focal-x86-64-qemux86-64-mender.img || ret=$?
    assert "${ret}" "0" "Expected uncompressed file deploy/Ubuntu-Focal-x86-64-qemux86-64-mender.img"
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "ubuntu-qemux86-64-no-grub-d" ]; then
    wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/image/
    mkdir -p input/tests
    sudo cp -r "tests/ssh-public-key-overlay" "input/tests/"
    QEMU_NO_SECURE_BOOT=1 \
                     convert_and_test \
                     "qemux86-64" \
                     "release-1" \
                     "input/image/Ubuntu-Focal-x86-64.img.gz" \
                     "--overlay input/tests/ssh-public-key-overlay" \
                     "--config configs/ubuntu-qemux86-64_config" \
                     "--config configs/testing/no-grub.d_config $EXTRA_CONFIG" \
                     || test_result=$?
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "raspberrypi3" ]; then
    wget --progress=dot:giga -N ${RASPBIAN_IMAGE_URL} -P input/image/
    RASPBIAN_IMAGE="${RASPBIAN_IMAGE_URL##*/}"
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/image/${RASPBIAN_IMAGE}" \
                     "--config configs/raspberrypi3_config $EXTRA_CONFIG" \
                     || test_result=$?
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "beaglebone" ]; then
    wget --progress=dot:giga -N ${BBB_DEBIAN_SDCARD_IMAGE_URL} -P input/image/
    BBB_DEBIAN_SDCARD_IMAGE_COMPRESSED="${BBB_DEBIAN_SDCARD_IMAGE_URL##*/}"
    BBB_DEBIAN_SDCARD_IMAGE_UNCOMPRESSED="${BBB_DEBIAN_SDCARD_IMAGE_COMPRESSED%.xz}"
    # Convert uncompressed images to speed up this job
    unxz --force "input/image/${BBB_DEBIAN_SDCARD_IMAGE_COMPRESSED}"
    convert_and_test "beaglebone-sdcard" \
                     "release-1" \
                     "input/image/${BBB_DEBIAN_SDCARD_IMAGE_UNCOMPRESSED}" \
                     "--config configs/beaglebone_black_debian_sdcard_config $EXTRA_CONFIG" \
                     || test_result=$?

    rm -rf deploy
    wget --progress=dot:giga -N ${BBB_DEBIAN_EMMC_IMAGE_URL} -P input/image/
    BBB_DEBIAN_EMMC_IMAGE_COMPRESSED="${BBB_DEBIAN_EMMC_IMAGE_URL##*/}"
    BBB_DEBIAN_EMMC_IMAGE_UNCOMPRESSED="${BBB_DEBIAN_EMMC_IMAGE_COMPRESSED%.xz}"
    unxz --force "input/image/${BBB_DEBIAN_EMMC_IMAGE_COMPRESSED}"
    convert_and_test "beaglebone-emmc" \
                     "release-1" \
                     "input/image/${BBB_DEBIAN_EMMC_IMAGE_UNCOMPRESSED}" \
                     "--config configs/beaglebone_black_debian_emmc_config $EXTRA_CONFIG" \
                     || test_result=$?
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "ubuntu-raspberrypi3" ]; then
    wget --progress=dot:giga -N ${UBUNTU_SERVER_RPI_IMAGE_URL} -P input/image/
    UBUNTU_SERVER_RPI_IMAGE_COMPRESSED="${UBUNTU_SERVER_RPI_IMAGE_URL##*/}"
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/image/${UBUNTU_SERVER_RPI_IMAGE_COMPRESSED}" \
                     "--config configs/raspberrypi3_config $EXTRA_CONFIG" \
                     || test_result=$?
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "debian-qemux86-64" ]; then
    wget --progress=dot:giga -N ${DEBIAN_IMAGE_URL} -P input/image/
    mkdir -p input/tests
    sudo cp -r "tests/ssh-public-key-overlay" "input/tests/"
    convert_and_test "qemux86-64" \
                     "release-1" \
                     "input/image/Debian-11-x86-64.img.gz" \
                     "--overlay input/tests/ssh-public-key-overlay" \
                     "--config configs/debian-qemux86-64_config $EXTRA_CONFIG" \
                     || test_result=$?
  fi



  exit $test_result
fi
