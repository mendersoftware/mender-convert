#!/bin/bash

show_help() {
cat << EOF

Tool adding GRUB specific files to Mender compliant .sdimg image file.

Usage: $0 [options]

    Options: [-i|--image | -t|--toolchain -k|--keep | -d|--device-type]

        --image        - .sdimg image generated with mender-convert
        --toolchain    - ARM specific toolchain path
        --keep         - prevent deleting GRUB workspace
        --device-type  - target device type identification

    Note: supported device types are: beaglebone, raspberrypi3

    Examples:

        ./mender-convert.sh install_bootloader --image <sdimg_file_path>
                --device-type beaglebone --toolchain arm-linux-gnueabihf

        Note: toolchain naming convention is arch-vendor-(os-)abi

              arch is for architecture: arm, mips, x86, i686...
              vendor is tool chain supplier: apple, Codesourcery, Linux,
              os is for operating system: linux, none (bare metal)
              abi is for application binary interface convention: eabi, gnueabi, gnueabihf

EOF
}

tool_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
output_dir=${tool_dir}/output
grubenv_dir=$output_dir/grubenv
grubenv_build_dir=$output_dir/grubenv_build
image=
toolchain=
device_type=
keep=0
efi_boot=EFI/BOOT
EFI_STUB_VER="4.12.0"

declare -a sdimgmappings

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
  mkdir -p $grubenv_dir
  mkdir -p $grubenv_build_dir

  git clone https://github.com/mendersoftware/grub-mender-grubenv.git $grubenv_dir
  cd $grubenv_dir

  # Prepare configuration file.
  cp mender_grubenv_defines.example mender_grubenv_defines

  local uname_r=$1
  local kernel_imagetype=vmlinuz-${uname_r}
  local kernel_devicetree=dtbs/${uname_r}/am335x-boneblack.dtb

  sed -i '/^kernel_imagetype/s/=.*$/='${kernel_imagetype}'/' mender_grubenv_defines
  sed -i '/^kernel_devicetree/s/=.*$/='${kernel_devicetree//\//\\/}'/' mender_grubenv_defines

  make
  make DESTDIR=$grubenv_build_dir install
  cd $output_dir
  rm -rf $grubenv_dir
}

# Takes following arguments:
#
#  $1 - linux kernel version
build_grub_efi() {
  local grub_arm=$output_dir/grub/arm
  local grub_linux=$output_dir/grub/linux
  local grub_repo_vc_dir=$output_dir/grub/.git
  local repo_clean=0

  local version=$(echo $1 | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')

  # Build grub modules for arm platform and executables for the host.
  if [ ! -d $grub_repo_vc_dir ]; then
    git clone git://git.savannah.gnu.org/grub.git $output_dir/grub
    local repo_clean=1
  fi

  cd $output_dir/grub/
  [[ repo_clean -eq 0 ]] && { make --quiet clean; make --quiet distclean; }

  if [ $(version $version) -lt $(version $EFI_STUB_VER) ]; then
    # To avoid error message: "plain image kernel not supported - rebuild
    # with CONFIG_(U)EFI_STUB enabled" - use a specific commit.
    git checkout 9b37229f0
  fi

  mkdir -p $grub_arm
  mkdir -p $grub_linux

  # First build linux tools.
  ./autogen.sh
  ./configure --quiet CC=gcc --target=x86_64 --with-platform=efi --prefix=$grub_linux
  make --quiet
  make --quiet install

  # Clean workspace.
  make --quiet clean
  make --quiet distclean

  # Now build ARM modules.
  ./configure --host=$toolchain --with-platform=efi --prefix=$grub_arm \
      CFLAGS="-Os -march=armv7-a" CCASFLAGS="-march=armv7-a" --disable-werror
  make --quiet
  make --quiet install

  # Build grub.efi binary.
  $grub_linux/bin/grub-mkimage  -v -p /$efi_boot -o grub.efi --format=arm-efi \
      -d $grub_arm/lib/grub/arm-efi/  boot linux ext2 fat serial part_msdos \
      part_gpt  normal efi_gop iso9660 configfile search loadenv test cat echo \
      gcry_sha256 halt hashsum loadenv reboot

  rc=$?

  [[ $rc -ne 0 ]] && { return 1; } || { return 0; }
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
  local grubenv_dir=$grubenv_build_dir/boot/efi/EFI/BOOT/
  local boot_dir=$1
  local rootfs_dir=$2
  local efi_boot_dir=$boot_dir/$efi_boot

  # Make sure env, lock, lock.sha256sum files exists in working directory.
  [[ ! -d $grubenv_dir/mender_grubenv1 || ! -d $grubenv_dir/mender_grubenv2 ]] && \
      { echo "Error: cannot find mender grub related files."; exit 1; }

  sudo install -d -m 755 $efi_boot_dir

  cd $grubenv_dir && find . -type f -exec sudo install -Dm 644 "{}" "$efi_boot_dir/{}" \;
  cd ${output_dir}

  sudo install -m 0644 ${output_dir}/grub/grub.efi $efi_boot_dir
  sudo install -m 0755 ${output_dir}/grub/arm/bin/grub-editenv $rootfs_dir/usr/bin

  sudo install -m 0755 $grubenv_build_dir/usr/bin/fw_printenv $rootfs_dir/sbin/fw_printenv
  sudo install -m 0755 $grubenv_build_dir/usr/bin/fw_setenv $rootfs_dir/sbin/fw_setenv

  # Replace U-Boot default printenv/setenv commands.
  sudo ln -fs /sbin/fw_printenv $rootfs_dir/usr/bin/fw_printenv
  sudo ln -fs /sbin/fw_setenv $rootfs_dir/usr/bin/fw_setenv

  set_uenv $boot_dir
}

do_install_bootloader() {
  echo "Setting bootloader..."

  if [ -z "${image}" ]; then
    echo ".sdimg image file not set. Aborting."
    exit 1
  fi

  if [ -z "${toolchain}" ]; then
    echo "ARM toolchain not set. Aborting."
    exit 1
  fi    

  if [ -z "${device_type}" ]; then
    echo "Target device type name not set. Aborting."
    exit 1
  fi

  if [[ $(which ${toolchain}-gcc) = 1 ]]; then
    echo "Error: ARM GCC not found in PATH. Aborting."
    exit 1
  fi

  [ ! -f $image ] && { echo "$image - file not found. Aborting."; exit 1; }

  # Map & mount Mender compliant image.
  create_device_maps $image sdimgmappings

  mkdir -p $output_dir && cd $output_dir

  boot=${sdimgmappings[0]}
  primary=${sdimgmappings[1]}
  map_boot=/dev/mapper/"$boot"
  map_primary=/dev/mapper/"$primary"
  path_boot=$output_dir/sdimg/boot
  path_primary=$output_dir/sdimg/primary
  mkdir -p ${path_boot} ${path_primary}

  sudo mount ${map_boot} ${path_boot}
  sudo mount ${map_primary} ${path_primary}

  get_kernel_version ${path_primary} kernel_version
  echo -e "\nKernel version: $kernel_version"

  build_env_lock_boot_files $kernel_version

  build_grub_efi $kernel_version
  rc=$?

  [[ $rc -ne 0 ]] && { echo "Error: grub.efi building failure. Aborting."; } \
                  || { echo "Successful grub.efi building."; \
                       install_files ${path_boot} ${path_primary}; }

  # Back to working directory.
  cd $tool_dir && sync

  detach_device_maps ${sdimgmappings[@]}
  # Clean files.
  rm -rf $output_dir/sdimg

#  [[ $keep -eq 0 ]] && { rm -rf $output_dir; }
  echo -e "\nAll done."
}

PARAMS=""

while (( "$#" )); do
  case "$1" in
    -i | --image)
      image=$2
      shift 2
      ;;
    -t | --toolchain)
      toolchain=$2
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
      echo "Error: unsupported option $1" >&2
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
