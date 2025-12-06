#!/bin/bash
set -eu
cargo test --package uucore --lib -- features::mode::test
UTILS="chmod install mkdir mkfifo mknod" make test
#cargo build
#cargo test fmt
#./util/build-gnu.sh
#sudo locale-gen ru_RU.KOI8-R
#./util/run-gnu-test.sh tests/fmt/non-space
