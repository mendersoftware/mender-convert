#
# Copyright 2021 Northern.tech AS
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

# Init tests configuration file
#
function testscfg_init () {
  rm -f work/testscfg.tmp
  touch work/testscfg.tmp
}

# Add key/value to tests configuration file
#
#  $1 - key
#  $2 - value
#
function testscfg_add () {
  if [[ $# -ne 2 ]]; then
    log_fatal "testscfg_add() requires 2 arguments"
  fi
  local -r key="${1}"
  local -r value="${2}"
  echo "${key}=\"${value}\"" >> work/testscfg.tmp
}

# Save tests configuration file into the given location
#
#  $1 - Filename
#
function testscfg_save () {
  if [[ $# -ne 1 ]]; then
    log_fatal "testscfg_save() requires 1 argument"
  fi
  local -r filename="${1}"
  cp work/testscfg.tmp ${filename}
}
