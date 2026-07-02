#!/usr/bin/env bash
# Validates the Docker publish vulnerability-scan floor and its exception-ticket
# policy, before any build/push so a misconfigured floor fails fast.
#
# Env:
#   FAILURE_SEVERITY  - Trivy failure floor. Must be EXACTLY one of the allowlist
#                       below. Trivy matches severities case-sensitively with no
#                       whitespace trimming, so we do NOT normalise: a lowercase,
#                       spaced or mis-ordered value is rejected here rather than
#                       passed on to fail the scan later with an opaque error.
#   EXCEPTION_TICKET  - Jira link justifying a CRITICAL-only floor (HIGH dropped).
#
# Outputs (GITHUB_OUTPUT):
#   failure_severity  - the validated failure floor, echoed back for the scan step
#                       so the value that gates Trivy is exactly the value checked.
#   scan_severity     - the report floor, always a superset of failure_severity so
#                       anything that can fail the build also appears in the
#                       uploaded SARIF report.
#
# Exit 0 = allowed; exit 1 = blocked. Format-check only — no live Jira call, so
# no token dependency. A CRITICAL-only floor waives HIGH gating, so it is recorded
# to the job summary + a ::notice:: as a durable audit trail.
set -euo pipefail

failure_severity="${FAILURE_SEVERITY:-}"

# Exact-match only against the Trivy-valid, canonically-ordered floors. Each maps
# to a scan (report) severity that is a superset of the failure floor.
case "$failure_severity" in
  CRITICAL,HIGH|CRITICAL,HIGH,MEDIUM)
    scan_severity="$failure_severity"
    echo "Vulnerability floor '${failure_severity}' includes HIGH — no exception ticket required."
    ;;
  CRITICAL)
    # HIGH dropped from the failure floor: still scan+report HIGH, and require a
    # tracked Jira exception ticket (validated below).
    scan_severity="CRITICAL,HIGH"
    ;;
  *)
    # Reject empty/unknown/lowercase/spaced/mis-ordered floors rather than passing
    # them to Trivy. Strip control chars from the echoed value so a crafted input
    # cannot inject a GitHub workflow command into the log.
    safe="$(printf '%s' "$failure_severity" | tr -d '[:cntrl:]')"
    echo "::error::Invalid vulnerability severity floor '${safe}'. Must be EXACTLY one of: CRITICAL, CRITICAL,HIGH, CRITICAL,HIGH,MEDIUM (uppercase, no spaces)."
    exit 1
    ;;
esac

if [[ "$failure_severity" == CRITICAL ]]; then
  # Require a format-valid Jira exception ticket. Reject a multi-line value first
  # so the anchored regex can't be defeated and no attacker-controlled newline can
  # inject a GitHub workflow command into the log.
  ticket="${EXCEPTION_TICKET:-}"
  if [[ "$ticket" == *$'\n'* ]]; then
    echo "::error::vulnerability_exception_ticket must be a single-line Jira URL."
    exit 1
  fi

  ticket_re='^https://thetradedesk\.atlassian\.net/browse/UID2-[0-9]+$'
  if [[ ! "$ticket" =~ $ticket_re ]]; then
    if [[ -z "$ticket" ]]; then
      echo "::error::Vulnerability floor 'CRITICAL' drops HIGH but no vulnerability_exception_ticket was supplied. Provide a Jira link (https://thetradedesk.atlassian.net/browse/UID2-1234) or raise the floor to CRITICAL,HIGH."
    else
      # Single-line (newline already rejected) — cannot start a workflow command mid-line.
      echo "::error::vulnerability_exception_ticket '${ticket}' is malformed. Expected https://thetradedesk.atlassian.net/browse/UID2-1234."
    fi
    exit 1
  fi

  # Allowed exception — leave a durable audit trail.
  echo "::notice::Vulnerability floor 'CRITICAL' (HIGH gating waived) justified by exception ticket ${ticket}."
  {
    echo "### ⚠️ Vulnerability floor exception"
    echo ""
    echo "- Failure floor: \`CRITICAL\` — HIGH severity gating **waived**"
    echo "- Exception ticket: ${ticket}"
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
fi

# Emit the validated floors for the scan step to consume.
{
  echo "failure_severity=${failure_severity}"
  echo "scan_severity=${scan_severity}"
} >> "${GITHUB_OUTPUT:-/dev/null}"
