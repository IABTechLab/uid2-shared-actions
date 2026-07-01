#!/usr/bin/env bash
# Tests for validate_vuln_floor.sh — run: bash actions/shared_publish_to_docker/tests/test_validate_vuln_floor.sh
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/validate_vuln_floor.sh"
fail=0

assert_eq() { # $1=desc $2=expected $3=actual
  if [[ "$2" == "$3" ]]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2' got '$3'"; fail=1; fi
}
assert_contains() { # $1=desc $2=needle $3=haystack
  if [[ "$3" == *"$2"* ]]; then echo "ok   - $1"; else echo "FAIL - $1: '$3' missing '$2'"; fail=1; fi
}

# Runs the guard with FAILURE_SEVERITY=$1, EXCEPTION_TICKET=$2; captures combined
# output in $OUTPUT, exit code in $RC, and the job-summary file in $SUMMARY.
run() {
  SUMMARY="$(mktemp)"
  OUTPUT="$(FAILURE_SEVERITY="${1-}" EXCEPTION_TICKET="${2-}" GITHUB_STEP_SUMMARY="$SUMMARY" bash "$SCRIPT" 2>&1)"; RC=$?
}

# --- Standard floors: pass, no ticket needed ---
run "CRITICAL,HIGH" ""
assert_eq       "CRITICAL,HIGH: pass"        "0" "$RC"
run "CRITICAL,HIGH,MEDIUM" ""
assert_eq       "CRITICAL,HIGH,MEDIUM: pass" "0" "$RC"
run "critical,high" ""
assert_eq       "lowercase: pass"            "0" "$RC"
run "CRITICAL, HIGH" ""
assert_eq       "spaced: pass"               "0" "$RC"

# --- CRITICAL-only: needs a valid ticket ---
run "CRITICAL" "https://thetradedesk.atlassian.net/browse/UID2-6767"
assert_eq       "CRITICAL+UID2 ticket: pass" "0" "$RC"
assert_contains "CRITICAL+ticket: notice"    "::notice::" "$OUTPUT"
assert_contains "CRITICAL+ticket: audit summary" "Vulnerability floor exception" "$(cat "$SUMMARY")"
assert_contains "CRITICAL+ticket: ticket in summary" "UID2-6767" "$(cat "$SUMMARY")"

run "CRITICAL" "https://thetradedesk.atlassian.net/browse/EUID-123"
assert_eq       "CRITICAL+EUID ticket: block (only UID2 accepted)" "1" "$RC"

run "CRITICAL" ""
assert_eq       "CRITICAL no ticket: block"  "1" "$RC"
assert_contains "CRITICAL no ticket: msg"    "no vulnerability_exception_ticket was supplied" "$OUTPUT"

run "CRITICAL" "https://evil.com/UID2-1"
assert_eq       "CRITICAL bad host: block"   "1" "$RC"
assert_contains "CRITICAL bad host: msg"     "malformed" "$OUTPUT"

run "CRITICAL" "https://thetradedesk.atlassian.net/browse/JIRA-1"
assert_eq       "CRITICAL wrong project: block" "1" "$RC"

run "CRITICAL" $'https://thetradedesk.atlassian.net/browse/UID2-1\n::set-output name=x::y'
assert_eq       "CRITICAL newline ticket: block" "1" "$RC"
assert_contains "CRITICAL newline: msg"      "single-line" "$OUTPUT"

# --- Invalid floors: reject rather than pass to Trivy ---
run "HIGH" ""
assert_eq       "HIGH-only (drops CRITICAL): block" "1" "$RC"
assert_contains "HIGH-only: invalid msg"     "Invalid vulnerability severity floor" "$OUTPUT"
run "" ""
assert_eq       "empty floor: block"         "1" "$RC"
run "FOO,BAR" ""
assert_eq       "garbage floor: block"       "1" "$RC"

exit $fail
