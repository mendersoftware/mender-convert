# Copyright 2023 Northern.tech AS
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
  echo "$0 [--config EXTRA_CONFIG_FILE] <--all | --only DEVICE_TYPE | --prebuilt-image DEVICE_TYPE IMAGE_NAME> [-- <pytest-options>]"
  exit 1
}

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" && pwd )
if [ "${root_dir}" != "${PWD}" ]; then
  echo "You must execute $(basename $0) from the root directory: ${root_dir}"
  exit 1
fi

WORKSPACE=./tests

## Auto-update
RASPBIAN_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz"

UBUNTU_IMAGE_URL="https://downloads.mender.io/mender-convert/images/Ubuntu-Jammy-x86-64.img.gz"

DEBIAN_IMAGE_URL="https://downloads.mender.io/mender-convert/images/Debian-11-x86-64.img.gz"

## Auto-update
UBUNTU_SERVER_RPI_IMAGE_URL="https://cdimage.ubuntu.com/releases/22.04.4/release/ubuntu-22.04.4-preinstalled-server-armhf+raspi.img.xz"

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
    --)
      shift
      break
      ;;
  esac
  shift
done

test_result=0

if [ -n "$PREBUILT_IMAGE" ]; then
  run_tests $PREBUILT_IMAGE "$@" \
            || test_result=$?
  exit $test_result

else
  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "ubuntu-qemux86-64" ]; then
    # For this test, we explicitly test compressed and uncompressed image conversion
    # For most of the other tests, we just test the uncompressed image conversion to
    # speed up the process
    wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/image/
    UBUNTU_IMAGE_COMPRESSED="${UBUNTU_IMAGE_URL##*/}"
    mkdir -p input/tests
    sudo cp -r "tests/ssh-public-key-overlay" "input/tests/"
    convert_and_test "qemux86-64" \
                     "release-1" \
                     "input/image/${UBUNTU_IMAGE_COMPRESSED}" \
                     "--overlay input/tests/ssh-public-key-overlay" \
                     "--config configs/ubuntu-qemux86-64_config $EXTRA_CONFIG" \
                     "--" \
                     "$@" \
                     || test_result=$?

    echo >&2 "----------------------------------------"
    echo >&2 "Running the uncompressed test"
    echo >&2 "----------------------------------------"
    rm -rf deploy
    UBUNTU_IMAGE_UNCOMPRESSED=${UBUNTU_IMAGE_COMPRESSED%.gz}
    gunzip --force "input/image/${UBUNTU_IMAGE_COMPRESSED}"
    run_convert "release-2" \
                "input/image/${UBUNTU_IMAGE_UNCOMPRESSED}" \
                "--config configs/ubuntu-qemux86-64_config $EXTRA_CONFIG" || test_result=$?
    ret=0
    UBUNTU_IMAGE_MENDER="${UBUNTU_IMAGE_UNCOMPRESSED%.img}-qemux86-64-mender.img"
    test -f deploy/${UBUNTU_IMAGE_MENDER} || ret=$?
    assert "${ret}" "0" "Expected uncompressed file deploy/${UBUNTU_IMAGE_MENDER}"
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "ubuntu-qemux86-64-no-grub-d" ]; then
    wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/image/
    UBUNTU_IMAGE_COMPRESSED="${UBUNTU_IMAGE_URL##*/}"
    UBUNTU_IMAGE_UNCOMPRESSED=${UBUNTU_IMAGE_COMPRESSED%.gz}
    gunzip --force "input/image/${UBUNTU_IMAGE_COMPRESSED}"
    mkdir -p input/tests
    sudo cp -r "tests/ssh-public-key-overlay" "input/tests/"
    QEMU_NO_SECURE_BOOT=1 \
                     convert_and_test \
                     "qemux86-64" \
                     "release-1" \
                     "input/image/${UBUNTU_IMAGE_UNCOMPRESSED}" \
                     "--overlay input/tests/ssh-public-key-overlay" \
                     "--config configs/ubuntu-qemux86-64_config" \
                     "--config configs/testing/no-grub.d_config $EXTRA_CONFIG" \
                     "--" \
                     "$@" \
                     || test_result=$?
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "raspberrypi3" ]; then
    # For this test we test compressed image to verify xz compression
    wget --progress=dot:giga -N ${RASPBIAN_IMAGE_URL} -P input/image/
    RASPBIAN_IMAGE_COMPRESSED="${RASPBIAN_IMAGE_URL##*/}"
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/image/${RASPBIAN_IMAGE_COMPRESSED}" \
                     "--config configs/raspberrypi3_config $EXTRA_CONFIG" \
                     "--" \
                     "$@" \
                     || test_result=$?
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "ubuntu-raspberrypi3" ]; then
    wget --progress=dot:giga -N ${UBUNTU_SERVER_RPI_IMAGE_URL} -P input/image/
    UBUNTU_SERVER_RPI_IMAGE_COMPRESSED="${UBUNTU_SERVER_RPI_IMAGE_URL##*/}"
    UBUNTU_SERVER_RPI_IMAGE_UNCOMPRESSED="${UBUNTU_SERVER_RPI_IMAGE_COMPRESSED%.xz}"
    unxz --force "input/image/${UBUNTU_SERVER_RPI_IMAGE_COMPRESSED}"
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/image/${UBUNTU_SERVER_RPI_IMAGE_UNCOMPRESSED}" \
                     "--config configs/raspberrypi3_config $EXTRA_CONFIG" \
                     "--" \
                     "$@" \
                     || test_result=$?
  fi

  if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "debian-qemux86-64" ]; then
    wget --progress=dot:giga -N ${DEBIAN_IMAGE_URL} -P input/image/
    DEBIAN_IMAGE_COMPRESSED="${DEBIAN_IMAGE_URL##*/}"
    DEBIAN_IMAGE_UNCOMPRESSED=${DEBIAN_IMAGE_COMPRESSED%.gz}
    gunzip --force "input/image/${DEBIAN_IMAGE_COMPRESSED}"
    mkdir -p input/tests
    sudo cp -r "tests/ssh-public-key-overlay" "input/tests/"
    convert_and_test "qemux86-64" \
                     "release-1" \
                     "input/image/${DEBIAN_IMAGE_UNCOMPRESSED}" \
                     "--overlay input/tests/ssh-public-key-overlay" \
                     "--config configs/debian-qemux86-64_config $EXTRA_CONFIG" \
                     "--" \
                     "$@" \
                     || test_result=$?
  fi



  exit $test_result
fi
