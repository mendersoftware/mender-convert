#!/bin/bash

output_dir=$1
boot_mapping=$2
embedded_rootfs_dir=$3
uboot_backup_dir=${embedded_rootfs_dir}/opt/backup/uboot
build_log=$output_dir/build.log

[ ! -f $output_dir/boot.vfat ] && \
    { log "Error: extracted boot partition not found. Aborting."; exit 1; }
[ ! -d "${embedded_rootfs_dir}" ] && \
    { log "Error: embedded content not mounted."; exit 1; }
[[ ! -f $uboot_backup_dir/MLO || ! -f $uboot_backup_dir/u-boot.img ]] && \
    { log "Error: cannot find U-Boot related files."; exit 1; }

cat <<- 'EOF' | sudo tee --append ${output_dir}/uEnv.txt 2>&1 >/dev/null
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

mcopy -o -i ${output_dir}/boot.vfat -s ${output_dir}/uEnv.txt ::uEnv.txt
mcopy -o -i ${output_dir}/boot.vfat -s ${uboot_backup_dir}/MLO ::MLO
mcopy -o -i ${output_dir}/boot.vfat -s ${uboot_backup_dir}/u-boot.img ::u-boot.img

sudo dd if=${output_dir}/boot.vfat of=/dev/mapper/${boot_mapping} bs=1M conv=sparse >> "$build_log" 2>&1

log "\tDone."

exit 0
