#!/bin/bash

set -eu

apt-get update
# https://github.com/uutils/coreutils/blob/4bbbb972ad956afaf1f0df4f1132a3a38bfac009/.github/workflows/GnuTests.yml#L153
apt-get install -y autoconf autopoint bison texinfo gperf gcc g++ gdb python3-pyinotify jq valgrind libexpect-perl libacl1-dev libattr1-dev libcap-dev libselinux1-dev attr quilt

pip3 install --break-system-packages pre-commit

# otherwise cargo test will run tests that require root permission, some of them fail in container
rm /etc/sudoers.d/vscode
