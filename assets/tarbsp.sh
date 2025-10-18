#!/bin/bash
drive_config=emmc
uboot_version=v2024.03
rm -rf tmp
mkdir tmp

cat <<- EOF > fw_env.config
/dev/mmcblk0 0x400000 0x8000
/dev/mmcblk0 0x800000 0x8000
EOF

cp radxa-cm3i-io/idbloader.img radxa-cm3i-io/u-boot.itb fw_env.config tmp
cd tmp
tar czvf ../perfecta-cm3i-rk3568_${drive_config}-${uboot_version}.tar.gz *
cd ..