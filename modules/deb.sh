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

source modules/log.sh
source modules/probe.sh .

# Download of latest deb package for the given distribution of an APT repository
#
#  $1 - Download directory
#  $2 - APT repository url
#  $3 - Debian architecture
#  $4 - Debian Distribution
#  $5 - Package name
#  $6 - Component (optional, default "main")
#
# @return - Filename of the downloaded package
#
function deb_from_repo_dist_get()  {
    if [[ $# -lt 5 || $# -gt 7 ]]; then
        log_fatal "deb_from_repo_dist_get() requires 5 arguments"
    fi
    local -r download_dir="${1}"
    local -r repo_url="${2}"
    local -r architecture="${3}"
    local -r distribution="${4}"
    local -r package="${5}"
    local -r component="${6:-main}"

    # Fetch and parse the packages list of the given distribution to find the latest version
    local -r packages_url="${repo_url}/dists/${distribution}/${component}/binary-${architecture}/Packages"
    run_and_log_cmd "wget -Nq ${packages_url} -P /tmp"

    local -r deb_package_path=$(grep Filename /tmp/Packages | grep ${package}_ | tail -n1 | sed 's/Filename: //')
    if [ -z "${deb_package_path}" ]; then
        log_fatal "Couldn't find package ${package} in ${packages_url}"
    fi

    local -r filename=$(basename $deb_package_path)
    local -r deb_package_url=$(echo ${repo_url}/${deb_package_path} | sed 's/+/%2B/g')
    run_and_log_cmd "wget -Nq ${deb_package_url} -P ${download_dir}"

    rm -f /tmp/Packages
    log_info "Successfully downloaded ${filename}"
    echo ${filename}
}

# Download a deb package direcrly from the pool of an APT repository
#
#  $1 - Download directory
#  $2 - APT repository url
#  $3 - Debian architecture
#  $4 - Package name
#  $5 - Package version
#  $6 - Component (optional, default "main")
#
# @return - Filename of the downloaded package
#
function deb_from_repo_pool_get()  {
    if [[ $# -ne 5 ]]; then
        log_fatal "deb_from_repo_pool_get() requires 5 arguments"
    fi
    local -r download_dir="${1}"
    local -r repo_url="${2}"
    local -r architecture="${3}"
    local -r package="${4}"
    local -r version="${5}"
    local -r component="${6:-main}"

    local -r initial="$(echo $package | head -c 1)"
    local -r deb_package_path="pool/${component}/${initial}/${package}/${package}_${version}_${architecture}.deb"

    local -r filename=$(basename $deb_package_path)
    local -r deb_package_url=$(echo ${repo_url}/${deb_package_path} | sed 's/+/%2B/g')
    run_and_log_cmd_noexit "wget -Nq ${deb_package_url} -P ${download_dir}"
    local exit_code=$?

    rm -f /tmp/Packages
    if [[ ${exit_code} -ne 0 ]]; then
        log_warn "Could not download ${filename}"
        echo ""
    else
        log_info "Successfully downloaded ${filename}"
        echo ${filename}
    fi
}

# Extract the binary files of a deb package into a directory
#
#  $1 - Deb package
#  $2 - Dest directory
#
function deb_extract_package()  {
    if [[ $# -ne 2 ]]; then
        log_fatal "deb_extract_package() requires 2 arguments"
    fi
    local -r deb_package="$(pwd)/${1}"
    local -r dest_dir="$(pwd)/${2}"

    local -r extract_dir=$(mktemp -d)
    cd ${extract_dir}
    run_and_log_cmd "ar -xv ${deb_package}"
    mkdir -p files
    run_and_log_cmd "sudo tar xJf data.tar.xz -C files"
    cd - > /dev/null 2>&1

    run_and_log_cmd "sudo rsync --archive --keep-dirlinks --verbose ${extract_dir}/files/ ${dest_dir}"

    log_info "Successfully installed $(basename ${deb_package}) into ${dest_dir}"
}

# Download and install the binary files of a deb package into work/deb-packages
# This is the main entry point of deb.sh
# Defines variable DEB_NAME with the actual filename installed
#
#  $1 - Package name
#  $2 - Package version
#  $3 - Arch independent (optional, default "false")
#
function deb_get_and_install_pacakge() {
    if ! [[ $# -eq 2 || $# -eq 3 ]]; then
        log_fatal "deb_get_and_install_pacakge() requires 2 or 3 arguments"
    fi
    local package="$1"
    local version="$2"
    local arch_indep="${3:-false}"

    mkdir -p work/deb-packages

    local deb_arch=$(probe_debian_arch_name)
    local deb_distro=$(probe_debian_distro_name)
    local deb_codename=$(probe_debian_distro_codename)
    if ! [[ "$MENDER_APT_REPO_DISTS" == *"${deb_distro}/${deb_codename}"* ]]; then
        deb_distro="debian"
        deb_codename="buster"
    fi

    DEB_NAME=""
    if [ "${version}" = "latest" ]; then
        DEB_NAME=$(deb_from_repo_dist_get "work/deb-packages" ${MENDER_APT_REPO_URL} ${deb_arch} "${deb_distro}/${deb_codename}/stable" "${package}")
    elif [ "${version}" = "master" ]; then
        DEB_NAME=$(deb_from_repo_dist_get "work/deb-packages" ${MENDER_APT_REPO_URL} ${deb_arch} "${deb_distro}/${deb_codename}/experimental" "${package}")
    else
        # On direct downloads, the architecture suffix will be "all" for arch independent packages
        local pool_arch=""
        if [[ "$arch_indep" == "true" ]]; then
            pool_arch="all"
        else
            pool_arch="$deb_arch"
        fi

        local debian_version="-1+${deb_distro}+${deb_codename}"
        DEB_NAME=$(deb_from_repo_pool_get "work/deb-packages" ${MENDER_APT_REPO_URL} ${pool_arch} "${package}" "${version}${debian_version}")
        if [[ -z "${DEB_NAME}" ]]; then
            local debian_version_fallback="-1"
            DEB_NAME=$(deb_from_repo_pool_get "work/deb-packages" ${MENDER_APT_REPO_URL} ${pool_arch} "${package}" "${version}${debian_version_fallback}")
            if [[ -z "${DEB_NAME}" ]]; then
                log_fatal "Specified version for ${package} cannot be found, tried ${version}${debian_version} and ${version}${debian_version_fallback}"
            fi
        fi
    fi
    deb_extract_package "work/deb-packages/${DEB_NAME}" "work/rootfs/"
}
