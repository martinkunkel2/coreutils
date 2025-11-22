#!/bin/bash
set -eu

# Start VM
#limactl start --plain --name=default --cpus=4 --disk=40 --memory=8 --network=lima:user-v2 template:ubuntu
limactl start --name=default --cpus=4 --disk=40 --memory=8 --network=lima:user-v2

# Install dependencies in VM
lima sudo apt-get update
lima sudo apt-get install -y autoconf autopoint bison texinfo gperf gcc g++ gdb hfsprogs python3-pyinotify jq valgrind libexpect-perl libacl1-dev libattr1-dev libcap-dev libselinux1-dev attr quilt
lima rustup-init -y --default-toolchain stable
