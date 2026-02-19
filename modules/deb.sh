# Copyright 2025 Northern.tech AS
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

deb_chroot_set_up=0

# Install deb package(s) using a chroot
#
#  $1 - Dest directory
#  $@ - Deb package(s)
#
function deb_install_packages() {
    if [[ $# -lt 2 ]]; then
        log_fatal "deb_install_packages() requires at least 2 arguments"
    fi

    local -r dest_dir="$(pwd)/${1}"
    shift

    local -a deb_packages=()
    for pkg in "$@"; do
        deb_packages+=("$(pwd)/${pkg}")
    done

    (   
        # Mender postinstall script uses this variable.
        export DEVICE_TYPE="${MENDER_DEVICE_TYPE}"
        # This may be called from a larger script that manages the chroot
        # setup/teardown by using deb_prepare/cleanup or from a place where the
        # chroot is supposed to be set up and torn down for a single package
        # installation.
        if [[ $deb_chroot_set_up -eq 1 ]]; then
            deb_install_packages_in_chroot "$dest_dir" "${deb_packages[@]}"
        else
            run_with_chroot_setup "$dest_dir" deb_install_packages_in_chroot "$dest_dir" "${deb_packages[@]}"
        fi
    )
}

function deb_install_packages_in_chroot() {
    if [[ $# -lt 2 ]]; then
        log_fatal "deb_install_packages_in_chroot() requires at least 2 arguments"
    fi

    local -r dest_dir="${1}"
    shift
    local -a deb_packages=("$@")

    # Copy packages to somewhere reachable from within the chroot.
    local -a tmp_packages=()
    for deb_package in "${deb_packages[@]}"; do
        cp "$deb_package" "$dest_dir/tmp/"
        tmp_packages+=("/tmp/$(basename "$deb_package")")
    done

    local ret=0
    local dpkg_output
    dpkg_output=$(run_in_chroot_and_log_cmd_with_output_noexit "$dest_dir" "env \
        DEBIAN_FRONTEND=noninteractive \
        DEVICE_TYPE=${MENDER_DEVICE_TYPE} \
        dpkg --install ${tmp_packages[*]}") || ret=$?

    # Clean up copied packages
    for deb_package in "${deb_packages[@]}"; do
        rm -f "$dest_dir/tmp/$(basename "$deb_package")"
    done
    case $ret in
        0)
            # Success
            ;;
        1)
            # Check if this is actually a dependency problem that can be fixed with apt
            if ! echo "$dpkg_output" | grep -qE "(dependency problems|depends on.*not installed)"; then
                log_error "dpkg failed but not due to missing dependencies:"
                log_fatal "$dpkg_output"
            fi

            log_info "Installing dependencies for packages"

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

            # Verify that all packages were installed. If we install input packages with dependencies not available in the APT repositories,
            # `apt --fix-broken install` will remove the packages and exit with 0
            for deb_package in "${deb_packages[@]}"; do
                local pkg_name="$(dpkg-deb -f "$deb_package" Package)"
                # From dpkg-query man page: db:Status-Status contains the package status word
                local status=$(run_in_chroot_and_log_cmd_with_output "$dest_dir" "dpkg-query -W -f='\${db:Status-Status}' $pkg_name")
                if [[ "$status" != "installed" ]]; then
                    log_error "Package "$deb_package" ("$pkg_name") was not installed. This typically means some of its dependencies are not available in the configured APT repositories."
                    log_fatal "$(dpkg --field "$deb_package")"
                fi
                log_info ""$deb_package" ("$pkg_name") installed successfully"
            done
            ;;
        *)
            # Other return codes are not expected.
            log_fatal "dpkg returned unexpected return code: $ret"
            ;;
    esac
}

#  Do preparations before deb operations in the image
#  $1 - image root directory
function deb_prepare() {
    local -r root_dir="${1}"

    chroot_setup "$root_dir" && deb_chroot_set_up=1
    if [[ -f "${root_dir}/etc/apt/sources.list.d/mender.list" ]]; then
        cp -a "${root_dir}/etc/apt/sources.list.d/mender.list"{,.orig}
    fi
    if [[ -f "${root_dir}/etc/apt/trusted.gpg.d/mender.asc" ]]; then
        cp -a "${root_dir}/etc/apt/trusted.gpg.d/mender.asc"{,.orig}
    fi
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
        wget --quiet -O "work/rootfs/etc/apt/trusted.gpg.d/mender.asc" "$MENDER_APT_KEY_URL"
    fi
    if ! gpg --quiet --show-keys --with-fingerprint --with-colons "work/rootfs/etc/apt/trusted.gpg.d/mender.asc" \
                                                                                                         | grep -qE "fpr:+$MENDER_APT_KEY_FP:"; then
        log_fatal "APT key fingerprint mismatch, cannot continue"
    fi

    local deb_arch=$(probe_debian_arch_name)
    local deb_distro=$(probe_debian_distro_name)
    local deb_codename=$(probe_debian_distro_codename)
    local -r list_file="work/rootfs/etc/apt/sources.list.d/mender.list"
    touch "$list_file"
    if ! grep -qF "$MENDER_APT_REPO_URL $deb_distro/$deb_codename/$variant" "$list_file"; then
        echo "deb [arch=${deb_arch}] $MENDER_APT_REPO_URL $deb_distro/$deb_codename/$variant main" >> "$list_file"
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
    if [[ $# -ne 2 ]]; then
        log_fatal "$FUNCNAME requires 2 arguments"
    fi
    local -r pkg_name="$1"
    local -r pkg_ver="$2"

    local ver_filter
    local variant_filter="stable"
    if [[ "$pkg_ver" = "latest" ]]; then
        ver_filter='.*'
    elif [[ "$pkg_ver" = "master" ]] || [[ "$pkg_ver" = "main" ]]; then
        ver_filter='.*'
        variant_filter="experimental"
    else
        # particular version like "5", "5.1" or even "5.2.1", we need to replace
        # all the '.' with '\.' to convert the version into an equivalent
        # regular expression and make sure that an incomplete version like "5"
        # or "5.1" only matches compatible versions, i.e. having dot after the
        # specified version prefix.
        if [[ "${pkg_ver}" =~ ^[0-9](\.[0-9])?$ ]]; then
            ver_filter="${pkg_ver//\./\\.}\."
        else
            ver_filter="${pkg_ver//\./\\.}"
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
        apt --assume-yes --fix-broken --no-remove install $1"
}

#  Install binary files of a deb package into work/deb-packages from a local directory
#  $1 - Directory path
#
function deb_get_and_install_input_package() {
    if ! [[ $# -eq 1 ]]; then
        log_fatal "deb_get_and_install_input_package() requires 1 argument"
    fi

    local -r package_path="$1"
    local -a packages=("${package_path}"/*.deb)

    # Check if we have any packages
    if [[ ! -e "${packages[0]}" ]]; then
        log_warn "No .deb packages found in ${package_path}"
        return
    fi

    log_info "Installing ${#packages[@]} package(s) from ${package_path}"

    # Install all packages at once - dpkg handles dependencies automatically
    deb_install_packages "work/rootfs/" "${packages[@]}"
}

function deb_cleanup() {
    local -r dest_dir="$(pwd)/${1}"
    if [[ $deb_chroot_set_up -eq 0 ]]; then
        # Already cleaned up, this is not the first call of this function since
        # the last deb_prepare().
        return
    fi

    chroot_teardown "$dest_dir" && deb_chroot_set_up=0
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
}
