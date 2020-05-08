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

#
# Parse the filename from the zipped output
#
# $1 - Zip archive path
#
# @return - Name of the img contained in the archive
#
function zip_get_imgname () {
  if [[ $# -ne 1 ]]; then
    log_fatal "zip_get_imgname requires one argument"
  fi
  local -r disk_image="${1}"
  # Assert that the archive holds only one file
  nfiles="$(unzip -l ${disk_image} | awk '{nfiles=$2} END {print nfiles}')"
  [[ "$nfiles" -ne 1 ]] && log_fatal "Zip archive has more than one file. Needs to be unzipped by a human. nfiles: $nfiles"
  local -r filename="$(unzip -lq ${disk_image} | awk 'NR==3 {filename=$NF} END {print filename}')"
  [[ ${filename} == *.img ]] || log_fatal "no img file found in the zip archive ${disk_image}."
  echo "$(basename ${filename})"
}
