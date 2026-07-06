#!/usr/bin/env bash
# Pure matcher for the check_jira_key composite action (UID2-7426). Reads its inputs from the
# environment and does NO network I/O, so it is unit-testable (tests/match.test.sh). action.yaml
# gathers the inputs (gh api) + the squash-config tripwire, then calls this.
#
# Assumes the repo squashes with squash_merge_commit_title=COMMIT_OR_PR_TITLE and
# squash_merge_commit_message=COMMIT_MESSAGES (see action.yaml). Under that config the squash commit
# GitHub lands is: subject = the single commit's first line (1-commit PR) or the PR title
# (multi-commit); body = all commit messages concatenated.
#
# Inputs (env): PR_TITLE, COMMIT_COUNT, ALL_MSGS, FIRST_LINE.
set -uo pipefail
export LC_ALL=C.UTF-8   # grep -P (PCRE) errors under a non-UTF-8 locale

# SINGLE SOURCE OF TRUTH regex — kept byte-identical to the self-assertion in
# actions/commit_pr_and_merge/action.yaml (enforced by tests/regex_identity.test.sh) and to
# local.jira_key_pattern in uid2-okta-configuration. The \b blocks FOOUID2-1; \S blocks a blank reason.
PATTERN='\bUID2-[0-9]+|\[no-jira - reason:\s*\S[^\]]*\]'

PR_TITLE="${PR_TITLE:-}"
COMMIT_COUNT="${COMMIT_COUNT:-0}"
ALL_MSGS="${ALL_MSGS:-}"
FIRST_LINE="${FIRST_LINE:-}"

# Reconstruct the squash commit under the assumed config.
if [ "$COMMIT_COUNT" -eq 1 ]; then SUBJECT="$FIRST_LINE"; else SUBJECT="$PR_TITLE"; fi
BODY="$ALL_MSGS"

# Search subject and body INDEPENDENTLY — never concatenate. For a single-commit PR the subject
# (first line) is contained in the body (its full message); concatenating could create a spurious
# cross-boundary match (e.g. a blank "[no-jira - reason: ]" pairing its own "]" with the body copy).
if printf '%s' "$SUBJECT" | grep -Pq "$PATTERN" || printf '%s' "$BODY" | grep -Pq "$PATTERN"; then
  echo "✓ A UID2-<n> key or reasoned [no-jira - reason: …] opt-out is present in the commit that will land."
  exit 0
fi

if [ "$COMMIT_COUNT" -eq 1 ]; then
  WHATLANDS="your **single commit's message**"
  FIX="reword the commit (e.g. \`git commit --amend\`) to include it"
else
  WHATLANDS="the **PR title** or one of your **commit messages**"
  FIX="put it in the PR title or a commit message"
fi
echo "::error title=Missing Jira key::The squash commit that will merge to the default branch has no UID2-<n> key and no reasoned opt-out."
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### ❌ Jira-key check failed"
    echo ""
    echo "Every change merged to the default branch must carry, **in the commit that lands**, either a \`UID2-<n>\` key (uppercase) or a reasoned \`[no-jira - reason: <reason>]\` opt-out (lowercase, reason mandatory)."
    echo ""
    echo "Your PR has **${COMMIT_COUNT}** commit(s), so what lands is ${WHATLANDS}."
    echo ""
    echo "Fix: ${FIX}."
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit 1
