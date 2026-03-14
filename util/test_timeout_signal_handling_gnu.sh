#!/bin/bash
# Test all signal handling cases against GNU timeout.
# Mirrors the test cases in tests/by-util/test_timeout.rs::test_signal_handling.

set -u

TIMEOUT_BIN="${1:-/usr/bin/timeout}"
PASS=0
FAIL=0

run_case() {
    local case_num="$1"
    local description="$2"
    local signal="$3"              # signal to send to timeout (empty = none, let it expire)
    local sig_arg="$4"             # -s argument (empty = default)
    local child_exit_code="$5"
    local expected_trap_sig="$6"   # signal the child should trap
    local expected_exit="$7"

    local args=()
    if [[ -n "$sig_arg" ]]; then
        args+=(-s "$sig_arg")
    fi

    local trap_cmd="trap 'echo child_received_signal; exit ${child_exit_code}' ${expected_trap_sig}; echo started; sleep 10"
    args+=(5 sh -c "$trap_cmd")

    if [[ -z "$signal" ]]; then
        # No external signal — just let it time out (use 1s timeout instead of 5)
        args=()
        if [[ -n "$sig_arg" ]]; then
            args+=(-s "$sig_arg")
        fi
        args+=(1 sh -c "$trap_cmd")

        output=$("$TIMEOUT_BIN" "${args[@]}" 2>&1)
        actual_exit=$?
    else
        "$TIMEOUT_BIN" "${args[@]}" &>/tmp/timeout_test_output &
        local pid=$!
        # Wait for child to start
        for _ in $(seq 1 50); do
            if grep -q "started" /tmp/timeout_test_output 2>/dev/null; then
                break
            fi
            sleep 0.05
        done
        kill "-${signal}" "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        actual_exit=$?
        output=$(cat /tmp/timeout_test_output)
        rm -f /tmp/timeout_test_output
    fi

    local status="PASS"
    local errors=""

    if [[ "$actual_exit" -ne "$expected_exit" ]]; then
        status="FAIL"
        errors="exit code: expected=$expected_exit actual=$actual_exit"
    fi

    if ! echo "$output" | grep -q "child_received_signal"; then
        status="FAIL"
        errors="${errors:+$errors; }child did not receive expected signal ($expected_trap_sig)"
    fi

    if [[ "$status" == "PASS" ]]; then
        PASS=$((PASS + 1))
        printf "  Case %d: PASS  — %s\n" "$case_num" "$description"
    else
        FAIL=$((FAIL + 1))
        printf "  Case %d: FAIL  — %s [%s]\n" "$case_num" "$description" "$errors"
    fi
}

echo "Testing signal handling with: $TIMEOUT_BIN"
echo "$("$TIMEOUT_BIN" --version 2>&1 | head -1)"
echo

#          #  description                              signal   -s arg    child_exit  trap_sig  expected_exit
run_case   1  "no signal, default -s (timeout)"        ""       ""        42          "TERM"    124
run_case   2  "no signal, -s SIGUSR1 (timeout)"        ""       "SIGUSR1" 42          "USR1"    124
run_case   3  "SIGTERM, default -s"                    "TERM"   ""        42          "TERM"    42
run_case   4  "SIGTERM, -s SIGUSR1"                    "TERM"   "SIGUSR1" 42          "TERM"    42
run_case   5  "SIGALRM, default -s (like timeout)"     "ALRM"   ""        42          "TERM"    124
run_case   6  "SIGALRM, -s SIGUSR1 (like timeout)"     "ALRM"   "SIGUSR1" 42          "USR1"    124
run_case   7  "SIGINT, default -s"                     "INT"    ""        42          "INT"     42
run_case   8  "SIGINT, -s SIGUSR1"                     "INT"    "SIGUSR1" 42          "INT"     42

echo
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL))"
exit "$FAIL"
