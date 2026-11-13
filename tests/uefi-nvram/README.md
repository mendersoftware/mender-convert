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
shipped by Debian 13 / Ubuntu 24.04 and newer: which firmware and QEMU machine we
use when Secure Boot is on vs. off, and why Ubuntu images currently cannot be
tested with Secure Boot enabled.

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

#### Secure Boot on vs. off, and the q35 / Ubuntu limitation

The 4M `OVMF_CODE_4M.secboot.fd` is built `SMM_REQUIRE`, so it only initializes
on a `q35` machine with `smm=on` and a secure pflash. `scripts/test/mender-convert-qemu`
therefore picks the machine based on whether Secure Boot is being tested:

* **Secure Boot on** (default, e.g. the Debian grub.d images): the `.secboot`
  firmware plus the Microsoft-enrolled vars store (`OVMF_VARS_4M.ms.fd`), run on
  `-machine q35,smm=on` with a secure pflash. This is real, SMM-protected Secure
  Boot.
* **Secure Boot off** (`QEMU_NO_SECURE_BOOT=1`): the plain `OVMF_CODE_4M.fd`,
  which is not `SMM_REQUIRE` and so boots on the default i440fx machine.

The machine choice matters because `q35` moves the guest disk from IDE to
SATA/AHCI. Guests whose initramfs lacks the `ahci` driver -- notably our
converted **Ubuntu** images -- hang on `Waiting for root device /dev/sda2` under
`q35` and never boot. Debian's initramfs has `ahci`, so Debian boots fine and
gets full Secure Boot testing. Ubuntu cannot currently boot the `.secboot` / q35
firmware, so `scripts/test/run-tests.sh` runs the Ubuntu images with
`QEMU_NO_SECURE_BOOT=1` (plain firmware, i440fx). The plain firmware exposes no
Secure Boot state, so `mokutil --sb-state` cannot report it, and the
`test_secure_boot` test skips itself in that case.

#### Impact and the planned fix

Right now Debian gets real Secure Boot coverage on modern hosts; Ubuntu boots
and runs the rest of the suite, but its Secure Boot state is not verified.

The planned fix (tracked as a follow-up) is to attach the test disk as
`virtio-blk` (`/dev/vda`) instead of IDE/SATA. `virtio` is machine-independent
(it works under `q35`) and `virtio_blk` is present in both Debian and Ubuntu
cloud initramfs, so both distros would then boot under the `.secboot` / q35
firmware and get real Secure Boot testing. That requires switching
`MENDER_STORAGE_DEVICE_BASE` to `/dev/vda` in the `*-qemux86-64` configs and the
qemu run scripts together.
