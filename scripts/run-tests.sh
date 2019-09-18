#!/bin/bash

set -e

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
if [ "${root_dir}" != "${PWD}" ]; then
    echo "You must execute $(basename $0) from the root directory: ${root_dir}"
    exit 1
fi

WORKSPACE=./tests

# Relative to where scripts are executed (${WORKSPACE}/mender-image-tests)
MENDER_CONVERT_DIR=../../

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

MENDER_ACCEPTANCE_URL="https://raw.githubusercontent.com/mendersoftware/meta-mender/master/tests/acceptance"

# Some distros do not have /sbin in path for "normal users"
export PATH="${PATH}:/sbin"

convert_and_test() {
    device_type=$1
    artifact_name=$2
    image_url=$3
    image_name=$4
    image_name_compressed=$5
    config=$6 # Optional

    wget --progress=dot:giga -N ${image_url} -P input/

    echo "Extracting: ${image_name_compressed}"
    case "${image_name_compressed}" in
    *.gz)
        gunzip -f input/${image_name_compressed}
        ;;
    *.zip)
        cd input
        unzip -o ${image_name_compressed}
        cd -
      ;;
    *.xz)
        xz -d -f input/${image_name_compressed}
        ;;
    *)
        echo "Unknown image type: ${image_name_compressed}"
        exit 1
    esac

    rm -f ${WORKSPACE}/test_config


    # Two motives for the following statement
    #
    # - speed up tests by avoiding decompression on all images (majority of images
    #   we test have a platform specific configuration)
    #
    # - test providing multiple '--config' options
    #
    # - (when no platform configuration is provided) test conversion without
    #   '--config' and with MENDER_COMPRESS_DISK_IMAGE=y. Compressed disk
    #   images is the default user facing option and we need to ensure that we
    #   cover this in the tests.
    if [ -n "${config}" ]; then
        echo "Will disable MENDER_COMPRESS_DISK_IMAGE for this image"
        echo "MENDER_COMPRESS_DISK_IMAGE=n" > ${WORKSPACE}/test_config
        local MENDER_CONVERT_EXTRA_ARGS="--config ${config} --config ${WORKSPACE}/test_config"
    fi

    MENDER_ARTIFACT_NAME=${artifact_name} ./docker-mender-convert \
        --disk-image input/${image_name} \
        ${MENDER_CONVERT_EXTRA_ARGS}

    if pip list | grep -q -e pytest-html; then
        html_report_args="--html=${MENDER_CONVERT_DIR}/report_${device_type}.html --self-contained-html"
    fi

    # Need to decompress images built with MENDER_COMPRESS_DISK_IMAGE=y before
    # running tests.
    if [ -f deploy/${device_type}-${artifact_name}.sdimg.gz ]; then
        # sudo is needed because the image is created using docker-mender-convert
        # which sets root permissions on the image
        sudo gunzip --force deploy/${device_type}-${artifact_name}.sdimg.gz
    fi

    cd ${WORKSPACE}/mender-image-tests

    python2 -m pytest --verbose \
            --junit-xml="${MENDER_CONVERT_DIR}/results_${device_type}.xml" \
            ${html_report_args} \
            --test-conversion \
            --test-variables="${MENDER_CONVERT_DIR}/deploy/${device_type}-${artifact_name}.cfg" \
            --board-type="${device_type}" \
            --mender-image=${device_type}-${artifact_name}.sdimg \
            --sdimg-location="${MENDER_CONVERT_DIR}/deploy"
    exitcode=$?

    cd -

    return $exitcode
}

get_pytest_files() {
    wget -N ${MENDER_ACCEPTANCE_URL}/pytest.ini -P $WORKSPACE/mender-image-tests
    wget -N ${MENDER_ACCEPTANCE_URL}/common.py -P $WORKSPACE/mender-image-tests
    wget -N ${MENDER_ACCEPTANCE_URL}/conftest.py -P $WORKSPACE/mender-image-tests
    wget -N ${MENDER_ACCEPTANCE_URL}/fixtures.py -P $WORKSPACE/mender-image-tests
}

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
