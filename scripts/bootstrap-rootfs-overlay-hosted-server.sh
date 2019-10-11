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

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
if [ "${root_dir}" != "${PWD}" ]; then
    echo "You must execute $(basename $0) from the root directory: ${root_dir}"
    exit 1
fi

tenant_token=""
output_dir=""
while (( "$#" )); do
  case "$1" in
    -t | --tenant-token)
      tenant_token="${2}"
      shift 2
      ;;
    -o | --output-dir)
      output_dir="${2}"
      shift 2
      ;;
    *)
      echo "Sorry but the provided option is not supported: $1"
      echo "Usage:  $(basename $0) --output-dir ./rootfs_overlay_demo --tenant-token <paste your token here>"
      exit 1
      ;;
  esac
done

if [ -z "${output_dir}" ]; then
    echo "Sorry, but you need to provide an output directory using the '-o/--output-dir' option"
    exit 1
fi

if [ -z "${tenant_token}" ]; then
    echo "Sorry, but you need to provide a tenant token using the '-t/--tenant-token' option"
    exit 1
fi

mkdir -p ${output_dir}/etc/mender
cat <<- EOF > ${output_dir}/etc/mender/mender.conf
{
  "InventoryPollIntervalSeconds": 5,
  "RetryPollIntervalSeconds": 30,
  "ServerURL": "https://hosted.mender.io/",
  "TenantToken": "${tenant_token}",
  "UpdatePollIntervalSeconds": 5
}
EOF

echo "Configuration file for using Hosted Mender written to: ${output_dir}/etc/mender"
