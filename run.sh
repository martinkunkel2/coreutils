#!/bin/bash
set -eu
cargo build
#cargo test ls
./util/build-gnu.sh
sudo ./util/run-gnu-test.sh tests/mv/hardlink-case
