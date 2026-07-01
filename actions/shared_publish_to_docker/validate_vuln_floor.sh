#!/usr/bin/env bash
# Validates the Docker publish vulnerability-scan floor and its exception-ticket
# policy (UID2-6767), before any build/push so a misconfigured floor fails fast.
#
# Env:
#   FAILURE_SEVERITY  - Trivy failure floor. Must be one of the allowlist below.
#   EXCEPTION_TICKET  - Jira link justifying a CRITICAL-only floor (HIGH dropped).
#
# Exit 0 = allowed; exit 1 = blocked. Format-check only — no live Jira call, so
# no token dependency. A CRITICAL-only floor waives HIGH gating, so it is recorded
# to the job summary + a ::notice:: as durable SOC2 change-testing evidence.
set -euo pipefail

# Normalize: strip ALL whitespace and uppercase. Trivy severities are uppercase;
# the allowlist mirrors the Java publish path's documented set.
norm="$(printf '%s' "${FAILURE_SEVERITY:-}" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"

case "$norm" in
  CRITICAL,HIGH|CRITICAL,HIGH,MEDIUM)
    echo "Vulnerability floor '${norm}' includes HIGH — no exception ticket required."
    exit 0
    ;;
  CRITICAL)
    : # HIGH dropped — falls through to the exception-ticket requirement below.
    ;;
  *)
    # Reject empty/unknown/mis-ordered floors rather than passing them to Trivy.
    # $norm is whitespace-stripped, so it is safe to echo on one line.
    echo "::error::Invalid vulnerability severity floor '${norm}'. Must be one of: CRITICAL, CRITICAL,HIGH, CRITICAL,HIGH,MEDIUM (no spaces)."
    exit 1
    ;;
esac

# CRITICAL-only floor: require a format-valid Jira exception ticket. Reject a
# multi-line value first so the anchored regex can't be defeated and no attacker-
# controlled newline can inject a GitHub workflow command into the log.
ticket="${EXCEPTION_TICKET:-}"
if [[ "$ticket" == *$'\n'* ]]; then
  echo "::error::vulnerability_exception_ticket must be a single-line Jira URL."
  exit 1
fi

ticket_re='^https://thetradedesk\.atlassian\.net/browse/(UID2|EUID)-[0-9]+$'
if [[ ! "$ticket" =~ $ticket_re ]]; then
  if [[ -z "$ticket" ]]; then
    echo "::error::Vulnerability floor 'CRITICAL' drops HIGH but no vulnerability_exception_ticket was supplied. Provide a Jira link (https://thetradedesk.atlassian.net/browse/UID2-1234, UID2 or EUID) or raise the floor to CRITICAL,HIGH."
  else
    # Single-line (newline already rejected) — cannot start a workflow command mid-line.
    echo "::error::vulnerability_exception_ticket '${ticket}' is malformed. Expected https://thetradedesk.atlassian.net/browse/UID2-1234 (UID2 or EUID)."
  fi
  exit 1
fi

# Allowed exception — leave a durable audit trail (SOC2 rows 8/9).
echo "::notice::Vulnerability floor 'CRITICAL' (HIGH gating waived) justified by exception ticket ${ticket}."
{
  echo "### ⚠️ Vulnerability floor exception (UID2-6767)"
  echo ""
  echo "- Failure floor: \`CRITICAL\` — HIGH severity gating **waived**"
  echo "- Exception ticket: ${ticket}"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
