#!/bin/bash
set -eu
cargo build
cargo test timeout
./util/build-gnu.sh
./util/run-gnu-test.sh tests/timeout/timeout
