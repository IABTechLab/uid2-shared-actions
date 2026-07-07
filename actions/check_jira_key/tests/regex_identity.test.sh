#!/usr/bin/env bash
# Drift guard (UID2-7426): the SSOT Jira-key regex must be byte-identical across its in-repo copies
# — the check_jira_key matcher and the commit_pr_and_merge self-assertion. This test READS the real
# files (not a copy), so it cannot itself drift. Auto-run by .github/workflows/test-scripts.yaml.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MATCH="$HERE/../match.sh"
CPAM="$HERE/../../commit_pr_and_merge/action.yaml"
fail=0

# Extract the single-quoted regex string that contains "UID2-" from a file (ERE, no PCRE needed).
extract() { grep -oE "'[^']*UID2-[^']*'" "$1" | head -1 | sed "s/^'//; s/'\$//"; }

A="$(extract "$MATCH")"
B="$(extract "$CPAM")"
echo "check_jira_key/match.sh   : $A"
echo "commit_pr_and_merge/action: $B"

if [ -z "$A" ]; then echo "FAIL - could not extract regex from match.sh"; fail=1; fi
if [ -z "$B" ]; then echo "FAIL - could not extract regex from commit_pr_and_merge/action.yaml"; fail=1; fi
if [ -n "$A" ] && [ "$A" = "$B" ]; then
  echo "ok   - SSOT regex is byte-identical across both copies"
else
  echo "FAIL - SSOT regex drift between the two in-repo copies"; fail=1
fi
exit "$fail"
