#!/bin/bash
set -eu
cargo build
#cargo test tail
./util/build-gnu.sh

./util/run-gnu-test.sh tests/tail/overlay-headers
