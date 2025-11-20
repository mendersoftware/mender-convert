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
  echo "$0 [--config EXTRA_CONFIG_FILE] <--all | --only DEVICE_TYPE | --raspios-image-url RASPIOS_IMAGE_URL | --prebuilt-image DEVICE_TYPE IMAGE_NAME> [-- <pytest-options>]"
  exit 1
}

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" && pwd )
if [ "${root_dir}" != "${PWD}" ]; then
  echo "You must execute $(basename $0) from the root directory: ${root_dir}"
  exit 1
fi

WORKSPACE=./tests

UBUNTU_IMAGE_URL="https://downloads.mender.io/mender-convert/images/Ubuntu-Jammy-x86-64.img.gz"

DEBIAN_IMAGE_URL="https://downloads.mender.io/mender-convert/images/Debian-11-x86-64.img.gz"

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
RASPIOS_IMAGE_URL=
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
    --raspios-image-url)
      usage_if_empty "$2"
      RASPIOS_IMAGE_URL="$2"
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
fi

MATCHED_A_TEST=0

if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "ubuntu-qemux86-64" ]; then
  MATCHED_A_TEST=1
  # For this test, we explicitly test compressed and uncompressed image conversion
  # For most of the other tests, we just test the uncompressed image conversion to
  # speed up the process
  wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/image/
  UBUNTU_IMAGE_COMPRESSED="${UBUNTU_IMAGE_URL##*/}"
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
  MATCHED_A_TEST=1
  wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/image/
  UBUNTU_IMAGE_COMPRESSED="${UBUNTU_IMAGE_URL##*/}"
  UBUNTU_IMAGE_UNCOMPRESSED=${UBUNTU_IMAGE_COMPRESSED%.gz}
  gunzip --force "input/image/${UBUNTU_IMAGE_COMPRESSED}"
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

if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "raspberrypi4_bookworm_64bit" ]; then
  MATCHED_A_TEST=1
  # For this test we test compressed image to verify xz compression
  wget --progress=dot:giga -N ${RASPIOS_IMAGE_URL} -P input/image/
  RASPIOS_IMAGE_COMPRESSED="${RASPIOS_IMAGE_URL##*/}"
  convert_and_test "raspberrypi4_64" \
                   "release-1" \
                   "input/image/${RASPIOS_IMAGE_COMPRESSED}" \
                   "--config configs/raspberrypi/uboot/debian/raspberrypi4_bookworm_64bit_config $EXTRA_CONFIG" \
                   "--" \
                   "$@" \
                   || test_result=$?
fi

if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "raspberrypi4_uefi_bookworm_64bit" ]; then
  MATCHED_A_TEST=1
  # For this test we test compressed image to verify xz compression
  wget --progress=dot:giga -N ${RASPIOS_IMAGE_URL} -P input/image/
  RASPIOS_IMAGE_COMPRESSED="${RASPIOS_IMAGE_URL##*/}"
  convert_and_test "raspberrypi4_64_uefi" \
                   "release-1" \
                   "input/image/${RASPIOS_IMAGE_COMPRESSED}" \
                   "--config configs/raspberrypi/uefi/debian/raspberrypi4_bookworm_64bit_config $EXTRA_CONFIG" \
                   "--" \
                   "$@" \
                   || test_result=$?
fi

if [ "$TEST_ALL" == "1" -o "$TEST_PLATFORM" == "debian-qemux86-64" ]; then
  MATCHED_A_TEST=1
  wget --progress=dot:giga -N ${DEBIAN_IMAGE_URL} -P input/image/
  DEBIAN_IMAGE_COMPRESSED="${DEBIAN_IMAGE_URL##*/}"
  DEBIAN_IMAGE_UNCOMPRESSED=${DEBIAN_IMAGE_COMPRESSED%.gz}
  gunzip --force "input/image/${DEBIAN_IMAGE_COMPRESSED}"
  convert_and_test "qemux86-64" \
                   "release-1" \
                   "input/image/${DEBIAN_IMAGE_UNCOMPRESSED}" \
                   "--overlay input/tests/ssh-public-key-overlay" \
                   "--config configs/debian-qemux86-64_config $EXTRA_CONFIG" \
                   "--" \
                   "$@" \
                   || test_result=$?
fi

if [ "$MATCHED_A_TEST" = 0 ]; then
  echo "No test matched!" 1>&2
  exit 1
fi

exit $test_result
