#!/usr/bin/env bash
#
# Copyright 2022 Northern.tech AS
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

# Run a command, capture and log output, and exit on non-zero return code
#
#  $1 - command to run
function run_and_log_cmd() {
    local -r cmd="${1}"
    local -r position="(${BASH_SOURCE[1]}:${BASH_LINENO[0]}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }"
    local exit_code=0
    output="$({ eval ${cmd}; } 2>&1)" || exit_code=$?
    local log_msg="Running: ${position} \n\r\n\r\t${cmd}"
    if [[ "${output}" != "" ]]; then
        log_msg="${log_msg}\n\t${output}\n"
    fi
    log_debug "${log_msg}"
    if [[ ${exit_code} -ne 0 ]]; then
        exit ${exit_code}
    fi
}

# Run a command, capture and log output, and return the command's return code
#
#  $1 - command to run
function run_and_log_cmd_noexit() {
    local -r cmd="${1}"
    local -r position="(${BASH_SOURCE[1]}:${BASH_LINENO[0]}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }"
    local exit_code=0
    output="$({ eval ${cmd}; } 2>&1)" || exit_code=$?
    local log_msg="Running: ${position} \n\r\n\r\t${cmd}"
    if [[ "${output}" != "" ]]; then
        log_msg="${log_msg}\n\t${output}\n"
    fi
    log_debug "${log_msg}"
    return ${exit_code}
}
