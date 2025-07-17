#!/bin/bash
set -eu
cargo build
cargo test cp
./util/build-gnu.sh

./util/run-gnu-test.sh tests/cp/link-heap
