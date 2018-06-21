#!/bin/bash

sdimg_boot_dir=$1
embedded_rootfs_dir=$2
uboot_backup_dir=${embedded_rootfs_dir}/opt/backup/uboot

echo $sdimg_boot_dir
echo $embedded_rootfs_dir

[ ! -d "${sdimg_boot_dir}" ] && \
    { echo "Error: boot location not mounted."; exit 1; }
[ ! -d "${embedded_rootfs_dir}" ] && \
    { echo "Error: embedded content not mounted."; exit 1; }
[[ ! -f $uboot_backup_dir/MLO || ! -f $uboot_backup_dir/u-boot.img ]] && \
    { echo "Error: cannot find U-Boot related files."; exit 1; }

set_uenv() {
  cat <<- 'EOF' | sudo tee --append $sdimg_boot_dir/uEnv.txt 2>&1 >/dev/null
	loadaddr=0x82000000
	fdtaddr=0x88000000
	rdaddr=0x88080000

	initrd_high=0xffffffff
	fdt_high=0xffffffff

	loadximage=echo debug: [/boot/vmlinuz-${uname_r}] ... ; load mmc 0:2 ${loadaddr} /boot/vmlinuz-${uname_r}
	loadxfdt=echo debug: [/boot/dtbs/${uname_r}/${fdtfile}] ... ;load mmc 0:2 ${fdtaddr} /boot/dtbs/${uname_r}/${fdtfile}
	loadxrd=echo debug: [/boot/initrd.img-${uname_r}] ... ; load mmc 0:2 ${rdaddr} /boot/initrd.img-${uname_r}; setenv rdsize ${filesize}
	loaduEnvtxt=load mmc 0:2 ${loadaddr} /boot/uEnv.txt ; env import -t ${loadaddr} ${filesize};
	check_dtb=if test -n ${dtb}; then setenv fdtfile ${dtb};fi;
	loadall=run loaduEnvtxt; run check_dtb; run loadximage; run loadxrd; run loadxfdt;

	mmcargs=setenv bootargs console=tty0 console=${console} ${optargs} ${cape_disable} ${cape_enable} root=/dev/mmcblk0p2 rootfstype=${mmcrootfstype} ${cmdline}

	uenvcmd=run loadall; run mmcargs; echo debug: [${bootargs}] ... ; echo debug: [bootz ${loadaddr} ${rdaddr}:${rdsize} ${fdtaddr}] ... ; bootz ${loadaddr} ${rdaddr}:${rdsize} ${fdtaddr};
	EOF
}

##  dd if=MLO of=${sdimg_file} count=1 seek=1 bs=128k
##  dd if=u-boot.img of=${sdimg_file} count=2 seek=1 bs=384k
# Copy U-Boot related files.
sudo cp ${uboot_backup_dir}/MLO ${sdimg_boot_dir}
sudo cp ${uboot_backup_dir}/u-boot.img ${sdimg_boot_dir}

# Create U-Boot purposed uEnv.txt file.
set_uenv

echo -e "\nStage done."

exit 0
