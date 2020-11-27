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

source modules/log.sh

# Direct download of a deb package from an APT repository
#
#  $1 - Download directory
#  $2 - APT repository url
#  $3 - Debian architecture
#  $4 - Debian Distribution
#  $5 - Package name
#  $6 - Package version (optional, default "latest")
#  $7 - Component (optional, default "main")
#
# @return - Filename of the downloaded package
#
function deb_from_repo_get () {
  if [[ $# -lt 5 || $# -gt 7 ]]; then
    log_fatal "deb_from_repo_get() requires 5 or 6 arguments"
  fi
  local -r download_dir="${1}"
  local -r repo_url="${2}"
  local -r architecture="${3}"
  local -r distribution="${4}"
  local -r package="${5}"
  local -r version="${6:-latest}"
  local -r component="${7:-main}"

  local deb_package_path=""
  if [ "${version}" = "latest" ]; then
    # If latest, fetch and parse the packages list of the given distribution to find the latest version
    local -r packages_url="${repo_url}/dists/${distribution}/${component}/binary-${architecture}/Packages"
    run_and_log_cmd "wget -Nq ${packages_url} -P /tmp"

    deb_package_path=$(grep Filename /tmp/Packages | grep ${package}_ | grep ${architecture} | tail -n1 | sed 's/Filename: //')
    if [ -z "${deb_package_path}" ]; then
      log_fatal "Couldn't fine package ${package} in ${packages_url}"
    fi
  else
    # Else, try to download the specified version (ignoring distribution)
    local -l initial="$(echo $package | head -c 1)"
    deb_package_path="pool/${component}/${initial}/${package}/${package}_${version}_${architecture}.deb"
  fi

  local -r filename=$(basename $deb_package_path)
  run_and_log_cmd "wget -Nq ${repo_url}/${deb_package_path} -P ${download_dir}"

  rm -f /tmp/Packages
  log_info "Successfully downloaded ${filename}"
  echo ${filename}
}
