#!/bin/bash

show_help() {
cat << EOF

Tool adding GRUB specific files to Mender compliant image file.

Usage: $0 [options]

    Options: [-m|--mender-disk-image | -b|--bootloader-toolchain |
              -k|--keep | -d|--device-type]

        --mender-disk-image    - Mender raw disk image
        --bootloader-toolchain - GNU Arm Embedded Toolchain
        --device-type          - target device type identification
        --keep                 - prevent deleting GRUB workspace

    Note: supported device types are: beaglebone, raspberrypi3

    Examples:

        ./mender-convert install-bootloader-to-mender-disk-image
                --mender-disk-image <mender_image_path>
                --device-type <beaglebone | raspberrypi3>
                --bootloader-toolchain arm-linux-gnueabihf

        Note: toolchain naming convention is arch-vendor-(os-)abi

              arch is for architecture: arm, mips, x86, i686...
              vendor is tool chain supplier: apple, Codesourcery, Linux,
              os is for operating system: linux, none (bare metal)
              abi is for application binary interface convention: eabi, gnueabi, gnueabihf

EOF
}

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
output_dir=${tool_dir}/output
grub_dir=$output_dir/grub
grubenv_dir=$output_dir/grubenv
mender_disk_image=
bootloader_toolchain=
device_type=
keep=0
efi_boot=EFI/BOOT
EFI_STUB_VER="4.12.0"
build_log=$output_dir/build.log

declare -a mender_disk_mappings

version() {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

get_kernel_version() {
  local search_path=$1/boot
  local resultvar=$2

  [ ! -d "$search_path" ] && { return 1; }

  kernel_image=$(ls -1 $search_path | grep -E "^vmlinuz")

  local myresult=${kernel_image#*-}
  eval $resultvar="'$myresult'"
  return 0
}

# Takes following arguments:
#
#  $1 - linux kernel version
build_env_lock_boot_files() {
  log "\tBuilding boot scripts and tools."
  local grubenv_repo_vc_dir=$grubenv_dir/.git
  local grubenv_build_dir=$grubenv_dir/build

  mkdir -p $grubenv_dir

  if [ ! -d $grubenv_repo_vc_dir ]; then
    git clone https://github.com/mendersoftware/grub-mender-grubenv.git $grubenv_dir >> "$build_log" 2>&1
  fi
  cd $grubenv_dir

  mkdir -p $grubenv_build_dir

  # Prepare configuration file.
  cp mender_grubenv_defines.example mender_grubenv_defines

  local uname_r=$1
  local kernel_imagetype=vmlinuz-${uname_r}
  local kernel_devicetree=dtbs/${uname_r}/am335x-boneblack.dtb

  sed -i '/^kernel_imagetype/s/=.*$/='${kernel_imagetype}'/' mender_grubenv_defines
  sed -i '/^kernel_devicetree/s/=.*$/='${kernel_devicetree//\//\\/}'/' mender_grubenv_defines

  make --quiet >> "$build_log" 2>&1
  make --quiet DESTDIR=$grubenv_build_dir install >> "$build_log" 2>&1
  cd $output_dir
}

# Takes following arguments:
#
#  $1 - linux kernel version
build_grub_efi() {
  log "\tBuilding GRUB efi file."

  local grub_build_dir=$grub_dir/build
  local grub_arm_dir=$grub_build_dir/arm
  local host=$(uname -m)
  local grub_host_dir=$grub_build_dir/$host
  local grub_repo_vc_dir=$grub_dir/.git

  local version=$(echo $1 | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')

  # Build grub modules for arm platform and executables for the host.
  if [ ! -d $grub_repo_vc_dir ]; then
    git clone git://git.savannah.gnu.org/grub.git $grub_dir >> "$build_log" 2>&1
  fi

  cd $grub_dir
  make --quiet distclean >> "$build_log" 2>&1

  if [ $(version $version) -lt $(version $EFI_STUB_VER) ]; then
    # To avoid error message: "plain image kernel not supported - rebuild
    # with CONFIG_(U)EFI_STUB enabled" - use a specific commit.
    git checkout 9b37229f0 >> "$build_log" 2>&1
  fi

  mkdir -p $grub_arm_dir
  mkdir -p $grub_host_dir

  local cores=$(nproc)

  # First build host tools.
  ./autogen.sh >> "$build_log" 2>&1
  ./configure --quiet CC=gcc --target=${host} --with-platform=efi --prefix=$grub_host_dir >> "$build_log" 2>&1
  make --quiet -j$cores >> "$build_log" 2>&1
  make --quiet install >> "$build_log" 2>&1

  # Clean workspace.
  make --quiet clean >> "$build_log" 2>&1
  make --quiet distclean >> "$build_log" 2>&1

   # Now build ARM modules.
  ./configure --quiet  --host=$bootloader_toolchain --with-platform=efi \
      --prefix=$grub_arm_dir CFLAGS="-Os -march=armv7-a" \
      CCASFLAGS="-march=armv7-a" --disable-werror >> "$build_log" 2>&1
  make --quiet -j$cores >> "$build_log" 2>&1
  make --quiet install >> "$build_log" 2>&1

  # Build GRUB EFI image.
  ${grub_host_dir}/bin/grub-mkimage  -v -p /$efi_boot -o grub.efi --format=arm-efi \
      -d $grub_arm_dir/lib/grub/arm-efi/  boot linux ext2 fat serial part_msdos \
      part_gpt  normal efi_gop iso9660 configfile search loadenv test cat echo \
      gcry_sha256 halt hashsum loadenv reboot >> "$build_log" 2>&1

  rc=$?

  cd ${output_dir}
  return $rc
}

# Takes following arguments:
#
#  $1 - boot partition mountpoint
set_uenv() {
  local boot_dir=$1
  # Erase/create uEnv.txt file.
  sudo install -b -m 644 /dev/null $boot_dir/uEnv.txt

  # Fill uEnv.txt file.
  cat <<- 'EOF' | sudo tee $boot_dir/uEnv.txt 2>&1 >/dev/null
	bootdir=
	grubfile=EFI/BOOT/grub.efi
	grubaddr=0x80007fc0
	loadgrub=fatload mmc 0:1 ${grubaddr} ${grubfile}
	grubstart=bootefi ${grubaddr}
	uenvcmd=mmc rescan; run loadgrub; run grubstart;
	EOF
}

# Takes following arguments:
#
#  $1 - boot partition mountpoint
#  $2 - primary partition mountpoint
install_files() {
  log "\tInstalling GRUB files."
  local boot_dir=$1
  local rootfs_dir=$2

  local grub_build_dir=$grub_dir/build
  local grub_arm_dir=$grub_build_dir/arm

  local grubenv_build_dir=$grubenv_dir/build
  local grubenv_efi_boot_dir=$grubenv_build_dir/boot/efi/EFI/BOOT/

  local efi_boot_dir=$boot_dir/$efi_boot

  # Make sure env, lock, lock.sha256sum files exists in working directory.
  [[ ! -d $grubenv_efi_boot_dir/mender_grubenv1 || \
     ! -d $grubenv_efi_boot_dir/mender_grubenv2 ]] && \
      { log "Error: cannot find mender grub related files."; return 1; }

  sudo install -d -m 755 $efi_boot_dir

  cd $grubenv_efi_boot_dir && find . -type f -exec sudo install -Dm 644 "{}" "$efi_boot_dir/{}" \;
  cd ${output_dir}

  sudo install -m 0644 ${grub_dir}/grub.efi $efi_boot_dir
  sudo install -m 0755 ${grub_arm_dir}/bin/grub-editenv $rootfs_dir/usr/bin

  sudo install -m 0755 $grubenv_build_dir/usr/bin/fw_printenv $rootfs_dir/sbin/fw_printenv
  sudo install -m 0755 $grubenv_build_dir/usr/bin/fw_setenv $rootfs_dir/sbin/fw_setenv

  # Replace U-Boot default printenv/setenv commands.
  sudo ln -fs /sbin/fw_printenv $rootfs_dir/usr/bin/fw_printenv
  sudo ln -fs /sbin/fw_setenv $rootfs_dir/usr/bin/fw_setenv

  set_uenv $boot_dir
}

do_install_bootloader() {
  if [ -z "${mender_disk_image}" ]; then
    log "Mender raw disk image not set. Aborting."
    exit 1
  fi

  if [ -z "${bootloader_toolchain}" ]; then
    log "ARM GCC toolchain not set. Aborting."
    exit 1
  fi

  if [ -z "${device_type}" ]; then
    log "Target device type name not set. Aborting."
    exit 1
  fi

  if ! [ -x "$(command -v ${bootloader_toolchain}-gcc)" ]; then
    log "Error: ARM GCC not found in PATH. Aborting."
    exit 1
  fi

  [ ! -f $mender_disk_image ] && \
      { log "$mender_disk_image - file not found. Aborting."; exit 1; }

  # Map & mount Mender compliant image.
  create_device_maps $mender_disk_image mender_disk_mappings

  mkdir -p $output_dir && cd $output_dir

  boot=${mender_disk_mappings[0]}
  primary=${mender_disk_mappings[1]}
  map_boot=/dev/mapper/"$boot"
  map_primary=/dev/mapper/"$primary"
  path_boot=$output_dir/sdimg/boot
  path_primary=$output_dir/sdimg/primary
  mkdir -p ${path_boot} ${path_primary}

  sudo mount ${map_boot} ${path_boot}
  sudo mount ${map_primary} ${path_primary}

  get_kernel_version ${path_primary} kernel_version
  log "\tFound kernel version: $kernel_version"

  build_env_lock_boot_files $kernel_version

  build_grub_efi $kernel_version
  rc=$?

  [[ $rc -ne 0 ]] && { log "\tBuilding grub.efi failed. Aborting."; } \
                  || { log "\tBuilding grub.efi succeeded."; \
                       install_files ${path_boot} ${path_primary}; }

  # Back to working directory.
  cd $tool_dir && sync

  detach_device_maps ${mender_disk_mappings[@]}
  # Clean files.
  rm -rf $output_dir/sdimg

  [[ $keep -eq 0 ]] && { rm -rf $grubenv_dir $grub_dir; }
  [[ $rc -ne 0 ]] && { exit 1; } || { log "\tDone."; }
}

PARAMS=""

while (( "$#" )); do
  case "$1" in
    -m | --mender-disk-image)
      mender_disk_image=$2
      shift 2
      ;;
    -b | --bootloader-toolchain)
      bootloader_toolchain=$2
      shift 2
      ;;
    -d | --device-type)
      device_type=$2
      shift 2
      ;;
    -k | --keep)
      keep=1
      shift 1
      ;;
    -h | --help)
      show_help
      exit 0
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

do_install_bootloader
