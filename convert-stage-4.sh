#!/bin/bash

set -e

show_help() {
  cat << EOF

Mender executables, service and configuration files installer.

Usage: $0 [options]

    Options: [-m|--mender-disk-image | -g|--mender-client | -a|--artifact-name |
              -d|--device-type | -n|--demo | -p|--demo-host-ip | -u| --server-url |
              -c|--server-cert -t| --tenant-token -k|--keep -h|--help]

        --mender-disk-image - Mender raw disk image
        --mender-client     - Mender client binary file
        --artifact-name     - artifact info
        --device-type       - target device type identification
        --demo              - Configure image using demo parameters
        --demo-host-ip      - Mender demo server IP address
        --server-url        - Mender production server url
        --server-cert       - Mender server certificate
        --tenant-token      - Mender tenant token
        --keep              - Keep intermediate files in output directory
        --help              - Show help and exit

    For examples, see: ./mender-convert --help

EOF
  exit 1
}

jq_inplace() {
  jq_args="$1"
  dest_file="$2"
  sudo sh -c -e "jq \"${jq_args}\" ${dest_file} > ${dest_file}.tmp && mv ${dest_file}.tmp ${dest_file}"
}

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
output_dir=${tool_dir}/output

meta_mender_repo="https://raw.githubusercontent.com/mendersoftware/meta-mender"
meta_mender_revision="thud"

mender_dir=$output_dir/mender
device_type=
artifact_name=
# Mender demo server IP address.
demo_host_ip=
# Mender production server url passed as CLI option.
server_url=
# Mender production certificate.
server_cert=
# Mender tenant token passed as CLI option.
tenant_token=
# Mender tenant token.
mender_tenant_token="dummy"

declare -a mender_disk_mappings

append_rootfs_configuration() {
  local conffile=$1

  local rootfsparta="/dev/mmcblk0p2"
  local rootfspartb="/dev/mmcblk0p3"

  if [ "$device_type" == "qemux86_64" ]; then
    rootfsparta="/dev/hda2"
    rootfspartb="/dev/hda3"
  fi

  jq_inplace '.RootfsPartA = \"'$rootfsparta'\" | .RootfsPartB = \"'$rootfspartb'\"' ${conffile}
}

create_client_files() {
  cat <<- EOF > $mender_dir/device_type
	device_type=${device_type}
	EOF

  case "$device_type" in
    "beaglebone" | "qemux86_64")
      cat <<- EOF > $mender_dir/fw_env.config
	/dev/mmcblk0 0x800000 0x20000
	/dev/mmcblk0 0x1000000 0x20000
	EOF
      ;;
    "raspberrypi3"|"raspberrypi0w")
      cat <<- EOF > $mender_dir/fw_env.config
	/dev/mmcblk0 0x400000 0x4000
	/dev/mmcblk0 0x800000 0x4000
	EOF
      ;;
  esac
}

get_mender_files_from_upstream() {

  mkdir -p $mender_dir

  log "\tDownloading demo server certificate."

  wget -q -O $mender_dir/server.demo.crt \
    $meta_mender_repo/$meta_mender_revision/meta-mender-demo/recipes-mender/mender/files/server.crt
}

install_files() {
  local primary_dir=$1
  local data_dir=$2

  sysconfdir="etc/mender"
  bindir="usr/bin"
  localstatedir="var/lib/mender"
  dataconfdir="mender"
  databootdir="u-boot"

  log "\tInstalling files."

  # Prepare 'data' partition
  sudo install -d -m 755 ${data_dir}/${dataconfdir}
  sudo install -d -m 755 ${data_dir}/${databootdir}

  sudo install -m 0444 ${mender_dir}/device_type ${data_dir}/${dataconfdir}
  sudo install -m 0644 ${mender_dir}/fw_env.config ${data_dir}/${databootdir}

  sudo ln -sf /data/${databootdir}/fw_env.config ${primary_dir}/etc/fw_env.config

  # Create mount-points
  #
  # Note that only one of /boot/efi or /uboot will be used depending on what
  # type of Mender integration is used (GRUB or U-boot). I do not see any
  # problems with keeping an empty directory to reduce complexity of creating
  # this directory structure.
  sudo install -d -m 755 ${primary_dir}/data
  sudo install -d -m 755 ${primary_dir}/boot/efi
  sudo install -d -m 755 ${primary_dir}/uboot

  case "$device_type" in
    "qemux86_64")
      sudo install -d ${primary_dir}/lib64
      sudo ln -sf /lib/ld-linux-x86-64.so.2 ${primary_dir}/lib64/ld-linux-x86-64.so.2
      ;;
  esac

  sudo ln -sf /data/${dataconfdir} ${primary_dir}/${localstatedir}

  # Call mender make install target
  ( cd $GOPATH/src/github.com/mendersoftware/mender && \
  sudo make install prefix=$primary_dir )

  # If specified, replace Mender client binary
  if [ -n "${mender_client}" ]; then
    sudo install -m 0755 ${mender_client} ${primary_dir}/${bindir}/mender
  fi

  # Enable menderd service starting on boot.
  if [ -z "${standalone_operation}" ]; then
    # Enable menderd service starting on boot.
    sudo ln -sf /lib/systemd/system/mender.service \
        ${primary_dir}/etc/systemd/system/multi-user.target.wants/mender.service
  fi

  # By default production settings configuration is installed
  if [ -n "${demo}" ] && [ ${demo} -eq 1 ]; then
    sudo install -m 0644 ${primary_dir}/${sysconfdir}/mender.conf.demo ${primary_dir}/${sysconfdir}/mender.conf
  fi

  # If specified, replace server URL
  if [ -n "${server_url}" ]; then
    jq_inplace '.ServerURL = \"'${server_url}'\"' ${primary_dir}/${sysconfdir}/mender.conf
  fi

  # Set tenant token
  if [ -n "${tenant_token}" ]; then
    jq_inplace '.TenantToken = \"'${tenant_token}'\"' ${primary_dir}/${sysconfdir}/mender.conf
  fi

  # Append RootfsPartA/B to mender.conf
  append_rootfs_configuration ${primary_dir}/${sysconfdir}/mender.conf

  # Set artifact name
  if [ -n "${artifact_name}" ]; then
    sudo sh -c -e "echo artifact_name=${artifact_name} > ${primary_dir}/${sysconfdir}/artifact_info";
  fi

  # Set demo server
  if [ -n "${demo_host_ip}" ]; then
    sudo sh -c -e "echo '$demo_host_ip docker.mender.io s3.docker.mender.io' >> $primary_dir/etc/hosts";
    jq_inplace '.ServerURL = \"https://docker.mender.io\"' ${primary_dir}/${sysconfdir}/mender.conf
  fi

  # Install provided or demo certificate
  if [ -n "${server_cert}" ]; then
    sudo install -m 0444 ${server_cert} ${primary_dir}/${sysconfdir}/server.crt
  else
    sudo install -m 0444 ${mender_dir}/server.demo.crt ${primary_dir}/${sysconfdir}/server.crt
  fi
}

do_install_mender() {
  if [ -z "${mender_disk_image}" ]; then
    log "Mender raw disk image not set. Aborting."
    show_help
  fi

  if [ -z "${device_type}" ]; then
    log "Target device type name not set. Aborting."
    show_help
  fi

  if [ -z "${artifact_name}" ]; then
    log "Artifact info not set. Aborting."
    show_help
  fi

  if [ -z "${server_url}" ] && [ -z "${demo_host_ip}" ] && \
     [ -z "${tenant_token}" ]; then
    log "No Mender server configuration was provided, it will only be possible to update using standalone mode."
    standalone_operation="true"
  fi

  if [ -n "${server_url}" ] && [ -n "${demo_host_ip}" ]; then
    log "Incompatible server type choice. Aborting."
    show_help
  fi

  [ ! -f $mender_disk_image ] && \
      { log "$mender_disk_image - file not found. Aborting."; exit 1; }

  test -n "$(go version)" || \
      { log "go binary not found in PATH. Aborting."; exit 1; }

  test -n "$GOPATH" || \
      { log "GOPATH not set. Aborting."; exit 1; }

  test -d $GOPATH/src/github.com/mendersoftware/mender || \
      { log "mender source not found in \$GOPATH/src/github.com/mendersoftware/mender. Aborting."; exit 1; }

  # Mount rootfs partition A.
  create_device_maps $mender_disk_image mender_disk_mappings

  # Change current directory to 'output' directory.
  cd $output_dir

  primary=${mender_disk_mappings[1]}
  data=${mender_disk_mappings[3]}

  if [ "$device_type" == "qemux86_64" ]; then
    data=${mender_disk_mappings[4]}
  fi

  map_primary=/dev/mapper/"$primary"
  map_data=/dev/mapper/"$data"
  path_primary=$output_dir/sdimg/primary
  path_data=$output_dir/sdimg/data
  mkdir -p ${path_primary} ${path_data}

  sudo mount ${map_primary} ${path_primary}
  sudo mount ${map_data} ${path_data}

  # Get Mender client related files.
  get_mender_files_from_upstream

  # Create all necessary client's files.
  create_client_files

  # Create all required paths and install files.
  install_files ${path_primary} ${path_data}

  # Back to working directory.
  cd $tool_dir && sync

  # Clean stuff.
  detach_device_maps ${mender_disk_mappings[@]}
  rm -rf $output_dir/sdimg
  [[ $keep -eq 0 ]] && { rm -rf $mender_dir; }

  log "\tDone."
}

PARAMS=""

while (( "$#" )); do
  case "$1" in
    -m | --mender-disk-image)
      mender_disk_image=$2
      shift 2
      ;;
    -g | --mender-client)
      mender_client=$2
      shift 2
      ;;
    -d | --device-type)
      device_type=$2
      shift 2
      ;;
    -a | --artifact-name)
      artifact_name=$2
      shift 2
      ;;
    -n | --demo)
      demo="1"
      shift 1
      ;;
    -i | --demo-host-ip)
      demo_host_ip=$2
      shift 2
      ;;
    -c | --server-cert)
      server_cert=$2
      shift 2
      ;;
    -u | --server-url)
      server_url=$2
      shift 2
      ;;
    -t | --tenant-token)
      tenant_token=$2
      shift 2
      ;;
    -k | --keep)
      keep="1"
      shift 1
      ;;
    -h | --help)
      show_help
      ;;
    --)
      shift
      break
      ;;
    -*)
      log "Error: unsupported option $1"
      exit 1
      ;;
    *)
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

eval set -- "$PARAMS"

# Some commands expect elevated privileges.
sudo true

do_install_mender
