UEFI NVRAM
==========

This directory holds the NVRAM file which is used as the firmware memory of the UEFI software which
runs under QEMU. It's main purpose is to start the UEFI software with certificates pre-loaded into
the firmware memory, and Secure Boot enabled.

How to recreate the `OVMF_VARS.fd` file
--------------------------------

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
