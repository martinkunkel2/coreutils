#!/bin/bash
set -eu

cargo build
./util/build-gnu.sh

#cargo test ls

# jq -r 'to_entries[] | .key as $cmd | .value | to_entries[] | select(.value == "SKIP") | "tests/\($cmd)/\(.key)" | sub("\\.log$"; "")' /workspaces/coreutils/result.json | tr '\n' ' '

#./util/run-gnu-test.sh tests/cp/cp-mv-enotsup-xattr 
#./util/run-gnu-test.sh tests/cp/nfs-removal-race 
#./util/run-gnu-test.sh tests/csplit/csplit-io-err 
#./util/run-gnu-test.sh tests/date/date-ethiopia 
#./util/run-gnu-test.sh tests/date/date-iran 
#./util/run-gnu-test.sh tests/date/date-thailand 
#./util/run-gnu-test.sh tests/df/no-mtab-status 
#./util/run-gnu-test.sh tests/df/skip-duplicates 
./util/run-gnu-test.sh tests/df/skip-rootfs 
#./util/run-gnu-test.sh tests/id/gnu-zero-uids 
#./util/run-gnu-test.sh tests/id/smack 
#./util/run-gnu-test.sh tests/misc/coreutils 
#./util/run-gnu-test.sh tests/mkdir/smack-no-root 
#./util/run-gnu-test.sh tests/mkdir/smack-root
#./util/run-gnu-test.sh tests/mkdir/writable-under-readonly 
#./util/run-gnu-test.sh tests/mv/hardlink-case 
#./util/run-gnu-test.sh tests/mv/i-3 
#./util/run-gnu-test.sh tests/nproc/nproc-quota 
#./util/run-gnu-test.sh tests/numfmt/mb-non-utf8 
#./util/run-gnu-test.sh tests/pr/pr-tests  
#./util/run-gnu-test.sh tests/rm/fail-eperm
#./util/run-gnu-test.sh tests/rm/r-root 
#./util/run-gnu-test.sh tests/rm/rm-readdir-fail 
#./util/run-gnu-test.sh tests/stty/bad-speed 
#./util/run-gnu-test.sh tests/stty/stty-invalid 
#./util/run-gnu-test.sh tests/stty/stty-pairs 
#./util/run-gnu-test.sh tests/stty/stty-row-col 
#./util/run-gnu-test.sh tests/stty/stty 
#./util/run-gnu-test.sh tests/tac/tac-continue 
#./util/run-gnu-test.sh tests/tail/inotify-dir-recreate 
#./util/run-gnu-test.sh tests/tail/inotify-race 
#./util/run-gnu-test.sh tests/tail/inotify-race2 
#./util/run-gnu-test.sh tests/timeout/timeout-group 
#./util/run-gnu-test.sh 
#./util/run-gnu-test.sh 