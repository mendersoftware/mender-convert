#!/bin/bash
# Copyright 2026 Northern.tech AS
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

set -e

OVMF_VARS=$(mktemp /tmp/OVMF_VARS_4M.XXXXXX.fd)
cp /usr/share/OVMF/OVMF_VARS_4M.fd "$OVMF_VARS"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"

qemu-system-x86_64 -machine q35 \
                   -m 8G \
                   -accel kvm \
                   -cpu host \
                   -smp 2 \
                   -boot menu=on,splash-time=3000 \
                   -vga virtio \
                   -net user,hostfwd=tcp::8822-:22 \
                   -net nic,macaddr=52:54:00$(od -txC -An -N3 /dev/urandom | tr \  :) \
                   -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE" \
                   -drive if=pflash,format=raw,unit=1,file="$OVMF_VARS" \
                   -drive format=raw,file="$1"

trap 'rm -f "$OVMF_VARS"' EXIT
