#!/bin/bash
set -eu
cargo build
cargo test test_timeout
./util/build-gnu.sh
./util/run-gnu-test.sh tests/timeout/timeout-blocked tests/timeout/timeout-group tests/timeout/timeout-large-parameters tests/timeout/timeout-parameters tests/timeout/timeout
