MENDER_ACCEPTANCE_URL="https://raw.githubusercontent.com/mendersoftware/meta-mender/master/tests/acceptance"

WORKSPACE=${WORKSPACE:-./tests}

MENDER_CONVERT_DIR=$PWD

convert_and_test() {
  device_type=$1
  artifact_name=$2
  image_url=$3
  image_file=$4
  image_file_compressed=$5
  config=$6 # Optional

  wget --progress=dot:giga -N ${image_url} -P input/

  echo "Extracting: ${image_file_compressed}"
  case "${image_file_compressed}" in
    *.gz)
      gunzip -f input/${image_file_compressed}
      ;;
    *.zip)
      cd input
      unzip -o ${image_file_compressed}
      cd -
      ;;
    *.xz)
      xz -d -f input/${image_file_compressed}
      ;;
    *)
      echo "Unknown image type: ${image_file_compressed}"
      exit 1
      ;;
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
  #   '--config' and with MENDER_COMPRESS_DISK_IMAGE=gzip. Compressed disk
  #   images is the default user facing option and we need to ensure that we
  #   cover this in the tests.
  if [ -n "${config}" ]; then
    echo "Will disable MENDER_COMPRESS_DISK_IMAGE for this image"
    echo "MENDER_COMPRESS_DISK_IMAGE=none" > ${WORKSPACE}/test_config
    local MENDER_CONVERT_EXTRA_ARGS="--config ${config} --config ${WORKSPACE}/test_config"
  fi

  MENDER_ARTIFACT_NAME=${artifact_name} ./docker-mender-convert \
    --disk-image input/${image_file} \
    ${MENDER_CONVERT_EXTRA_ARGS}

  local ret=0

  # The output image name after conversion
  image_name="${image_file%.img}-${device_type}-mender"

  run_tests "${device_type}"  "$image_name" || ret=$?

  rm -f deploy/${image_file}*

  return $ret
}

run_tests() {
  device_type=$1
  converted_image_name=$2
  shift 2
  pytest_args_extra=$@

  if pip3 list | grep -q -e pytest-html; then
    html_report_args="--html=${MENDER_CONVERT_DIR}/report_${device_type}.html --self-contained-html"
  fi

  # Need to decompress images built with MENDER_COMPRESS_DISK_IMAGE=gzip before
  # running tests.
  if [ -f "deploy/${converted_image_name}.gz" ]; then
    # sudo is needed because the image is created using docker-mender-convert
    # which sets root permissions on the image
    sudo gunzip --force "deploy/${converted_image_name}.gz"
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
  wget -N ${MENDER_ACCEPTANCE_URL}/conftest.py -P $WORKSPACE/mender-image-tests
  wget -N ${MENDER_ACCEPTANCE_URL}/fixtures.py -P $WORKSPACE/mender-image-tests
}

