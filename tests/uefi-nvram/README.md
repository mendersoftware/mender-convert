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

At the time of writing, we have not yet been able to make our image run on
Ubuntu 24.04 OVMF. However, some progress has been made and this subsection
has some information to avoid repeating the same pitfalls the next time that we
come here to update to Ubuntu 24.04.

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

#### explict SMM for QEMU

For SecureBoot to run correctly on QEMU, SMM needs to be enabled. This is
explicitly mentioned in the ovmf package README file.

Why it was not needed on Ubuntu 22.04 is unknown, but for Ubuntu 24.04 the
`qemu-system-x86_64` call needs an explict parameter `-machine q35,smm=on` to
enable SMM and SecureBoot to work correctly.

With these first two tips we are able to do the steps on this guide and get the
`OVMF_VARS.fd` set up with the certificates for our image testing.

#### Running the mender-convert'ed image

At the time of writing, we were not able to run it. The _closest_ we got is for
the kernel to start booting and crash. To get there, we need to modify a few
things in the `mender-convert-qemu` script:

1. Replace `-nographic` with `-vga virtio` (this is mainly to _see_ QEMU boot)
2. Add `-machine q35,smm=on -cpu host` options. The former is to enable
   SecureBoot but the latter has been found experimentally (maybe is wrong? or
   maybe does not have an effect?)
3. Remove `,readonly=on` from `OVMF_VARS`. Without this qemu crashes before
   starting the bootloader (??)

Even with these tweaks the kernel crashes, as stated above, so more reserach is
needed to get this up and running in Ubuntu 24.04
