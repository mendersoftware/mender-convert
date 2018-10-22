#!/bin/bash

show_help() {
  cat << EOF

Mender executables, service and configuration files installer.

Usage: $0 [options]

    Options: [-m|--mender-disk-image | -g|--mender-client | -a|--artifact-name |
              -d|--device-type | -p|--demo-host-ip | -u| --server-url |
              -t| --tenant-token]

        --mender-disk-image - Mender raw disk image
        --mender-client     - Mender client binary file
        --artifact-name     - artifact info
        --device-type       - target device type identification
        --demo-host-ip      - Mender demo server IP address
        --server-url        - Mender production server url
        --server-cert       - Mender server certificate

    Examples:

        ./mender-convert install-mender-to-mender-disk-image
                --mender-disk-image <mender_image_path>
                --device-type <beaglebone | raspberrypi3>
                --artifact-name release-1_1.5.0
                --demo-host-ip 192.168.10.2
                --mender-client <mender_binary_path>

EOF
  exit 1
}

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
output_dir=${tool_dir}/output

mender_client_repo="https://raw.githubusercontent.com/mendersoftware/mender"
mender_client_revision="1.6.x"
meta_mender_repo="https://raw.githubusercontent.com/mendersoftware/meta-mender"
meta_mender_revision="sumo"

mender_dir=$output_dir/mender
device_type=
artifact_name=
# Mender demo server IP address.
demo_host_ip=
# Mender production server url passed as CLI option.
server_url=
# Actual server url.
mender_server_url="https://docker.mender.io"
# Mender production certificate.
server_cert=
# Mender tenant token passed as CLI option.
tenant_token=
# Mender tenant token.
mender_tenant_token="dummy"

declare -a mender_disk_mappings

create_client_files() {
  cat <<- EOF > $mender_dir/mender.service
	[Unit]
	Description=Mender OTA update service
	After=systemd-resolved.service

	[Service]
	Type=idle
	User=root
	Group=root
	ExecStartPre=/bin/mkdir -p -m 0700 /data/mender
	ExecStartPre=/bin/ln -sf /etc/mender/tenant.conf /var/lib/mender/authtentoken
	ExecStart=/usr/bin/mender -daemon
	Restart=on-abort

	[Install]
	WantedBy=multi-user.target
	EOF

  cat <<- EOF > $mender_dir/mender.conf
	{
	    "InventoryPollIntervalSeconds": 5,
	    "RetryPollIntervalSeconds": 1,
	    "RootfsPartA": "/dev/mmcblk0p2",
	    "RootfsPartB": "/dev/mmcblk0p3",
	    "ServerCertificate": "/etc/mender/server.crt",
	    "ServerURL": "$mender_server_url",
	    "TenantToken": "$mender_tenant_token",
	    "UpdatePollIntervalSeconds": 5
	}
	EOF

  cat <<- EOF > $mender_dir/artifact_info
	artifact_name=${artifact_name}
	EOF

  # Version file
  echo -n "2" > $mender_dir/version

  cat <<- EOF > $mender_dir/device_type
	device_type=${device_type}
	EOF

  case "$device_type" in
    "beaglebone")
      cat <<- EOF > $mender_dir/fw_env.config
	/dev/mmcblk0 0x800000 0x20000
	/dev/mmcblk0 0x1000000 0x20000
	EOF
      ;;
    "raspberrypi3")
      cat <<- EOF > $mender_dir/fw_env.config
	/dev/mmcblk0 0x400000 0x4000
	/dev/mmcblk0 0x800000 0x4000
	EOF
      ;;
  esac
}

get_mender_files_from_upstream() {

  mkdir -p $mender_dir

  log "\tDownloading inventory & identity scripts."

  wget -nc -q -O $mender_dir/mender-device-identity \
    $mender_client_repo/$mender_client_revision/support/mender-device-identity
  wget -nc -q -O $mender_dir/mender-inventory-bootloader-integration \
    $mender_client_repo/$mender_client_revision/support/mender-inventory-bootloader-integration
  wget -nc -q -O $mender_dir/mender-inventory-hostinfo \
    $mender_client_repo/$mender_client_revision/support/mender-inventory-hostinfo
  wget -nc -q -O $mender_dir/mender-inventory-network \
    $mender_client_repo/$mender_client_revision/support/mender-inventory-network
  wget -nc -q -O $mender_dir/mender-inventory-os \
    $mender_client_repo/$mender_client_revision/support/mender-inventory-os
  wget -nc -q -O $mender_dir/mender-inventory-rootfs-type \
    $mender_client_repo/$mender_client_revision/support/mender-inventory-rootfs-type
  wget -nc -q -O $mender_dir/server.crt \
    $meta_mender_repo/$meta_mender_revision/meta-mender-demo/recipes-mender/mender/files/server.crt
}

install_files() {
  local primary_dir=$1
  local data_dir=$2

  identitydir="usr/share/mender/identity"
  inventorydir="usr/share/mender/inventory"
  sysconfdir="etc/mender"
  bindir="usr/bin"
  systemd_unitdir="lib/systemd/system"
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

  # Prepare 'primary' partition
  [ ! -d "$primary_dir/data" ] && \
      { log "\t'data' mountpoint missing. Adding"; \
        sudo install -d -m 755 ${primary_dir}/data; }

  case "$device_type" in
    "beaglebone")
      [ ! -d "$primary_dir/boot/efi" ] && \
          { log "\t'/boot/efi' mountpoint missing. Adding"; \
            sudo install -d -m 755 ${primary_dir}/boot/efi; }
      ;;
    "raspberrypi3")
      [ ! -d "$primary_dir/uboot" ] && \
          { log "\t'/boot/efi' mountpoint missing. Adding"; \
            sudo install -d -m 755 ${primary_dir}/uboot; }
      ;;
  esac

  sudo install -d ${primary_dir}/${identitydir}
  sudo install -d ${primary_dir}/${inventorydir}
  sudo install -d ${primary_dir}/${sysconfdir}
  sudo install -d ${primary_dir}/${sysconfdir}/scripts

  sudo ln -sf /data/${dataconfdir} ${primary_dir}/${localstatedir}

  sudo install -m 0755 ${mender_client} ${primary_dir}/${bindir}/mender

  sudo install -t ${primary_dir}/${identitydir} -m 0755 \
      ${mender_dir}/mender-device-identity

  sudo install -t ${primary_dir}/${inventorydir} -m 0755 \
      ${mender_dir}/mender-inventory-*

  sudo install -m 0644 ${mender_dir}/mender.service ${primary_dir}/${systemd_unitdir}

  # Enable menderd service starting on boot.
  sudo ln -sf /lib/systemd/system/mender.service \
      ${primary_dir}/etc/systemd/system/multi-user.target.wants/mender.service

  sudo install -m 0644 ${mender_dir}/mender.conf ${primary_dir}/${sysconfdir}

  sudo install -m 0444 ${mender_dir}/server.crt ${primary_dir}/${sysconfdir}

  sudo install -m 0644 ${mender_dir}/artifact_info ${primary_dir}/${sysconfdir}

  sudo install -m 0644 ${mender_dir}/version ${primary_dir}/${sysconfdir}/scripts

  if [ -n "${demo_host_ip}" ]; then
    sudo sh -c -e "echo '$demo_host_ip docker.mender.io s3.docker.mender.io' >> $primary_dir/etc/hosts";
  fi

  if [ -n "${server_cert}" ]; then
    sudo install -m 0444 ${server_cert} ${primary_dir}/${sysconfdir}
  fi
}

do_install_mender() {
  if [ -z "${mender_disk_image}" ]; then
    log "Mender raw disk image not set. Aborting."
    show_help
  fi

  if [ -z "${mender_client}" ]; then
    log "Mender client binary not set. Aborting."
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
    log "No server type specified. Aborting."
    show_help
  fi

  if [ -n "${server_url}" ] && [ -n "${demo_host_ip}" ]; then
    log "Incompatible server type choice. Aborting."
    show_help
  fi

  # TODO: more error checking of server types
  if [ -n "${tenant_token}" ]; then
    mender_tenant_token=$(echo ${tenant_token} | tr -d '\n')
    mender_server_url="https://hosted.mender.io"
  fi

  if [ -n "${server_url}" ]; then
    mender_server_url=${server_url}
  fi

  [ ! -f $mender_disk_image ] && \
      { log "$mender_disk_image - file not found. Aborting."; exit 1; }

  # Mount rootfs partition A.
  create_device_maps $mender_disk_image mender_disk_mappings

  mkdir -p $output_dir && cd $output_dir

  primary=${mender_disk_mappings[1]}
  data=${mender_disk_mappings[3]}

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
