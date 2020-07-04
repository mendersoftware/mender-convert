#!/usr/bin/env bash
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

# Read in the array of config files to process
read -a configs <<< "${@}"
for config in "${configs[@]}"; do
  log_info "Using configuration file: ${config}"
  source "${config}"
done


# Fine grained partition variables override device/number variables where applicable
disk_override_partition_variable "MENDER_BOOT_PART_NUMBER" "${MENDER_BOOT_PART}"
disk_override_partition_variable "MENDER_ROOTFS_PART_A_NUMBER" "${MENDER_ROOTFS_PART_A}"
disk_override_partition_variable "MENDER_ROOTFS_PART_B_NUMBER" "${MENDER_ROOTFS_PART_B}"
disk_override_partition_variable "MENDER_DATA_PART_NUMBER" "${MENDER_DATA_PART}"
