#!/bin/bash
#
# Copyright 2019 Northern.tech AS
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

# Exit if any command exits with a non-zero exit status.
set -o errexit

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}")/../"  && pwd)
if [ "${root_dir}" != "${PWD}" ]; then
    echo "You must execute $(basename $0) from the root directory: ${root_dir}"
    exit 1
fi

server_url=""
output_dir=""
while (("$#")); do
    case "$1" in
        -o | --output-dir)
            output_dir="${2}"
            shift 2
            ;;
        -s | --server-url)
            server_url="${2}"
            shift 2
            ;;
        -S | --server-cert)
            server_cert="${2}"
            shift 2
            ;;
        *)
            echo "Sorry but the provided option is not supported: $1"
            echo "Usage:  $(basename $0) --output-dir ./rootfs_overlay_demo --server-url <your server URL> [--server-cert <path to your server.crt file>]"
            exit 1
            ;;
    esac
done

if [ -z "${output_dir}" ]; then
    echo "Sorry, but you need to provide an output directory using the '-o/--output-dir' option"
    exit 1
fi

if [ -z "${server_url}" ]; then
    echo "Sorry, but you need to provide a server URL using the '-s/--server-url' option"
    exit 1
fi

if [ -e ${output_dir} ]; then
    sudo chown -R $(id -u) ${output_dir}
    sudo chgrp -R $(id -g) ${output_dir}
fi

mkdir -p ${root_dir}/input/resources
cat <<- EOF > ${root_dir}/input/resources/mender.conf
{
  "ServerURL": "${server_url}",
EOF

if [ -n "${server_cert}" ]; then
    cat <<- EOF >> ${root_dir}/input/resources/mender.conf
  "ServerCertificate": "/etc/mender/server.crt"
EOF
    cp -f "${server_cert}" ${output_dir}/etc/mender/server.crt
fi

cat <<- EOF >> ${root_dir}/input/resources/mender.conf
}
EOF

sudo chown -R 0 ${output_dir}
sudo chgrp -R 0 ${output_dir}

echo "Configuration file for using Production Mender Server written to: ${root_dir}/input/resources/mender.conf"
