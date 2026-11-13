# UEFI NVRAM

This directory holds the NVRAM file which is used as the firmware memory of the UEFI software which
runs under QEMU. It's main purpose is to start the UEFI software with certificates pre-loaded into
the firmware memory, and Secure Boot enabled.

## How to recreate the `OVMF_VARS.fd` file

1. Create the `OVMF_VARS.fd` file:
   ```bash
   cp /usr/share/OVMF/OVMF_VARS.fd OVMF_VARS.fd
   ```

2. Create a filesystem which contains the UEFI certificates:
   ```bash
   dd if=/dev/zero of=/tmp/cert-filesystem.fs bs=1M count=10; \
   mkfs.vfat /tmp/cert-filesystem.fs; \
   mkdir cert-filesystem; \
   sudo mount /tmp/cert-filesystem.fs cert-filesystem -o loop,uid=$UID; \
   cp *.crt cert-filesystem; \
   sudo umount cert-filesystem; \
   rmdir cert-filesystem
   ```

   Tip: If you ever need to re-fetch the certificate files, run `mokutil --db` on your own
   computer. This lists your installed certificates, and they come with URLs which say where you can
   download them. Make sure you download the `.crt`, not the `.crl`.

3. Launch QEMU with the NVRAM and the filesystem containing the certificates. *Make sure to press F2
   quickly after the window appears to enter the firmware menu*:
   ```bash
   qemu-system-x86_64 \
       -drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
       -drive file=./OVMF_VARS.fd,if=pflash,format=raw,unit=1 \
       -drive file=/tmp/cert-filesystem.fs,if=ide,format=raw
   ```

4. After having entered the firmware menu, perform the following steps:

    1. Enter "Device Manager".

    2. Enter "Secure Boot Configuration".

    3. Switch "Secure Boot Mode" to "Custom Mode".

    4. Enter "Custom Secure Boot Options".

    5. Enter "PK Options".

    6. Enter "Enroll OK".

    7. Enter "Enroll PK Using File".

    8. Locate the certificate file in the filesystem that you created in main step 2, and add it.

    9. Make sure to select "Commit Changes".

    10. Repeat the same process starting from sub step 5, except for "DB Options" instead.

    11. Go back to the "Secure Boot Configuration" screen. "Attempt Secure Boot" should now have
        been auto-selected. If it's not, enable it and save the change.

    12. Go back to the main manu and select "Reset". After the setup has been exited, you can kill
        QEMU.

5. Clean up:
   ```bash
   rm -f /tmp/cert-filesystem.fs
   ```

### Notes for Ubuntu 24.04 - ovmf deb package

This section describes how Secure Boot testing works on the modern (4M) OVMF
shipped by Debian 13 / Ubuntu 24.04 and newer: which firmware, QEMU machine and
disk we use, and how Secure Boot on vs. off is selected.

#### ovmf deb package

Compared to Ubuntu 22.04, the `ovmf` package does not ship anymore with 2M and
4M versions, only the latter is available. What is more important, the
SecureBoot **code** has been compiled out from the base ovmf, and it is only
available on `OVMF_CODE_4M.secboot.fd` (and `OVMF_VARS_4M.ms.fd` with Microsoft
certificates).

This is the base file that needs to be used in our guide. According to the
README "you'll get a guest that is Secure Boot-*capable*, but has Secure Boot
disabled. To enable it, you'll need to manually import PK/KEK/DB keys".

References:
* https://changelogs.ubuntu.com/changelogs/pool/main/e/edk2/edk2_2024.02-2/changelog

#### Secure Boot on vs. off

The 4M `OVMF_CODE_4M.secboot.fd` is built `SMM_REQUIRE`, so it only initializes
on a `q35` machine with `smm=on` and a secure pflash. To make this work for every
guest, the test disk is attached as `virtio-blk` (`/dev/vda`; see
`MENDER_STORAGE_DEVICE_BASE` in the `*-qemux86-64` configs). `virtio` is
machine-independent and its driver is present in both Debian's and Ubuntu's
initramfs, so both distros boot under `q35` -- unlike IDE/SATA, where Ubuntu's
initramfs lacks the `ahci` driver and hangs on the root device.

`scripts/test/mender-convert-qemu` therefore always runs the `.secboot` firmware
on `-machine q35,smm=on` with a secure pflash, and selects Secure Boot on or off
purely by the vars store:

* **Secure Boot on** (the grub.d images, e.g. Debian and Ubuntu): the
  Microsoft-enrolled vars store (`OVMF_VARS_4M.ms.fd`). This is real,
  SMM-protected Secure Boot, and `mokutil --sb-state` reports
  `SecureBoot enabled`.
* **Secure Boot off** (`QEMU_NO_SECURE_BOOT=1`, used for the `no-grub.d` images
  whose unsigned grub cannot run with Secure Boot enforced): the plain,
  un-enrolled vars store (`OVMF_VARS_4M.fd`). The firmware is still
  Secure-Boot-capable, so it boots in setup mode and `mokutil --sb-state`
  reports `SecureBoot disabled`.

Both Debian and Ubuntu get real Secure Boot coverage on modern hosts, matching
the legacy (2M OVMF) behaviour, and `test_secure_boot` always has a Secure Boot
state to assert.
