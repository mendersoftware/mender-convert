# Copyright 2024 Northern.tech AS
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

source modules/chroot.sh
source modules/log.sh
source modules/probe.sh

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
        log_fatal "deb_from_repo_dist_get() requires 5 arguments. 6th is optional"
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

# Download a deb package directly from the pool of an APT repository
#
#  $1 - Download directory
#  $2 - APT repository url
#  $3 - Debian architecture
#  $4 - Package recipe
#  $5 - Package name
#  $6 - Package version
#
# @return - Filename of the downloaded package
#
function deb_from_repo_pool_get()  {
    if [[ $# -ne 6 ]]; then
        log_fatal "deb_from_repo_pool_get() requires 6 arguments"
    fi
    local -r download_dir="${1}"
    local -r repo_url="${2}"
    local -r architecture="${3}"
    local -r recipe="${4}"
    local -r package="${5}"
    local -r version="${6}"

    local -r initial="$(echo $recipe | head -c 1)"
    local -r deb_package_path="pool/main/${initial}/${recipe}/${package}_${version}_${architecture}.deb"

    local -r filename=$(basename $deb_package_path)
    local -r deb_package_url=$(echo ${repo_url}/${deb_package_path} | sed 's/+/%2B/g')
    run_and_log_cmd_noexit "wget -Nq ${deb_package_url} -P ${download_dir}"
    local exit_code=$?

    rm -f /tmp/Packages
    if [[ ${exit_code} -ne 0 ]]; then
        log_warn "Could not download ${filename} from ${deb_package_url}"
        echo ""
    else
        log_info "Successfully downloaded ${filename} from ${deb_package_url}"
        echo ${filename}
    fi
}

# Install a deb package using a chroot
#
#  $1 - Deb package
#  $2 - Dest directory
#
function deb_install_package() {
    if [[ $# -ne 2 ]]; then
        log_fatal "deb_install_package() requires 2 arguments"
    fi
    local -r deb_package="$(pwd)/${1}"
    local -r dest_dir="$(pwd)/${2}"

    (   
        # Mender postinstall script uses this variable.
        export DEVICE_TYPE="${MENDER_DEVICE_TYPE}"

        run_with_chroot_setup "$dest_dir" deb_install_package_in_chroot "$@"
    )
}

function deb_install_package_in_chroot() {
    if [[ $# -ne 2 ]]; then
        log_fatal "deb_install_package() requires 2 arguments"
    fi
    local -r deb_package="$(pwd)/${1}"
    local -r dest_dir="$(pwd)/${2}"

    # Copy package to somewhere reachable from within the chroot.
    cp "$deb_package" "$dest_dir/tmp/"

    local ret=0
    run_in_chroot_and_log_cmd_noexit "$dest_dir" "env \
        DEBIAN_FRONTEND=noninteractive \
        DEVICE_TYPE=${MENDER_DEVICE_TYPE} \
        dpkg --install \"/tmp/$(basename "$deb_package")\"" || ret=$?
    rm -f "$dest_dir/tmp/$(basename "$deb_package")"
    case $ret in
        0)
            # Success
            ;;
        1)
            log_info "Installing dependencies for $deb_package"

            # Try to avoid excessive repository pulling. Only update if older than one day.
            if [ ! -e "$dest_dir/var/cache/apt/pkgcache.bin" ] || [ $(date -r "$dest_dir/var/cache/apt/pkgcache.bin" +%s) -lt $(date -d 'today - 1 day' +%s) ]; then
                if [ ! -e "$dest_dir/var/cache/apt/pkgcache.bin" ]; then
                    # If the package cache didn't originally exist, delete it afterwards so we don't
                    # increase space usage.
                    mkdir -p "$dest_dir/var/cache/apt"
                    touch "$dest_dir/var/cache/apt/mender-convert.remove-apt-cache"
                fi

                run_in_chroot_and_log_cmd "$dest_dir" "apt update"
            fi

            # It's ok if dpkg fails, as long as a subsequent "apt install" succeeds. This happens
            # when we try to install a package and its dependencies are not immediately
            # satisfied. Then we need to run apt afterwards to remedy the problem.
            run_in_chroot_and_log_cmd "$dest_dir" "env \
                DEBIAN_FRONTEND=noninteractive \
                DEVICE_TYPE=${MENDER_DEVICE_TYPE} \
                apt --fix-broken --assume-yes install"
            ;;
        *)
            # Other return codes are not expected.
            log_error "dpkg returned unexpected return code: $ret"
            ;;
    esac
}

# Download and install the binary files of a deb package into work/deb-packages
# This is the main entry point of deb.sh
# Defines variable DEB_NAME with the actual filename installed
#
#  $1 - Package recipe
#  $2 - Package name
#  $3 - Package version
#  $4 - Arch independent (optional, default "false")
#
function deb_get_and_install_package() {
    if ! [[ $# -eq 3 || $# -eq 4 ]]; then
        log_fatal "deb_get_and_install_package() requires 3 or 4 arguments"
    fi
    local recipe="$1"
    local package="$2"
    local version="$3"
    local arch_indep="${4:-false}"

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
        DEB_NAME=$(deb_from_repo_pool_get "work/deb-packages" ${MENDER_APT_REPO_URL} ${pool_arch} "${recipe}" "${package}" "${version}${debian_version}")
        if [[ -z "${DEB_NAME}" ]]; then
            local debian_version_fallback="-1"
            DEB_NAME=$(deb_from_repo_pool_get "work/deb-packages" ${MENDER_APT_REPO_URL} ${pool_arch} "${recipe}" "${package}" "${version}${debian_version_fallback}")
            if [[ -z "${DEB_NAME}" ]]; then
                log_fatal "Specified version for ${package} cannot be found, tried ${version}${debian_version} and ${version}${debian_version_fallback}"
            fi
        fi
    fi
    deb_install_package "work/deb-packages/${DEB_NAME}" "work/rootfs/"
}

#  Install binary files of a deb package into work/deb-packages from a local directory
#  $1 - Directory path
#
function deb_get_and_install_input_package() {
    if ! [[ $# -eq 1 ]]; then
        log_fatal "deb_get_and_install_input_package() requires 1 argument"
    fi

    local -r package_path="$1"
    local -r package_order_file="${package_path}/order"
    local -a order=()

    # Install packages by set order if file exists
    if [ -f "${package_order_file}" ]; then
        while read package; do
            order+=("${package_path}/${package}")
        done < "$package_order_file"
    fi

    # Add the rest of the packages to the order array
    while read -r -d $'\0' package; do
        # Match `order packages` with `package` to
        # to avoid duplication in the array
        if ! [[ " ${order[@]} " =~ " ${package} " ]]; then
            order+=("$package")
        fi
    done < <(find "${package_path}" -name "*.deb" -type f -print0)

    # Install packages
    for package in "${order[@]}"; do
        if ! [ -e "${package}" ]; then
            log_fatal "Debian package '${package}' does not exist"
            continue
        fi
        log_info "Installing ${package}"
        deb_install_package "${package}" "work/rootfs/"
    done
}

function deb_cleanup_package_cache() {
    local -r dest_dir="$(pwd)/${1}"
    if [ -e "$dest_dir/var/cache/apt/mender-convert.remove-apt-cache" ]; then
        rm -rf "$dest_dir/var/cache/apt"
    fi
}
