#!/bin/bash
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

# Exit if any command exits with a non-zero exit status.
set -o errexit

tenant_token=""
output_dir=""
region="us"
while (("$#")); do
    case "$1" in
        -t | --tenant-token)
            tenant_token="${2}"
            shift 2
            ;;
        -o | --output-dir)
            output_dir="${2}"
            shift 2
            ;;
        -r | --region)
            region="${2}"
            shift 2
            ;;
        *)
            echo "Sorry but the provided option is not supported: $1"
            echo "Usage:  $(basename $0) [--region 'us','eu'] --output-dir ./input/rootfs_overlay_demo --tenant-token <paste your token here>"
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

if [ -e ${output_dir} ]; then
     sudo chown -R $(id -u) ${output_dir}
     sudo chgrp -R $(id -g) ${output_dir}
fi

# check lowercase or uppercase region
if [ "${region}" = "eu" || "${region}" = "EU" ]; then
    region_appendix="eu."
elif [ "${region}" = "us" || "${region}" = "US" ]; then
    region_appendix=""
else
    echo "Sorry, but the provided region is not supported: ${region} (only 'eu' and 'us' are accepted)"
    exit 1
fi

mkdir -p ${output_dir}/etc/mender
cat <<- EOF > ${output_dir}/etc/mender/mender.conf
{
  "ServerURL": "https://${region_appendix}hosted.mender.io/",
  "TenantToken": "${tenant_token}"
}
EOF

sudo chown -R 0 ${output_dir}
sudo chgrp -R 0 ${output_dir}

echo "Configuration file for using Hosted Mender written to: ${output_dir}/etc/mender/mender.conf"
