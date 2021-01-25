#
# Copyright 2020 Northern.tech AS
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

source modules/zip.sh
source modules/log.sh

# compression_type
#
# $1 - Path to the compressed disk image
#
# @return - The MENDER_COMPRESS_IMAGE compression type
#
function compression_type()  {
    if [[ $# -ne 1 ]]; then
        log_fatal "compression_type() requires one argument"
    fi
    local -r disk_image="${1}"
    case "${disk_image}" in
        *.img | *.sdimg | *.wic | *.rpi-sdimg)
            echo "none"
            ;;
        *.gz)
            echo "gzip"
            ;;
        *.zip)
            echo "zip"
            ;;
        *.xz)
            echo "lzma"
            ;;
        *)
            log_fatal "Unsupported compression type: ${disk_image}. Please uncompress the image yourself."
            ;;
    esac
}

# Decompresses the given input image
#
#  $1 - Path to the compressed image
#  $2 - Path to the output directory
#
# @return - Name of the uncompressed image
#
function decompress_image()  {
    if [[ $# -ne 2 ]]; then
        log_fatal "decompress_image() requires an image argument and an output directory"
    fi
    local -r input_image="${1}"
    local -r output_dir="${2}"
    local disk_image="${output_dir}/$(basename ${input_image})"
    case "$(compression_type ${disk_image})" in
        none)
            :
            ;;
        gzip)
            log_info "Decompressing ${disk_image}..."
            disk_image=${disk_image%.gz}
            zcat "${input_image}" > "${disk_image}"
            ;;
        zip)
            log_info "Decompressing ${disk_image}..."
            filename="$(zip_get_imgname ${input_image})"
            unzip "${input_image}" -d "${output_dir}" &> /dev/null
            disk_image="$(dirname ${disk_image})/${filename}"
            ;;
        lzma)
            log_info "Decompressing ${disk_image}..."
            disk_image=${disk_image%.xz}
            xzcat "${input_image}" > "${disk_image}"
            ;;
        *)
            log_fatal "Unsupported input image format: ${input_image}. We support: '.img', '.gz', '.zip', '.xz'."
            ;;
    esac
    echo "${disk_image}"
}
