#!/usr/bin/env bash
# Unit tests for ../match.sh — run: bash actions/check_jira_key/tests/match.test.sh
# Auto-run in CI by .github/workflows/test-scripts.yaml (actions/**/tests/*.sh).
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/match.sh"
fail=0

# check: desc  expected_rc  PR_TITLE  COMMIT_COUNT  ALL_MSGS  FIRST_LINE
# expected_rc 0 = pass (key/opt-out present in what lands), 1 = fail (missing)
check() {
  local desc="$1" exp="$2" title="$3" count="$4" allmsgs="$5" first="$6" rc
  PR_TITLE="$title" COMMIT_COUNT="$count" ALL_MSGS="$allmsgs" FIRST_LINE="$first" \
    bash "$SCRIPT" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq "$exp" ]; then echo "ok   - $desc"; else echo "FAIL - $desc: expected rc=$exp got $rc"; fail=1; fi
}

check "single-commit, key in commit"            0 "misc"                    1 "UID2-1234 fix" "UID2-1234 fix"
check "single-commit, key ONLY in PR title"     1 "UID2-1234 fix"           1 "fix thing"     "fix thing"
check "CI release marker in commit"             0 "[CI Pipeline] Released"  1 "[CI Pipeline] Released 5.70.207 [no-jira - reason: automated release v5.70.207]" "[CI Pipeline] Released 5.70.207 [no-jira - reason: automated release v5.70.207]"
check "multi-commit, key in PR title"           0 "UID2-7056 deploy"        2 "$(printf 'fix a\nfix b')" "fix a"
check "multi-commit, key in one commit"         0 "chore"                   2 "$(printf 'bump x\nUID2-9 tweak')" "bump x"
check "single-commit, key in commit body"       0 "fix"                     1 "$(printf 'fix thing\n\nUID2-99 in body')" "fix thing"
check "no key anywhere"                          1 "update stuff"            2 "$(printf 'update stuff\nmore')" "update stuff"
check "blank opt-out reason fails"               1 "x"                       1 "cleanup [no-jira - reason: ]" "cleanup [no-jira - reason: ]"
check "reasoned opt-out in commit"              0 "x"                       1 "cleanup [no-jira - reason: automated dep bump]" "cleanup [no-jira - reason: automated dep bump]"
check "FOOUID2-1 must not satisfy"              1 "x"                       1 "FOOUID2-1 sneaky" "FOOUID2-1 sneaky"
check "tf-modules bump marker"                  0 "Update tf"               1 "chore: update terraform_modules_version to v1.453 [no-jira - reason: automated tf-modules bump v1.453]" "chore: update terraform_modules_version to v1.453 [no-jira - reason: automated tf-modules bump v1.453]"

echo ""
if [ "$fail" -eq 0 ]; then echo "match.test.sh: ALL PASS"; else echo "match.test.sh: FAILURES"; fi
exit "$fail"
