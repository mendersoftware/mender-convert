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

function parse_cli_options()  {
    while (("$#")); do
        case "$1" in
            -o | --overlay)
                overlays+=("${2}")
                shift 2
                ;;
            -c | --config)
                configs+=("${2}")
                shift 2
                ;;
            -d | --disk-image)
                disk_image="${2}"
                shift 2
                ;;
            *)
                log_fatal "Sorry but the provided option is not supported: $1"
                ;;
        esac
    done

    if [ -z "${disk_image}" ]; then
        log_warn "Sorry, but '--disk-image' is a mandatory option"
        log_warn "See ./mender-convert --help for more information"
        exit 1
    fi

    if [ ! -e ${disk_image} ]; then
        log_fatal "File not found: ${disk_image}"
    fi

}
