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

#  Do preparations before deb operations in the image
#  $1 - image root directory
function deb_prepare() {
    local -r root_dir="${1}"
    if [[ -f "${root_dir}/etc/apt/sources.list.d/mender.list" ]]; then
        cp -a "${root_dir}/etc/apt/sources.list.d/mender.list"{,.orig}
    fi
    if [[ -f "${root_dir}/etc/apt/trusted.gpg.d/mender.asc" ]]; then
        cp -a "${root_dir}/etc/apt/trusted.gpg.d/mender.asc"{,.orig}
    fi
    if [[ -f "${root_dir}/etc/hosts" ]]; then
        cp -a "${root_dir}/etc/hosts"{,.orig}
    fi

    for host in $(sed -r -e '\@^deb https?://@!d' -e 's@.*https?://([-a-z.]+)/.*@\1@' "${root_dir}/etc/apt/sources.list" | sort | uniq); do
        echo -n "$host " >> "${root_dir}/etc/hosts"
        host $host | sed -r -e '/has address/!d' -e 's/.*has address (.*)/\1/' | head -n1 >> "${root_dir}/etc/hosts"
    done
}

#  Make sure the given variant (stable/experimental) of the APT repository is
#  enabled.
#  $1 - Repository variant ("stable" (default) or "experimental")
function deb_ensure_repo_enabled() {
    local variant="stable"
    if [[ $# -eq 1 ]]; then
        variant="$1"
    fi

    if ! [[ -f "work/rootfs/etc/apt/trusted.gpg.d/mender.asc" ]]; then
        mkdir -p "work/rootfs/etc/apt/trusted.gpg.d/"
        wget -O "work/rootfs/etc/apt/trusted.gpg.d/mender.asc" "$MENDER_APT_KEY_URL"
    fi
    if ! gpg --show-keys --with-fingerprint --with-colons "work/rootfs/etc/apt/trusted.gpg.d/mender.asc" \
                                                                                                         | grep -qE "fpr:+$MENDER_APT_KEY_FP:"; then
        log_fatal "APT key fingerprint mismatch, cannot continue"
    fi

    local deb_arch=$(probe_debian_arch_name)
    local deb_distro=$(probe_debian_distro_name)
    local deb_codename=$(probe_debian_distro_codename)
    local -r list_file="work/rootfs/etc/apt/sources.list.d/mender.list"
    touch "$list_file"
    if ! grep -qF "$MENDER_APT_REPO_URL $deb_distro/$deb_codename/$variant" "$list_file"; then
        log_info "Adding source 'deb [arch=${deb_arch}] $MENDER_APT_REPO_URL $deb_distro/$deb_codename/$variant main'"
        echo "deb [arch=${deb_arch}] $MENDER_APT_REPO_URL $deb_distro/$deb_codename/$variant main" >> "$list_file"

        local -r repo_host=$(echo $MENDER_APT_REPO_URL | sed -r 's@.*https?://([-a-z.]+)/.*@\1@')
        echo -n "$repo_host " >> "work/rootfs/etc/hosts"
        host $repo_host | sed -r -e '/has address/!d' -e 's/.*has address (.*)/\1/' | head -n1 >> "work/rootfs/etc/hosts"

        cat "work/rootfs/etc/hosts"
        apt-get install -y iputils-ping
        cp /bin/ping work/rootfs/bin/
        cp /bin/ping4 work/rootfs/bin/
        cp /bin/ping6 work/rootfs/bin/
        cp -a /lib work/rootfs/
        cp -a /usr/lib work/rootfs/usr/
        run_in_chroot_and_log_cmd "work/rootfs/" "ping -c4 8.8.8.8" || echo;
        run_in_chroot_and_log_cmd "work/rootfs/" "apt-get update"
        if [[ $? != 0 ]]; then
            log_fatal "Failed to fetch repository metadata, cannot continue"
        fi
    fi
}

#  Get the exact package (as name=version) for the given spec from the APT repository
#  $1 - Package name
#  $2 - Package version
function deb_get_repo_package() {
    if ! [[ $# -eq 2 ]]; then
        log_fatal "deb_get_repo_package() requires 2 arguments"
    fi
    local -r pkg_name="$1"
    local -r pkg_ver="$2"

    local ver_filter
    local variant_filter="stable"
    if [[ "$pkg_ver" = "latest" ]]; then
        ver_filter='.*'
    elif [[ "$pkg_ver" = "master" ]]; then
        ver_filter='.*'
        variant_filter="experimental"
    else
        # particular version like "5", "5.1" or even "5.2.1", we need to replace
        # all the '.' with '\.' to convert the version into an equivalent
        # regular expression and make sure that an incomplete version like "5"
        # or "5.1" only matches compatible versions, i.e. having dot after the
        # specified version prefix.
        if [[ "${pkg_ver}" =~ '^[0-9](\.[0-9])$' ]]; then
            ver_filter="${pkg_ver//\./\\./}\."
        else
            ver_filter="${pkg_ver//\./\\./}"
        fi
    fi

    # `apt-cache madison` output is something like this:
    # mender-client4 | 5.0.2-1+debian+bookworm | https://downloads.mender.io/repos/device-components debian/bookworm/stable/main arm64 Packages
    # mender-client4 | 5.0.1-1+debian+bookworm | https://downloads.mender.io/repos/device-components debian/bookworm/stable/main arm64 Packages
    # mender-client4 | 4.0.7-1+debian+bookworm | https://downloads.mender.io/repos/device-components debian/bookworm/stable/main arm64 Packages
    local -r chosen_ver=$(
        run_in_chroot_and_log_cmd_with_output "work/rootfs/" "apt-cache madison $pkg_name" \
                                                                               | grep -F "$MENDER_APT_REPO_URL" | grep -F "$variant_filter" | cut -d\| -f2 | grep " *$ver_filter" | tr -d ' ' \
                                                                                                                     | sort -rV | head -n1
    )
    if [[ -z "$chosen_ver" ]]; then
        log_fatal "Cannot choose exact version for package $pkg_name $pkg_ver from the APT repository"
    fi
    log_debug "Selected $pkg_name=$chosen_ver"
    echo "$pkg_name=$chosen_ver"
}

#  Install the given packages from the APT repository
#  $1 - Packages to install (space-separated name[=version] values)
function deb_install_repo_packages() {
    run_in_chroot_and_log_cmd "work/rootfs/" "env \
        DEBIAN_FRONTEND=noninteractive \
        DEVICE_TYPE=${MENDER_DEVICE_TYPE} \
        apt -y --fix-broken install $1"
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

function deb_cleanup() {
    local -r dest_dir="$(pwd)/${1}"
    if [ -e "$dest_dir/var/cache/apt/mender-convert.remove-apt-cache" ]; then
        rm -rf "$dest_dir/var/cache/apt"
    fi
    rm -f "${dest_dir}/etc/apt/sources.list.d/mender.list"
    if [[ -f "${dest_dir}/etc/apt/sources.list.d/mender.list.orig" ]]; then
        mv "${dest_dir}/etc/apt/sources.list.d/mender.list"{.orig,}
    fi
    rm -f "${dest_dir}/etc/apt/trusted.gpg.d/mender.asc"
    if [[ -f "${dest_dir}/etc/apt/trusted.gpg.d/mender.asc.orig" ]]; then
        mv "${dest_dir}/etc/apt/trusted.gpg.d/mender.asc"{.orig,}
    fi
    rm -f "${dest_dir}/etc/hosts"
    if [[ -f "${dest_dir}/etc/hosts.orig" ]]; then
        mv "${dest_dir}/etc/hosts"{.orig,}
    fi
}
