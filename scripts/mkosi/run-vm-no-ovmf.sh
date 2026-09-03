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

qemu-system-x86_64 \
    -enable-kvm \
    -m 8G \
    -smp 2 \
    -nic user,model=virtio \
    -net user,hostfwd=tcp::8822-:22 \
    -net nic,macaddr=52:54:00$(od -txC -An -N3 /dev/urandom | tr \  :) \
    -serial mon:stdio \
    -nographic \
    -drive format=raw,file="$1"
