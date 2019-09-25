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

# This must be an absolute path, as users might call the log functions
# from sub-directories
log_file="${PWD}/work/convert.log"

# Log the given message at the given level.
function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local -r script_name="$(basename "$0")"
  >&2 echo -e "${timestamp} [${level}] [$script_name] ${message}" | tee -a ${log_file}
}

function local_log_debug {
  local -r level="DEBUG"
  local -r message="$1"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local -r script_name="$(basename "$0")"
  echo -e "${timestamp} [${level}] [$script_name] ${message}" >> ${log_file}
}

# Log the given message at DEBUG level.
function log_debug {
  local -r message="$1"
  local_log_debug "$message"
}

# Log the given message at INFO level.
function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

# Log the given message at WARN level.
function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

# Log the given message at ERROR level.
function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

# Log the given message at FATAL level.
function log_fatal {
  local -r message="$1"
  log "FATAL" "$message"
  exit 1
}
