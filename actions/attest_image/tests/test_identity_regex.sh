#!/usr/bin/env bash
# Tests the certificate identity policy embedded in ../action.yaml.
set -euo pipefail

action_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/action.yaml"

python3 - "$action_file" <<'PY'
import re
import sys
from pathlib import Path

action = Path(sys.argv[1]).read_text()
match = re.search(r'--cert-identity-regex "([^"]+)"', action)
if not match:
    raise AssertionError("certificate identity regex not found in action.yaml")

identity_regex = match.group(1).replace(
    "${{ github.repository }}", "IABTechLab/uid2-examples"
)
policy = re.compile(identity_regex)

accepted = [
    "https://github.com/IABTechLab/uid2-shared-actions/.github/workflows/publish.yaml@refs/tags/v3",
    "https://github.com/iabtechlab/uid2-shared-actions/.github/workflows/publish.yaml@refs/tags/v3",
    "https://github.com/IABTechLab/uid2-examples/.github/workflows/release.yaml@refs/heads/main",
    "https://github.com/iabtechlab/uid2-examples/.github/workflows/release.yaml@refs/heads/main",
]
rejected = [
    "https://github.com/IABTechLab/uid2-shared-actions-malicious/.github/workflows/publish.yaml@refs/tags/v3",
    "https://github.com/other-org/uid2-examples/.github/workflows/release.yaml@refs/heads/main",
    "https://example.com/IABTechLab/uid2-shared-actions/.github/workflows/publish.yaml@refs/tags/v3",
]

for identity in accepted:
    if not policy.match(identity):
        raise AssertionError(f"expected identity to be accepted: {identity}")

for identity in rejected:
    if policy.match(identity):
        raise AssertionError(f"expected identity to be rejected: {identity}")

print("certificate identity regex tests passed")
PY
