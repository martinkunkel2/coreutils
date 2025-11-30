#!/bin/bash
set -eu
#cargo build
#cargo test ls
#./util/build-gnu.sh
#sudo ./util/run-gnu-test.sh tests/mv/hardlink-case
sudo killall -9 pseudo || true

#DESTDIR=/workspaces/coreutils/target/install-release make UTILS=ls PROFILE=release install
DESTDIR=/workspaces/coreutils/target/install-debug make UTILS=ls PROFILE=debug install

sudo apt-get update
sudo apt-get install libsqlite3-dev

cd target
git clone git://git.yoctoproject.org/pseudo || true
cd pseudo
./configure --prefix=/workspaces/coreutils/target/pseudo-install --bits=64
sed -i 's/^CFLAGS_DEBUG=-O2 -g$/CFLAGS_DEBUG=-g/' Makefile
make install
cd ..
cd ..

PSEUDO_PREFIX=/workspaces/coreutils/target/pseudo-install LD_LIBRARY_PATH=/workspaces/coreutils/target/pseudo-install/lib64 /workspaces/coreutils/target/pseudo-install/bin/pseudo /workspaces/coreutils/target/install-debug/usr/local/bin/ls --version

sudo killall -9 pseudo
