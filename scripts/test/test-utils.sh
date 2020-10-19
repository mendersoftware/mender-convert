MENDER_ACCEPTANCE_URL="https://raw.githubusercontent.com/mendersoftware/meta-mender/master/tests/acceptance"

WORKSPACE=${WORKSPACE:-./tests}

MENDER_CONVERT_DIR=$PWD

#
# function image_name_after_conversion()
#
# Transforms the given input image name to the name given to the output image by
# mender-convert.
#
# That is, an input image 'bone-debian-9.5-iot-armhf-2018-08-30-4gb.img.xz'
#
# T(bone-debian-9.5-iot-armhf-2018-08-30-4gb.img.xz)
#          -> bone-debian-9.5-iot-armhf-2018-08-30-4gb-beaglebone-mender
#
# $1 - image name, with optional .img and compression endings
# $2 - the compression used for the image
# $3 - the device type
#
function image_name_after_conversion () {
  if (( $# < 1 )); then
    echo "image_name_after_conversion requires one argument. $# given."
    exit 1
  fi
  local converted_image_name="$1"
  local compression="${2}"
  local device_type="${3}"
  # Remove the compression if any
  if [[ "${compression}" != "img" ]]; then
    converted_image_name="${converted_image_name%.${compression}}"
  fi
  # remove the .img extension if any
  converted_image_name="${converted_image_name%.img}"
  # Add the extension which a successful mender-conversion will apply
  converted_image_name="${converted_image_name}-${device_type}-mender.img"
  # Add the compression back in
  if [[ "${compression}" != "img" ]]; then
    converted_image_name="${converted_image_name}.${compression}"
  fi
  echo "$(basename ${converted_image_name})"
}

function assert () {
  if (( $# < 2 )); then
    echo >&2 "assert() requires at least an expected and an actual value"
  fi
  if [[ "$1" == "$2" ]]; then
    return
  fi
  # Neither string nor value matched the assertion
  echo >&2 "Assertion error: $1 not equal to $2"
  [[ -n "$3" ]] && echo >&2 "$3"
  exit 1
}

source modules/decompressinput.sh

convert_and_test() {
  device_type=$1
  artifact_name=$2
  image_file=$3
  extra_args=$4 # Optional

  rm -f ${WORKSPACE}/test_config

  MENDER_ARTIFACT_NAME=${artifact_name} ./docker-mender-convert \
                      --disk-image ${image_file} \
                      ${extra_args}

  local compression="${image_file##*.}"
  local ret=0

  image_name=$(image_name_after_conversion "${image_file}" "${compression}" "${device_type}")

  converted_image_file="${MENDER_CONVERT_DIR}/deploy/$(basename ${image_name})"

  converted_image_uncompressed="$(decompress_image ${converted_image_file} ${MENDER_CONVERT_DIR}/deploy)"

  run_tests "${device_type}"  "$(basename ${converted_image_uncompressed})" || ret=$?

  assert "${ret}" "0" "Failed to convert ${image_file}"

}

run_tests() {
  device_type=$1
  converted_image_file=$2
  shift 2
  pytest_args_extra=$@

  converted_image_name="${converted_image_file%.img}"

  if pip3 list | grep -q -e pytest-html; then
    html_report_args="--html=${MENDER_CONVERT_DIR}/report_${device_type}.html --self-contained-html"
  fi

  # Need to decompress images built with MENDER_COMPRESS_DISK_IMAGE=gzip before
  # running tests.
  if [ -f "deploy/${converted_image_name}.img.gz" ]; then
    # sudo is needed because the image is created using docker-mender-convert
    # which sets root permissions on the image
    sudo gunzip --force "deploy/${converted_image_name}.img.gz"
  fi

  # MEN-3051: Rename the files back to .sdimg, as the sdimg extension has meaning
  # in the test-infrastructure.
  for file in ${MENDER_CONVERT_DIR}/deploy/*.img; do
      mv $file "${file%.img}.sdimg"
  done

  cd ${WORKSPACE}/mender-image-tests

  echo "Converted image name: "
  echo "$converted_image_name"

  python3 -m pytest --verbose \
    --junit-xml="${MENDER_CONVERT_DIR}/results_${device_type}.xml" \
    ${html_report_args} \
    --test-conversion \
    --test-variables="${MENDER_CONVERT_DIR}/deploy/${converted_image_name}.cfg" \
    --board-type="${device_type}" \
    --mender-image="${converted_image_name}.sdimg" \
    --sdimg-location="${MENDER_CONVERT_DIR}/deploy" \
    tests \
    ${pytest_args_extra}

  exitcode=$?

  cd -

  return $exitcode
}

get_pytest_files() {
  wget -N ${MENDER_ACCEPTANCE_URL}/pytest.ini -P $WORKSPACE/mender-image-tests
  wget -N ${MENDER_ACCEPTANCE_URL}/common.py -P $WORKSPACE/mender-image-tests
  wget -N ${MENDER_ACCEPTANCE_URL}/helpers.py -P $WORKSPACE/mender-image-tests
  wget -N ${MENDER_ACCEPTANCE_URL}/conftest.py -P $WORKSPACE/mender-image-tests
  wget -N ${MENDER_ACCEPTANCE_URL}/fixtures.py -P $WORKSPACE/mender-image-tests
}

