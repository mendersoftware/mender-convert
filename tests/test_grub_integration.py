#!/usr/bin/python
# Copyright 2022 Northern.tech AS
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

import pytest
import re
import os
import subprocess

from utils.common import (
    extract_partition,
    get_no_sftp,
)


@pytest.fixture(scope="function")
def cleanup_boot_scripts(request, connection):
    """Take a backup of the various grub.cfg files and restore them after the
    test. This is recommended for tests that call `grub-install` and/or
    `update-grub`, so that other tests can also run them from a pristine
    state."""

    connection.run(
        "cp $(find /boot/efi/EFI/ -name grub.cfg -not -path '*/EFI/BOOT/*') /data/grub-efi.cfg"
    )
    connection.run("cp /boot/grub/grub.cfg /data/grub-main.cfg")
    connection.run("cp /boot/grub-mender-grubenv.cfg /data/grub-mender-grubenv.cfg")

    def cleanup():
        connection.run(
            "mv /data/grub-efi.cfg $(find /boot/efi/EFI/ -name grub.cfg -not -path '*/EFI/BOOT/*')"
        )
        connection.run("mv /data/grub-main.cfg /boot/grub/grub.cfg")
        connection.run("mv /data/grub-mender-grubenv.cfg /boot/grub-mender-grubenv.cfg")

    request.addfinalizer(cleanup)


def check_all_root_occurrences_valid(grub_cfg):
    found_expected = False
    inside_10_header = False
    # One of the functions we define and use.
    expected = "mender_check_and_restore_env"
    with open(grub_cfg) as fd:
        lineno = 0
        for line in fd.readlines():
            lineno += 1
            if re.match(r'^\s*root="\$\{mender_grub_storage_device\}', line):
                continue

            if line.strip() == "### BEGIN /etc/grub.d/00_header ###":
                # We allow root references inside the 00_header, because they
                # are overriden by Mender later.
                inside_10_header = True
            elif line.strip() == "### END /etc/grub.d/00_header ###":
                inside_10_header = False
            if not inside_10_header and re.match(r"^\s*(set +)?root=", line):
                pytest.fail(
                    "Found unexpected occurrence of `root=` in grub boot script\n"
                    "%d:%s" % (lineno, line)
                )

            if line.find(expected) >= 0:
                found_expected = True

    assert found_expected, "Expected content (%s) not found" % expected


@pytest.mark.usefixtures("setup_board", "cleanup_boot_scripts")
class TestGrubIntegration:
    @pytest.mark.min_mender_version("1.0.0")
    def test_no_root_occurrences(self, connection, latest_part_image):
        """Test that the generated grub scripts do not contain any occurrences of
        `root=<something>` except for known instances that we control. This is
        important because Mender needs to keep tight control of when this
        variable is set, in order to boot from, and mount, the correct root
        partition."""

        # First, check that the offline generated scripts don't have any.
        extract_partition(latest_part_image, 1)
        try:
            subprocess.check_call(
                ["mcopy", "-i", "img1.fs", "::/grub-mender-grubenv/grub.cfg", "."]
            )
            check_all_root_occurrences_valid("grub.cfg")
        finally:
            os.remove("img1.fs")
            os.remove("grub.cfg")

        extract_partition(latest_part_image, 2)
        try:
            subprocess.check_call(
                [
                    "debugfs",
                    "-R",
                    "dump -p /boot/grub-mender-grubenv.cfg grub-mender-grubenv.cfg",
                    "img2.fs",
                ]
            )
            check_all_root_occurrences_valid("grub-mender-grubenv.cfg")
        finally:
            os.remove("img2.fs")
            os.remove("grub-mender-grubenv.cfg")

        # Then, check that the runtime generated scripts don't have any.
        get_no_sftp("/boot/grub/grub.cfg", connection)
        try:
            check_all_root_occurrences_valid("grub.cfg")
        finally:
            os.remove("grub.cfg")

        get_no_sftp("/boot/grub-mender-grubenv.cfg", connection)
        try:
            check_all_root_occurrences_valid("grub-mender-grubenv.cfg")
        finally:
            os.remove("grub-mender-grubenv.cfg")

        # Check again after running `update-grub`.
        connection.run("grub-install && update-grub")
        get_no_sftp("/boot/grub/grub.cfg", connection)
        try:
            check_all_root_occurrences_valid("grub.cfg")
        finally:
            os.remove("grub.cfg")

        get_no_sftp("/boot/grub-mender-grubenv.cfg", connection)
        try:
            check_all_root_occurrences_valid("grub-mender-grubenv.cfg")
        finally:
            os.remove("grub-mender-grubenv.cfg")

    @pytest.mark.min_mender_version("1.0.0")
    def test_offline_and_runtime_boot_scripts_identical(self, connection):
        # Update scripts at runtime.
        connection.run("grub-install && update-grub")

        # Take advantage of the copies already made by cleanup_boot_scripts
        # fixture above, and use the copies in /data.

        # Take into account some known, but harmless differences. The "hd0,gpt1"
        # style location is missing from the offline generated grub-efi.cfg
        # file, but it is harmless because the filesystem UUID is being used
        # instead.
        connection.run(
            r"sed -Ee 's/ *hd[0-9]+,gpt[0-9]+//' "
            "$(find /boot/efi/EFI/ -name grub.cfg -not -path '*/EFI/BOOT/*') "
            "> /data/new-grub-efi-modified.cfg"
        )
        try:
            connection.run("diff -u /data/grub-efi.cfg /data/new-grub-efi-modified.cfg")
        finally:
            connection.run("rm -f /data/new-grub-efi-modified.cfg")

        # Another few differences we work around in the main grub files:
        # * `--hint` parameters are not generated in offline copy.
        # * `root` variable is not set in offline copy.
        # * `fwsetup` is added somewhat randomly depending on availability both
        #   on build host and device.
        try:
            connection.run("cp /data/grub-main.cfg /data/old-grub-modified.cfg")
            connection.run("cp /boot/grub/grub.cfg /data/new-grub-modified.cfg")
            connection.run(
                r"sed -i -En -e '/\bsearch\b/{s/ --hint[^ ]*//g;}' "
                "-e \"/^set root='hd0,gpt1'$/d\" "
                r"-e '\,### BEGIN /etc/grub.d/30_uefi-firmware ###,{p; n; :loop; \,### END /etc/grub.d/30_uefi-firmware ###,b end; n; b loop; :end;}' "
                "-e p "
                "/data/old-grub-modified.cfg /data/new-grub-modified.cfg"
            )
            connection.run("diff -u /data/old-grub-modified.cfg /data/new-grub-modified.cfg")
        finally:
            connection.run("rm -f /data/old-grub-modified.cfg /data/new-grub-modified.cfg")

        # Same differences as in previous check.
        try:
            connection.run("cp /data/grub-mender-grubenv.cfg /data/old-grub-mender-grubenv-modified.cfg")
            connection.run("cp /boot/grub-mender-grubenv.cfg /data/new-grub-mender-grubenv-modified.cfg")
            connection.run(
                r"sed -i -En -e '/\bsearch\b/{s/ --hint[^ ]*//g;}' "
                "-e \"/^set root='hd0,gpt1'$/d\" "
                r"-e '\,### BEGIN /etc/grub.d/30_uefi-firmware ###,{p; n; :loop; \,### END /etc/grub.d/30_uefi-firmware ###,b end; n; b loop; :end;}' "
                "-e p "
                "/data/old-grub-mender-grubenv-modified.cfg /data/new-grub-mender-grubenv-modified.cfg"
            )
            connection.run(
                "diff -u /data/old-grub-mender-grubenv-modified.cfg /data/new-grub-mender-grubenv-modified.cfg"
            )
        finally:
            connection.run("rm -f /data/old-grub-mender-grubenv-modified.cfg /data/new-grub-mender-grubenv-modified.cfg")
