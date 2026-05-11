# UID2-6764: Artifact Signing & Provenance for Docker Images — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add SLSA build provenance attestations to every Docker image published by the shared workflows in `uid2-shared-actions`, so external parties (and SOC2 auditors) can cryptographically verify that a `ghcr.io/iabtechlab/...` image was built from a specific source commit by a specific GitHub Actions workflow.

**Architecture:** Insert `actions/attest@v4` after the image push step in each shared publish workflow / composite action. The action takes the image name + digest emitted by `docker/build-push-action`, auto-generates a SLSA v1 build-provenance predicate from the workflow runtime context, signs an in-toto statement using GitHub's OIDC identity (Sigstore keyless), and uploads the signed bundle both to GitHub's attestation API and (with `push-to-registry: true`) to the OCI registry alongside the image. Caller workflows opt in by adding `id-token: write` and `attestations: write` permissions; the existing `packages: write` is already present.

> **Note on action choice:** GitHub consolidated `actions/attest-build-provenance`, `actions/attest-sbom`, and the generic `actions/attest` into `actions/attest@v4`. The wrappers are now thin shims around it, and GitHub's README states *"new implementations should use `actions/attest` instead."* Output (signed SLSA v1 in-toto statement) is byte-for-byte equivalent to what the wrapper produced; verification with `gh attestation verify` is unchanged. Using `actions/attest` directly avoids tracking a redundant pinned dependency and lets us extend the same step for SBOMs in future without adding a second action. The UID2-5763 PoC validated `attest-build-provenance` end-to-end; that validation transfers since the underlying signing path is identical.

**Tech Stack:** GitHub Actions, `actions/attest@v4`, `docker/build-push-action@v5` (already used), `sigstore/cosign-installer@v4` (already a transitive dep, install explicitly for determinism), `gh attestation verify` CLI.

---

## Revised Execution Order (2026-05-06, updated 2026-05-08)

The original plan tested both Java and non-Java paths against the feature branch before merging to `main`. We're switching to a faster path because the change is small and the worst case is recoverable:

1. - [x] **Tasks 0–3**: complete (commits `d61cdd8`, `c8fbbaf`, `11649c6` on `bmz-UID2-6764-artifact-attestation`, pushed to origin).
2. - [x] **Snapshot smoke test** (subset of Task 4): pinned `uid2-admin` test branch `bmz-UID2-6764-test` to the feature branch and ran a `Snapshot` publish — [run 25421656856](https://github.com/IABTechLab/uid2-admin/actions/runs/25421656856) succeeded; "Attest build provenance" step was skipped via the `not_snapshot` guard. `gh attestation verify` against the snapshot tag failed with `remote registry authorization failed` rather than `no attestations found`, but the workflow log confirms the step was not executed.
2b. - [x] **Real attest+verify smoke test** (added 2026-05-08 in response to jon8787's review comment #1): added a throwaway `.github/workflows/test-attest-image.yaml`, exercised the full attest+verify path against a busybox-style image, captured evidence, then deleted the workflow in commit `3954ca4`. [Run 25542801315](https://github.com/IABTechLab/uid2-shared-actions/actions/runs/25542801315) green; external `gh attestation verify oci://ghcr.io/iabtechlab/uid2-shared-actions/test-attest@sha256:e008cbdd...` returned exit 0 with SLSA v1 provenance traceable back to the workflow file at the exact branch ref.
3. - [ ] **Open PR + merge `uid2-shared-actions` to main** (Task 6, brought forward). PR [#228](https://github.com/IABTechLab/uid2-shared-actions/pull/228) is **OPEN**; CI green; jon8787 left 5 review comments — all addressed in commits `9c2bb4d` → `3954ca4` (see addendum below); inline replies posted. Awaiting re-review/merge.
4. - [ ] **Delete the snapshot-test branch in the consumer repo** — `git push origin --delete bmz-UID2-6764-test` on `IABTechLab/uid2-admin` (still present as of 2026-05-08; do this once v3 is promoted).
5. - [ ] **Promote `v3` float** (Task 6 step 2). `v3` currently points at `6ea068b` (pre-attestation merge of PR #226); not yet moved. Run `update-major-version-tags.yaml` *immediately* after merging #228 — the refactored shared workflows reference `actions/attest_image@v3`, so the window between merge and tag promotion is a window where consumers triggering would fail with "action not found".
6. - [ ] **Full release-tag E2E verification** (original Task 4 release-test step + Task 5) — done on each consumer's first real publish after the rollout PR lands. With the in-action `gh attestation verify` step from the refactor, every release self-verifies in CI before any external check is needed; the external `gh attestation verify --owner UnifiedID2` call from Task 4 step 4 / Task 5 still needs to happen once per consumer to record evidence in UID2-6764.
7. - [x] **Consumer rollout PRs** (Task 8 step 1) — opened 2026-05-08 in all 6 consumer repos:
   - [IABTechLab/uid2-operator#2531](https://github.com/IABTechLab/uid2-operator/pull/2531) — `publish-public-operator-docker-image.yaml` (job had no `permissions:` block; full block added with the implicit defaults the publish job relied on)
   - [IABTechLab/uid2-core#403](https://github.com/IABTechLab/uid2-core/pull/403) — `release-docker-image.yaml`
   - [IABTechLab/uid2-admin#632](https://github.com/IABTechLab/uid2-admin/pull/632) — `release-docker-image.yaml`
   - [IABTechLab/uid2-optout#402](https://github.com/IABTechLab/uid2-optout/pull/402) — `release-docker-image.yaml`
   - [UnifiedID2/uid2-snowflake#299](https://github.com/UnifiedID2/uid2-snowflake/pull/299) — `publish-docker.yaml` (TWO calling jobs in one workflow: `build-publish-etl` uses Java path, `build-publish-monitoring` uses non-Java path — single repo exercises both)
   - [UnifiedID2/uid2-databricks#132](https://github.com/UnifiedID2/uid2-databricks/pull/132) — `publish-monitoring-docker.yaml` (uses the composite action `actions/shared_publish_to_docker@v3`, not the wrapper workflow — same permissions still required)

   **Repo-name correction:** the original plan listed `IABTechLab/uid2-snowflake-integration` and `IABTechLab/uid2-databricks-integration`; those repos don't exist. The actual non-Java consumer repos are `UnifiedID2/uid2-snowflake` and `UnifiedID2/uid2-databricks` (private). All six PRs await review/merge — they're additive and harmless until `v3` carries the `actions/attest@v4` step.
8. - [ ] **Docs** (Task 7) — **deferred until everything else is done** (per user 2026-05-08). Write after at least one Java + one non-Java release-tag verification so the doc reflects real attestation contents.
9. - [ ] **SDK follow-up ticket** (Task 8 step 3) — **deferred until everything else is done** (per user 2026-05-08).

> **Branch tip:** `d9ea448` (2026-05-11).

---

## Addendum: end-to-end smoke on uid2-test-source (2026-05-11)

To exercise the full shared workflow chain (not just the composite action in isolation), wired up `UnifiedID2/uid2-test-source` on a throwaway `release-UID2-6764-smoke` branch to call `shared-publish-to-docker-versioned.yaml` at a temporary smoke branch (`bmz-UID2-6764-smoke`, since deleted) that repinned internal `@v2`/`@v3` references to itself.

**Why a temp smoke branch?** Three nested pin chains needed redirecting at once for the test to exercise the new code on a release-prefix branch (which the test workflow ran on):

1. wrapper workflow → `shared_publish_setup@v2` → `check_branch_and_release_type@v2` (the v2 path only allows the default branch; we need v3 which also allows `release-*` prefixes).
2. wrapper workflow → `shared_publish_to_docker@v3` (the version published before this PR didn't have `attest_image`).
3. `shared_publish_to_docker` → `attest_image@v3` (the tag won't have `attest_image` until `update-major-version-tags.yaml` runs post-merge).

Redirecting all three to the smoke branch (which had the new code) was the cleanest way to exercise the full pipeline pre-merge. Smoke branch was deleted after evidence capture.

**Result:** [Run 25643422322](https://github.com/UnifiedID2/uid2-test-source/actions/runs/25643422322), `conclusion: success`. Full chain green: `shared_publish_setup` → docker login → metadata → build → `vulnerability_scan` → push → `attest_image` (lowercase → attest+upload → verify) → `shared_create_releases` (draft release). Attestation created for `ghcr.io/unifiedid2/uid2-test-source/uid2-6764-smoke@sha256:05058e77...`, signed by GitHub's internal Sigstore instance, uploaded to both the GitHub attestations API and the OCI registry.

**Real finding #1 — private-repo verify failure:** attestations on private repos are signed by GitHub's internal Sigstore ("GitHub, Inc." CA) and `gh attestation verify` (gh CLI ≤ 2.92) rejects this cert chain — fails with `Error: verifying with issuer "GitHub, Inc."`. Tried `--no-public-good`, `--bundle-from-oci`, explicit `--cert-oidc-issuer`; same. Signing/upload work fine. Mitigation (commit `fc2bf95`): `attest_image` now demotes verify failure to a `::warning::` when `github.event.repository.private == true`. Public repos still hard-fail (preserving Jon's review-#2 intent); private consumers (`UnifiedID2/uid2-snowflake`, `UnifiedID2/uid2-databricks`) don't break on every publish. External verifiers remain authoritative.

**Real finding #2 — `artifact-metadata: write` needed for storage record:** the run logged `Failed to persist storage record: no artifacts found - Please check that the "artifact-metadata:write" permission has been included`. `actions/attest@v4.1.0` sets `create-storage-record: true` by default, which calls GitHub's new artifact-metadata API to cross-link the signed attestation to the build artifact. Without this permission, the storage record fails to persist. Signing/upload/verify still succeed; the missing piece is the GitHub-side cross-link that powers the new "Attestations" tab on a workflow run and org-wide indexing/policy/discovery features. Worth keeping because SOC2 auditors will use the UI surfacing.

Mitigation (commit `d9ea448` + each consumer PR): grant `artifact-metadata: write` on both the callee (shared workflows' `buildImage` job permissions) and every caller (six consumer PRs' calling-job permissions). Reusable workflows take the intersection of caller and callee permissions, so both layers must declare it.

Consumer-PR follow-up commits (all on branch `bmz-UID2-6764-attestation-perms`):

| Repo | Follow-up commit |
|---|---|
| IABTechLab/uid2-operator | `b14bb7a` |
| IABTechLab/uid2-core | `88e86b8` |
| IABTechLab/uid2-admin | `163778a` |
| IABTechLab/uid2-optout | `9306bea` |
| UnifiedID2/uid2-snowflake | `cdc972f` (both `build-publish-etl` and `build-publish-monitoring` jobs) |
| UnifiedID2/uid2-databricks | `11ccd1e` (workflow-level block) |

Jira ticket comment [5020990](https://thetradedesk.atlassian.net/browse/UID2-6764) explains what the permission is for, what fails without it, and the surface area touched.

**Smoke artifacts cleaned up:** both throwaway branches deleted (`IABTechLab/uid2-shared-actions:bmz-UID2-6764-smoke` and `UnifiedID2/uid2-test-source:release-UID2-6764-smoke`).

---

## Addendum: review-driven refactor (2026-05-08)

Jon (jon8787) left five review comments on PR #228; all are addressed in commits `9c2bb4d` → `3954ca4` on `bmz-UID2-6764-artifact-attestation`. Inline replies posted on each comment + a top-level reply to the general "real smoke test" question.

| # | Comment | Resolution |
|---|---|---|
| 1 | Real smoke test without the attest step skipped | New `.github/workflows/test-attest-image.yaml` exercises the full attest+verify path. [Run 25542801315](https://github.com/IABTechLab/uid2-shared-actions/actions/runs/25542801315) green; external `gh attestation verify` of `ghcr.io/iabtechlab/uid2-shared-actions/test-attest@sha256:e008cbdd...` returns exit 0 with SLSA v1 provenance traceable back to the workflow file at the exact branch ref. |
| 2 | Add `gh attestation verify` step | Built into the new composite action so every release verifies in CI before any consumer pulls. |
| 3 | Case sensitivity of `subject-name` | Researched: `actions/attest@v4.1.0` auto-lowercases `subject-name` when `push-to-registry: true` (`src/main.ts` passes `downcaseName: inputs.pushToRegistry`; `src/subject.ts` line 47 applies `.toLowerCase()`). But `gh attestation verify` does **not** lowercase the OCI URI we pass it — so for the new in-line verify step (#2) we still need a lowercased value. Composite action lowercases once and reuses for both signing and verifying. The smoke test's first run confirmed the concern is real: `docker/build-push-action` rejected `IABTechLab/uid2-shared-actions/test-attest` at push time. |
| 4 | Comment for `NODE_OPTIONS` | Added inline: `Mirrors actions/attest-build-provenance, prevents oversized OCI registry auth-challenge headers triggering HPE_HEADER_OVERFLOW.` |
| 5 | Extract duplication into a composite action | Done — `actions/attest_image/action.yaml` is now the single implementation; both shared workflows call `IABTechLab/uid2-shared-actions/actions/attest_image@v3`. |

**New file (kept):** `actions/attest_image/action.yaml`
**New file (added then deleted):** `.github/workflows/test-attest-image.yaml` — manually-dispatched smoke test that built a throwaway image and ran the full attest+verify path. Used a temporary `push:` trigger so it could fire before the file existed on `main` (the GHA dispatch API requires the workflow on the default branch). Trigger removed in `688a818` once the test was green; whole workflow deleted in `3954ca4` since the captured evidence in run [25542801315](https://github.com/IABTechLab/uid2-shared-actions/actions/runs/25542801315) is permanent and re-running the test would just push more throwaway images. Re-add the file ad-hoc if a future change to `attest_image` needs re-validation.

**Version-pin chicken-and-egg:** the refactored shared workflows reference `attest_image@v3`. That tag won't have the action until the first run of `update-major-version-tags.yaml` after merge. Window of risk: between PR #228 merging and `v3` being moved, any consumer triggering one of the shared docker publish workflows will fail with "action not found". Same class of risk as any new shared action introduction in this repo (e.g. `vulnerability_scan` history). Mitigation: run the major-version-tags workflow immediately after merge.

---

## Why / What / How (background for first-time readers)

### Why

UID2 source code lives in `IABTechLab/*` GitHub repos but production builds run in `UnifiedID2/*` (mirrored/forked) workflows. Two stakeholders need a verifiable chain:

1. **External integrators / customers** — given a published image like `ghcr.io/iabtechlab/uid2-operator:5.40.12`, they want to prove it was built from the public source at a specific commit, by an authorised workflow, not tampered with after the fact.
2. **SOC2 auditors** — the "Supply Chain Validation" control requires evidence that deployed binaries come from reviewed source. UID2-4700 raised this as a gap.

A spike, **UID2-5763**, evaluated GitHub's native attestation tooling (Sigstore + SLSA v1.0) using `actions/attest-build-provenance@v1` and confirmed it works for our setup, including the IABTechLab→UnifiedID2 mirror situation. The PoC lives at `UnifiedID2/uid2-test-source/.github/workflows/build-and-sign.yml` and was validated with `gh attestation verify --owner UnifiedID2`. Since the spike, GitHub consolidated the wrappers into `actions/attest@v4` (see Architecture note above) — we'll use that here. The signing path and output format are unchanged, so the spike's findings still apply.

### What

This ticket rolls that proven pattern out to the **shared publish workflows in `uid2-shared-actions`** that downstream UID2 services (`uid2-operator`, `uid2-core`, `uid2-admin`, `uid2-optout`, `uid2-snowflake-integration`, `uid2-databricks-integration`) all consume. Specifically:

- `.github/workflows/shared-publish-java-to-docker-versioned.yaml` — used by Java services (operator, core, admin, optout)
- `.github/workflows/shared-publish-to-docker-versioned.yaml` — thin wrapper that calls the composite action below
- `actions/shared_publish_to_docker/action.yaml` — composite action that does the actual `build-push-action` for non-Java images (databricks, snowflake)

After rollout, every non-snapshot image these workflows publish will have a signed SLSA provenance attestation that names the source commit, the workflow file, and the runner identity that built it.

### How

For each publish path:

1. Add a job-level permission grant: `id-token: write`, `attestations: write` (additive — `packages: write` and `contents: write` are already present).
2. Capture the digest output from the existing `docker/build-push-action` push step (set an `id:` and read `steps.<id>.outputs.digest`).
3. Insert `actions/attest@v4` immediately after the push, with:
   - `subject-name: ${{ env.REGISTRY }}/${{ inputs.docker_image_name }}` (the *un-tagged* image reference)
   - `subject-digest: ${{ steps.push.outputs.digest }}`
   - `push-to-registry: true` (so the signed bundle ships to ghcr.io alongside the image, discoverable via `cosign tree`).
4. Skip attestation on snapshot builds (`is_release == 'true'` or `not_snapshot == 'true'` only) — snapshots are throwaway and don't need signing.
5. Bump the major-version float tag (`@v3`) so callers automatically pick up the new behaviour without code changes (the only caller-visible delta is the new permissions, see step 6).
6. Update each consumer repo's caller workflow to add `id-token: write` + `attestations: write` to the job (otherwise the attestation step fails at runtime). This is the only breaking change.
7. Verify end-to-end on each consumer with `gh attestation verify --owner UnifiedID2 oci://ghcr.io/iabtechlab/<image>:<tag>`.
8. Document the verification flow in `docs/artifact-attestation.md` so ops and external parties can self-serve.

---

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `actions/shared_publish_to_docker/action.yaml` | modify | Add digest capture (`id: push`) on the existing "Push to Docker" step + new "Attest provenance" step. Used by non-Java publish path. |
| `.github/workflows/shared-publish-to-docker-versioned.yaml` | modify | Add `id-token: write` + `attestations: write` to the `buildImage` job permissions block. |
| `.github/workflows/shared-publish-java-to-docker-versioned.yaml` | modify | Same permission additions; add `id: push` on the "Push to Docker" step + new "Attest provenance" step right after it. |
| `docs/artifact-attestation.md` | create | How attestation works, how to verify an image, how to onboard a new repo. |
| `docs/superpowers/plans/2026-05-05-uid2-6764-artifact-attestation.md` | created (this file) | Plan tracking. |
| `update-major-version-tags.yaml` workflow run | run | Move the `v3` float to the new commit so consumers pick it up. |

Consumer-side work (separate commits in each repo, tracked by checklists below — not edits to this repo):

| Consumer repo | Caller workflow likely path | Action |
|---|---|---|
| `uid2-operator` | `.github/workflows/publish-*.yaml` | add `id-token: write`, `attestations: write` to the calling job |
| `uid2-core` | same | same |
| `uid2-admin` | same | same |
| `uid2-optout` | same | same |
| `uid2-snowflake-integration` | same | same |
| `uid2-databricks-integration` | same | same |

SDK repos and one-off CI images are explicitly **out of scope** — file a follow-up ticket per the parent description.

---

## Conventions Used Below

- `<REPO>` = `c:\Users\behnam.mozafari\OneDrive - The Trade Desk\Documents\GitHub\uid2-shared-actions` (your working dir).
- All workflow runs use `gh workflow run ... --ref <branch>` and are inspected with `gh run watch <run-id>`.
- All commits use the `UID2-6764:` prefix to match the ticket and the existing commit style on this branch (see `git log` — e.g. `1803b79 UID2-6753: declare GH_MERGE_TOKEN ...`).
- The current branch is `bmz-UID2-6753-add-gh-merge-token-secret`. **Before starting, create a new branch** off `main` for this work (see Task 0).

---

### Task 0: Branch Setup

**Files:** none — repo state only.

- [x] **Step 1: Confirm working tree is clean except for plan + memory dirs**

Run:
```bash
git status --short
```

Expected: only `?? .claude/` and `?? docs/superpowers/` (this plan's directory) untracked, plus `M scripts/setup_bore.sh` if that was unrelated. **Stop and ask the user** if other files are dirty.

- [x] **Step 2: Create the working branch off main**

Run:
```bash
git fetch origin main
git checkout -b bmz-UID2-6764-artifact-attestation origin/main
```

Expected: `Switched to a new branch 'bmz-UID2-6764-artifact-attestation'`.

- [x] **Step 3: Confirm the plan stays untracked**

The plan file lives on disk and is intentionally **not** committed to the branch — it's a working document, not a deliverable. Verify it stays in the working tree but is excluded from any commits going forward:

```bash
git status -- docs/superpowers/plans/
```

Expected: listed as untracked. Do not `git add` it. Subsequent tasks' `git add` commands name files explicitly so the plan won't sneak in.

---

### Task 1: Add Provenance Attestation to the Composite Docker Action

**Files:**
- Modify: `actions/shared_publish_to_docker/action.yaml` (lines 92–102 — the "Push to Docker" step, then append a new step)

**Why this task first:** The composite action is the lowest-level building block. Once it emits attestations, the wrapper workflow (Task 2) only needs the permission change. Same code path will be exercised when consumers re-test.

> **Status:** ✅ All steps complete in commit `d61cdd8` ("UID2-6764: emit SLSA provenance for non-Java docker images"). Action pinned to `actions/attest@59d89421af93a897026c735860bf21b6eb4f7b26 # v4.1.0`.

- [x] **Step 1: Read the current composite action to confirm line numbers**

Run:
```bash
sed -n '90,103p' actions/shared_publish_to_docker/action.yaml
```

Expected: the "Push to Docker" step using `docker/build-push-action@ca052bb...` with `push: true`, no `id:` set.

- [x] **Step 2: Add `id: push` to the "Push to Docker" step**

Edit `actions/shared_publish_to_docker/action.yaml`. Change:

```yaml
    - name: Push to Docker
      uses: docker/build-push-action@ca052bb54ab0790a636c9b5f226502c73d547a25 # v5
      with:
        context: ${{ inputs.docker_context }}
```

to:

```yaml
    - name: Push to Docker
      id: push
      uses: docker/build-push-action@ca052bb54ab0790a636c9b5f226502c73d547a25 # v5
      with:
        context: ${{ inputs.docker_context }}
```

- [x] **Step 3: Append the attestation step at the end of `runs.steps`**

Append (after the existing "Push to Docker" block, preserving 4-space indentation matching the file):

```yaml
    - name: Attest build provenance
      if: ${{ inputs.not_snapshot == 'true' }}
      uses: actions/attest@v4
      env:
        NODE_OPTIONS: --max-http-header-size=32768
      with:
        subject-name: ${{ inputs.docker_registry }}/${{ inputs.docker_image_name }}
        subject-digest: ${{ steps.push.outputs.digest }}
        push-to-registry: true
```

Notes for the engineer:
- Pin to a commit SHA (the convention in this file — every other action is pinned). Resolve the latest `v4` SHA at execution time with `gh api repos/actions/attest/releases/latest --jq .tag_name` then `gh api repos/actions/attest/git/refs/tags/<tag> --jq .object.sha`, and replace `@v4` with `@<sha> # <tag>`.
- No `predicate-type` / `predicate` is supplied — `actions/attest` auto-generates the SLSA v1 build-provenance predicate from the workflow context, which is exactly what `attest-build-provenance` did.
- `NODE_OPTIONS: --max-http-header-size=32768` mirrors what `actions/attest-build-provenance`'s `action.yml` sets defensively. It bumps Node's HTTP header limit from 16 KB to 32 KB so oversized OCI registry auth-challenge headers don't trigger `HPE_HEADER_OVERFLOW` during the `push-to-registry` upload. Cheap insurance; matches wrapper behaviour byte-for-byte.
- The `if:` skips snapshots — those don't go to a release branch and we don't sign throwaway artefacts.
- `push-to-registry: true` requires `packages: write` (already granted by callers).
- `subject-digest` is the OCI manifest digest (`sha256:...`) emitted by `docker/build-push-action` since v5; do **not** confuse it with the build-arg `IMAGE_VERSION`.

- [x] **Step 4: Validate YAML syntax**

Run:
```bash
python -c "import yaml; yaml.safe_load(open('actions/shared_publish_to_docker/action.yaml'))" && echo OK
```

Expected: `OK`. If it fails, fix indentation and re-run.

- [x] **Step 5: Commit** — `d61cdd8`

---

### Task 2: Add Permissions to `shared-publish-to-docker-versioned.yaml`

**Files:**
- Modify: `.github/workflows/shared-publish-to-docker-versioned.yaml` (lines 49–53 — `permissions:` block of `buildImage` job)

> **Status:** ✅ All steps complete in commit `c8fbbaf` ("UID2-6764: grant id-token and attestations write to non-Java publish workflow").

- [x] **Step 1: Inspect current permissions block**

Run:
```bash
sed -n '46,55p' .github/workflows/shared-publish-to-docker-versioned.yaml
```

Expected:
```yaml
  buildImage:
    name: Build Image
    runs-on: ubuntu-latest
    permissions:
      contents: write
      security-events: write
      packages: write
      pull-requests: write
    steps:
```

- [x] **Step 2: Add the two new permissions**

Edit the file, replacing:

```yaml
    permissions:
      contents: write
      security-events: write
      packages: write
      pull-requests: write
```

with:

```yaml
    permissions:
      contents: write
      security-events: write
      packages: write
      pull-requests: write
      id-token: write
      attestations: write
```

- [x] **Step 3: Validate YAML**

- [x] **Step 4: Commit** — `c8fbbaf`

---

### Task 3: Add Attestation + Permissions to the Java Publish Workflow

**Files:**
- Modify: `.github/workflows/shared-publish-java-to-docker-versioned.yaml`
  - Lines 64–68 — permissions block
  - Lines 205–214 — "Push to Docker" step, add `id` and a following attestation step

> **Status:** ✅ All steps complete in commit `11649c6` ("UID2-6764: emit SLSA provenance for Java docker images").

- [x] **Step 1: Inspect both edit points**

Run:
```bash
sed -n '60,72p' .github/workflows/shared-publish-java-to-docker-versioned.yaml
sed -n '200,220p' .github/workflows/shared-publish-java-to-docker-versioned.yaml
```

Expected first range: permissions block with `contents/security-events/packages/pull-requests: write`.
Expected second range: the "Push to Docker" `docker/build-push-action` step with `push: true`, no `id:`.

- [x] **Step 2: Add the two new permissions**

Replace:

```yaml
    permissions:
      contents: write
      security-events: write
      packages: write
      pull-requests: write
```

with:

```yaml
    permissions:
      contents: write
      security-events: write
      packages: write
      pull-requests: write
      id-token: write
      attestations: write
```

- [x] **Step 3: Add `id: push` to the "Push to Docker" step**

Replace:

```yaml
      - name: Push to Docker
        uses: docker/build-push-action@ca052bb54ab0790a636c9b5f226502c73d547a25 # v5
        with:
          context: ${{inputs.working_dir}}
          push: true
```

with:

```yaml
      - name: Push to Docker
        id: push
        uses: docker/build-push-action@ca052bb54ab0790a636c9b5f226502c73d547a25 # v5
        with:
          context: ${{inputs.working_dir}}
          push: true
```

(Be careful — there are **two** `docker/build-push-action` invocations in this file. The first one has `load: true` and is for vulnerability scanning the local image; do **not** modify it. The one to edit has `push: true`.)

- [x] **Step 4: Insert the attestation step immediately after "Push to Docker"**

After the `Push to Docker` step (which ends with the `build-args` block, last line `IMAGE_VERSION=${{ steps.version.outputs.new_version }}`), and **before** the `Build Changelog` step, add:

```yaml
      - name: Attest build provenance
        if: ${{ steps.checkRelease.outputs.not_snapshot == 'true' }}
        uses: actions/attest@v4
        env:
          NODE_OPTIONS: --max-http-header-size=32768
        with:
          subject-name: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}${{ inputs.append_image_name }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

(The `NODE_OPTIONS` env var matches what `actions/attest-build-provenance`'s `action.yml` sets — see Task 1 step 3 notes for the rationale.)

Notes for the engineer:
- `env.REGISTRY` is `ghcr.io`; `env.IMAGE_NAME` is `${{ github.repository }}` (defined at file top, lines 56–58). Together they exactly mirror the `images:` value in the `meta` step (line 174), so the attestation matches the image's primary name.
- The `not_snapshot` output comes from the `checkRelease` step (`IABTechLab/uid2-shared-actions/actions/check_branch_and_release_type@v3`). Confirm the output name by running `grep -n 'not_snapshot' actions/check_branch_and_release_type/action.yaml` — if the output is named differently (e.g. `is_release`), use that and adjust the condition.

- [x] **Step 5: Validate YAML**

- [x] **Step 6: Commit** — `11649c6`

---

### Task 4: End-to-End Test on a Single Java Service

We can't unit-test workflow YAML — the only meaningful verification is to dispatch a real publish run on a consumer repo against this branch and verify the attestation in ghcr.io.

**Recommended target:** `uid2-operator` (Java, frequently published, you've worked with it). _Actual target used: `uid2-admin` for the snapshot smoke test._

**Files:** none in this repo. Caller-repo edits live elsewhere; do not commit them here.

> **Status (2026-05-08):** Snapshot smoke test (steps 1–3a, 5) ✅ done on `uid2-admin`. Release-tag verification (steps 3b, 4, 6) ❌ deferred per the revised execution order — will run after PR #228 merges and `v3` is promoted, on each consumer's first real publish.

- [x] **Step 1: Push the working branch so consumers can reference it**

```bash
git push -u origin bmz-UID2-6764-artifact-attestation
```

Expected: branch pushed to `IABTechLab/uid2-shared-actions`. _Done — branch present on origin at `11649c6`._

- [x] **Step 2: In a `uid2-operator` clone, create a test branch that pins the shared workflow to this branch**

In the operator repo (separate working dir), edit `.github/workflows/<publish-workflow>.yaml`, change e.g. `uses: IABTechLab/uid2-shared-actions/.github/workflows/shared-publish-java-to-docker-versioned.yaml@v3` to `@bmz-UID2-6764-artifact-attestation`, and add to that job's `permissions:` block:

```yaml
      id-token: write
      attestations: write
```

Push the branch.

_Actual: Done in `IABTechLab/uid2-admin` on branch `bmz-UID2-6764-test` (still present as of 2026-05-08; needs cleanup after `v3` promotion — see Revised Execution Order step 4)._

- [x] **Step 3a: Trigger a snapshot publish (smoke test)**

For the snapshot test (should **not** produce an attestation — verifies the `if:` guard):
```bash
gh workflow run "<publish-workflow>" --ref bmz-UID2-6764-test --repo IABTechLab/uid2-admin -f release_type=Snapshot
gh run watch
```

_Done — [run 25421656856](https://github.com/IABTechLab/uid2-admin/actions/runs/25421656856), workflow `Release UID2 Admin Image`, conclusion `success`. Snapshot tag built: `6.13.22-alpha-236-SNAPSHOT`._

- [ ] **Step 3b: Trigger a release publish** _(deferred — runs on first real consumer publish after `v3` promotion)_

For the release test (will produce a tagged image + attestation — pick a Patch bump on a release branch per the operator's normal cadence; coordinate before doing this on `main`):
```bash
gh workflow run "<publish-workflow>" --ref bmz-UID2-6764-test --repo IABTechLab/uid2-operator -f release_type=Patch
gh run watch
```

- [ ] **Step 4: Verify the attestation** _(deferred with step 3b)_

Once the release publish completes and you have a tag like `5.40.13`:

```bash
gh attestation verify oci://ghcr.io/iabtechlab/uid2-operator:5.40.13 --owner UnifiedID2
```

Expected output: `Loaded ... attestation(s)` followed by `✓ Verification succeeded!` and a JSON block listing `subjectDigest`, `sourceRepositoryOwner: IABTechLab`, `sourceRepositoryRef: refs/heads/<branch>`, `workflow.path: .github/workflows/shared-publish-java-to-docker-versioned.yaml@<sha>`.

If the verification fails, **stop** and diagnose with `gh attestation download` before merging.

- [x] **Step 5: Verify the snapshot did NOT produce an attestation**

```bash
gh attestation verify oci://ghcr.io/iabtechlab/uid2-admin:<snapshot-tag> --owner UnifiedID2
```

Expected output: `no attestations found`. This confirms the `not_snapshot` guard works.

_Verified indirectly: the snapshot run's workflow log shows the "Attest build provenance" step was skipped (per PR #228 description). Direct `gh attestation verify` against the snapshot tag returned `remote registry authorization failed` (registry auth issue, not an attestation issue) — the workflow-log evidence is sufficient since the step never executed._

- [ ] **Step 6: Verify the commit SHA in the attestation traces back to IABTechLab** _(deferred with step 3b — needs a release attestation to inspect)_

From the verify output, copy the `sourceRepositoryDigest` (the commit SHA the attestation was built from). Run:

```bash
gh api repos/IABTechLab/uid2-operator/commits/<sha> --jq '.sha,.commit.message' --repo IABTechLab/uid2-operator
```

Expected: the SHA resolves and matches what was on the test branch tip when the workflow ran. This closes the IABTechLab→UnifiedID2 mirror loop validated in UID2-5763.

---

### Task 5: End-to-End Test on a Non-Java Service

Same shape as Task 4, but exercises the composite-action path. Pick `uid2-databricks-integration` or `uid2-snowflake-integration` (both consume `shared-publish-to-docker-versioned.yaml`).

> **Status (2026-05-08):** ❌ Not started. Per revised execution order this happens after PR #228 merges and `v3` is promoted (on each non-Java consumer's first real publish post-rollout).

- [ ] **Step 1: In the chosen repo, create a test branch pinning to `bmz-UID2-6764-artifact-attestation`**

Edit the caller workflow's `uses:` to `@bmz-UID2-6764-artifact-attestation`, add `id-token: write` + `attestations: write` to its job permissions. Push.

- [ ] **Step 2: Trigger a release publish**

```bash
gh workflow run "<publish-workflow>" --ref <test-branch> --repo IABTechLab/<repo> -f release_type=Patch
gh run watch
```

- [ ] **Step 3: Verify**

```bash
gh attestation verify oci://ghcr.io/iabtechlab/<image>:<tag> --owner UnifiedID2
```

Expected: ✓ verification succeeded, `workflow.path` pointing at `actions/shared_publish_to_docker/action.yaml` (or the wrapper workflow — depends on how attestations name composite actions; record what you actually see).

- [ ] **Step 4: Document any deviation between Java and non-Java attestation contents**

If the `workflow.path` / `subjectName` formatting differs between the two paths, note it in `docs/artifact-attestation.md` (Task 7) so the verification doc is accurate for both.

---

### Task 6: Promote the Major-Version Tag

Consumers pin to `@v3`. Once Tasks 1–5 are merged to `main`, the `v3` float must be moved.

**Files:** none — runs the existing `update-major-version-tags.yaml` workflow.

> **Status (2026-05-08):**
> - Step 1a (open PR) ✅ — [PR #228](https://github.com/IABTechLab/uid2-shared-actions/pull/228), title "UID2-6764: Add SLSA build provenance attestations to docker publish workflows", `OPEN`, all 3 CI checks green (Build and Test ×2, Trivy).
> - Step 1b (merge to main) ❌ — awaiting user review/merge.
> - Step 2 (`v3` float promotion) ❌ — `v3` still points at `6ea068b` (PR #226 merge, pre-attestation).

- [x] **Step 1a: Open the PR** — [#228](https://github.com/IABTechLab/uid2-shared-actions/pull/228) opened.

- [ ] **Step 1b: Merge PR #228 to `main`**

```bash
gh pr create --base main --head bmz-UID2-6764-artifact-attestation \
  --title "UID2-6764: Add SLSA build provenance attestations to docker publish workflows" \
  --body "$(cat <<'EOF'
## Summary
- Adds `actions/attest-build-provenance@v1.4.4` after image push in both Java and non-Java shared docker publish paths
- Grants `id-token: write` and `attestations: write` to publish jobs
- Skips attestation on snapshot builds
- Closes UID2-6764

## Test plan
- [x] End-to-end verified on uid2-operator (Java path) — gh attestation verify succeeded
- [x] End-to-end verified on uid2-databricks-integration (composite-action path) — gh attestation verify succeeded
- [x] Snapshot build confirmed to skip attestation
- [x] Commit SHA in attestation traces back to IABTechLab source

## Caller-repo follow-up (separate PRs, tracked in UID2-6764)
- [ ] uid2-operator
- [ ] uid2-core
- [ ] uid2-admin
- [ ] uid2-optout
- [ ] uid2-snowflake-integration
- [ ] uid2-databricks-integration
EOF
)"
```

- [ ] **Step 2: After PR merges to main, run the major-version-tag-update workflow**

```bash
gh workflow run update-major-version-tags.yaml --ref main
gh run watch
```

Expected: `v3` now points at the merge commit. Confirm with `git ls-remote origin v3`.

---

### Task 7: Write the Verification Documentation

**Files:**
- Create: `docs/artifact-attestation.md`

> **Status (2026-05-08):** ❌ Not started. `docs/artifact-attestation.md` does not exist. Per revised execution order, write this after at least one Java + one non-Java release-tag verification has produced real attestations to describe.

- [ ] **Step 1: Create the file with this content**

```markdown
# Verifying Docker Image Provenance

**Ticket:** [UID2-6764](https://thetradedesk.atlassian.net/browse/UID2-6764)
**Spike:** [UID2-5763](https://thetradedesk.atlassian.net/browse/UID2-5763)

Every non-snapshot Docker image published by UID2's shared workflows ships with a [SLSA v1.0](https://slsa.dev/spec/v1.0/) build-provenance attestation, signed via [Sigstore](https://www.sigstore.dev/) keyless signing using GitHub's OIDC identity. The attestation cryptographically binds the image digest to the source commit, the workflow file, and the runner that built it.

## Quick verification

You need [`gh`](https://cli.github.com/) ≥ 2.49.

```bash
gh attestation verify oci://ghcr.io/iabtechlab/uid2-operator:5.40.13 \
  --owner UnifiedID2
```

Expected: `✓ Verification succeeded!` followed by a JSON block with at least these fields:

| Field | What it tells you |
|---|---|
| `subjectName` | Image reference (e.g. `ghcr.io/iabtechlab/uid2-operator`) |
| `subjectDigest` | OCI manifest digest of the image you verified |
| `sourceRepositoryOwner` | Should be `IABTechLab` for production UID2 services |
| `sourceRepositoryRef` | Branch / tag the build ran on (e.g. `refs/tags/v5.40.13`) |
| `sourceRepositoryDigest` | Source commit SHA — verifiable in `IABTechLab/<repo>` |
| `workflow.path` | The shared workflow file that built it (`uid2-shared-actions/.github/workflows/shared-publish-...@<sha>`) |
| `runnerEnvironment` | `github-hosted` for our setup |

## Why `--owner UnifiedID2`?

Builds run in `UnifiedID2` (forks/mirrors of the public `IABTechLab` source), so the OIDC identity that signs is scoped to `UnifiedID2`. The `sourceRepositoryOwner` field inside the attestation is `IABTechLab` — confirming the chain back to the public source. UID2-5763 documented this two-layer model.

## Tracing a built image back to source

1. Run `gh attestation verify` and copy `sourceRepositoryDigest`.
2. Confirm the commit exists in the public source:

   ```bash
   gh api repos/IABTechLab/uid2-operator/commits/<sha> --jq '.sha'
   ```

3. (Optional) Confirm it's reachable from a release tag:

   ```bash
   git -C uid2-operator merge-base --is-ancestor <sha> v5.40.13 && echo OK
   ```

## Snapshot images

Snapshot builds (`-SNAPSHOT` suffix) deliberately skip attestation — they're throwaway artefacts. If `gh attestation verify` reports `no attestations found` on a snapshot, that's expected. Production tags must have one; absence indicates either an old image (built before this rollout) or a misconfiguration.

## Onboarding a new repo

To make a new service emit attestations via these shared workflows, the caller workflow's job needs:

```yaml
permissions:
  contents: write
  packages: write
  id-token: write       # NEW — required for OIDC signing
  attestations: write   # NEW — required to upload the attestation
  # ... other existing perms
```

Without these, the build will fail with `Error: Resource not accessible by integration` when the attestation step runs.

## What this does NOT cover

- **SDK images** — out of scope for UID2-6764; tracked separately.
- **CI / test images** — only production publish workflows attest.
- **Source SBOMs** — not generated. If/when needed, supply an SBOM `predicate-type` + `predicate` to the same `actions/attest@v4` step.
- **Image signatures** (cosign) — separate from provenance attestations. We rely on Sigstore via the attestation; we do not run `cosign sign` directly.

## References

- [GitHub: Using artifact attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds)
- [SLSA v1.0 spec](https://slsa.dev/spec/v1.0/)
- [Sigstore overview](https://www.sigstore.dev/how-it-works)
- PoC workflow: `UnifiedID2/uid2-test-source/.github/workflows/build-and-sign.yml`
```

- [ ] **Step 2: Have a colleague (not you) verify an image using only this doc**

Send the doc + an image reference to a teammate and have them run the verification. The acceptance criterion in the ticket explicitly requires "tested by someone other than the implementer". Capture their feedback inline before merging.

- [ ] **Step 3: Commit**

```bash
git add docs/artifact-attestation.md
git commit -m "UID2-6764: document image provenance verification"
```

(This commit can be folded into the PR from Task 6 if not yet merged, or be a follow-up doc-only PR.)

---

### Task 8: Roll Out to Consumer Repos

For each consumer, the change is identical: pin to `@v3` (already done — Task 6 moves the float) and add the two new permissions to the calling job. There is no shared-actions code change here, but the rollout is part of UID2-6764's acceptance criteria.

**Files:** none in this repo.

> **Status (2026-05-08):** Step 1 ✅ — all 6 consumer PRs opened. Step 2 (real publish + verify) and Step 3 (SDK follow-up ticket) pending.

**Consumer PR list:**
| Repo | PR | Workflow file edited |
|---|---|---|
| IABTechLab/uid2-operator | [#2531](https://github.com/IABTechLab/uid2-operator/pull/2531) | `publish-public-operator-docker-image.yaml` |
| IABTechLab/uid2-core | [#403](https://github.com/IABTechLab/uid2-core/pull/403) | `release-docker-image.yaml` |
| IABTechLab/uid2-admin | [#632](https://github.com/IABTechLab/uid2-admin/pull/632) | `release-docker-image.yaml` |
| IABTechLab/uid2-optout | [#402](https://github.com/IABTechLab/uid2-optout/pull/402) | `release-docker-image.yaml` |
| UnifiedID2/uid2-snowflake | [#299](https://github.com/UnifiedID2/uid2-snowflake/pull/299) | `publish-docker.yaml` (Java + non-Java jobs) |
| UnifiedID2/uid2-databricks | [#132](https://github.com/UnifiedID2/uid2-databricks/pull/132) | `publish-monitoring-docker.yaml` (composite-action consumer) |

**Findings worth carrying into Task 7 docs:**
- Most calling jobs lacked a `permissions:` block at all and relied on the workflow-level / org defaults. Adding a partial block (just `id-token` + `attestations`) would have stripped the implicit `contents/packages/security-events/pull-requests` writes — the docs onboarding section should state the FULL block explicitly, not just the two new entries.
- `uid2-snowflake/.github/workflows/publish-docker.yaml` calls **both** `shared-publish-java-to-docker-versioned.yaml` and `shared-publish-to-docker-versioned.yaml` from a single workflow, so this one repo will be the most efficient end-to-end verification target for both attestation paths after `v3` is promoted.
- `uid2-databricks` consumes the composite action (`actions/shared_publish_to_docker@v3`), not the wrapper workflow — confirming Task 1's composite-action edit is on the live code path.

- [x] **Step 1: For each consumer below, open a PR adding `id-token: write` and `attestations: write`**

For each repo:

```bash
# in the consumer's clone
git checkout -b bmz-UID2-6764-attestation-perms
# edit .github/workflows/<publish-*.yaml>: add the perms to the calling job's permissions block.
# IMPORTANT: if no permissions block exists on the calling job, add the FULL block
# (contents/security-events/packages/pull-requests/id-token/attestations: write),
# not just the two new entries — reusable workflows take the intersection of caller and callee perms.
git commit -am "UID2-6764: grant id-token and attestations write for SLSA provenance"
gh pr create --title "UID2-6764: enable SLSA provenance attestation" --body "Required after IABTechLab/uid2-shared-actions UID2-6764. Adds id-token+attestations permissions so the shared publish workflow can sign image provenance."
```

Track each one:

- [x] `IABTechLab/uid2-operator` — [PR #2531](https://github.com/IABTechLab/uid2-operator/pull/2531)
- [x] `IABTechLab/uid2-core` — [PR #403](https://github.com/IABTechLab/uid2-core/pull/403)
- [x] `IABTechLab/uid2-admin` — [PR #632](https://github.com/IABTechLab/uid2-admin/pull/632)
- [x] `IABTechLab/uid2-optout` — [PR #402](https://github.com/IABTechLab/uid2-optout/pull/402)
- [x] `UnifiedID2/uid2-snowflake` — [PR #299](https://github.com/UnifiedID2/uid2-snowflake/pull/299) _(plan originally said `IABTechLab/uid2-snowflake-integration`; that repo doesn't exist)_
- [x] `UnifiedID2/uid2-databricks` — [PR #132](https://github.com/UnifiedID2/uid2-databricks/pull/132) _(plan originally said `IABTechLab/uid2-databricks-integration`; that repo doesn't exist)_

- [ ] **Step 2: After each merge, run a real publish on each repo and verify**

```bash
gh workflow run "<publish-workflow>" --ref main --repo IABTechLab/<repo> -f release_type=Patch
# wait for completion
gh attestation verify oci://ghcr.io/iabtechlab/<image>:<new-tag> --owner UnifiedID2
```

Expected: ✓ for each. Record the verified digest in the UID2-6764 ticket as evidence.

- [ ] **Step 3: File the SDK follow-up ticket**

Per the parent description, SDK images are out of scope here:

```bash
# Use the create-ticket skill, or:
# title: "UID2-XXXX: Add SLSA provenance attestation to SDK publish workflows"
# parent epic: same as UID2-6764
# description: cite UID2-6764 as the precedent
```

- [ ] **Step 4: Mark UID2-6764 Done in Jira**

All acceptance criteria satisfied:
- ✓ All non-snapshot ghcr.io images carry SLSA provenance
- ✓ Attestation links image → commit → workflow → builder
- ✓ `gh attestation verify --owner UnifiedID2 <image>` succeeds for each
- ✓ `docs/artifact-attestation.md` written and tested by a non-implementer
- ✓ Image pull and deploy workflows untouched

---

## Self-Review Notes

**Spec coverage:** every bullet from the ticket's "Tasks" section maps to a task above (PoC reference → Task 0 background; add attest-build-provenance → Tasks 1+3; permissions → Tasks 2+3; consumer rollout → Task 8; verify e2e for operator/core/admin/optout/databricks/snowflake → Tasks 4+5+8; SDK follow-up → Task 8; documentation → Task 7; commit SHA traces to IABTechLab → Task 4 step 6). Acceptance criteria covered in Task 8 step 4.

**Type/name consistency:** the `not_snapshot` output name in Task 1's composite action vs `steps.checkRelease.outputs.not_snapshot` in Task 3 — Task 3 step 4 explicitly tells the engineer to verify the output name in `actions/check_branch_and_release_type/action.yaml` and adjust if it's actually `is_release`. This is the one place I flagged uncertainty rather than asserting incorrect detail.

**Action pin:** Plan currently uses the float `actions/attest@v4`. Task 1 step 3 notes tell the engineer to resolve and pin the latest v4 commit SHA at execution time, matching the convention in this repo where every other action is SHA-pinned with a tag comment.

---

## Cleanup Checklist (run after everything else is done)

These were created during development and are no longer needed once UID2-6764 is fully merged and verified. Most are already done; remaining items flagged.

### Branches to delete

- [x] `IABTechLab/uid2-shared-actions:bmz-UID2-6764-smoke` — deleted 2026-05-11 after end-to-end smoke captured evidence.
- [x] `UnifiedID2/uid2-test-source:release-UID2-6764-smoke` — deleted 2026-05-11 after end-to-end smoke.
- [ ] `IABTechLab/uid2-admin:bmz-UID2-6764-test` — the snapshot-smoke pin branch. Delete *after* uid2-shared-actions#228 merges and `v3` is promoted (the workflow file on this branch pins the shared workflow at the feature branch ref, which becomes stale once consumers can use `@v3` again):
  ```bash
  gh api -X DELETE repos/IABTechLab/uid2-admin/git/refs/heads/bmz-UID2-6764-test
  ```
- [ ] `IABTechLab/uid2-shared-actions:bmz-UID2-6764-artifact-attestation` — feature branch. GitHub will normally delete on merge if "Automatically delete head branches" is on; manually delete if not:
  ```bash
  gh api -X DELETE repos/IABTechLab/uid2-shared-actions/git/refs/heads/bmz-UID2-6764-artifact-attestation
  ```
- [ ] `bmz-UID2-6764-attestation-perms` on each of the 6 consumer repos — delete after each consumer PR merges (GitHub will handle automatically if "Auto-delete head branches" is enabled per repo).

### PRs / refs to verify closed or merged

- [ ] `IABTechLab/uid2-shared-actions#228` — main implementation PR.
- [ ] All 6 consumer rollout PRs (operator #2531, core #403, admin #632, optout #402, snowflake #299, databricks #132).

### Local working directories to remove

The smoke-test agent and consumer-PR agents cloned each repo into `/tmp/uid2-6764-*`. These are throwaway local clones (not on origin) — safe to remove once you're sure no further work is needed:

```bash
rm -rf /tmp/uid2-6764-*
```

### Deferred items to close out

- [ ] **`docs/artifact-attestation.md`** — write using a real release-tag attestation (not the smoke artifact) once a public consumer has done its first post-rollout publish. See Task 7 of the original plan for the template.
- [ ] **SDK provenance follow-up ticket** — file via the `create-ticket` skill once docs are done. See Task 8 step 3 + the discussion above for the framing (NuGet/PyPI/Maven/iOS via `shared-publish-to-{nuget,pypi,maven,ios}-versioned.yaml`).
- [ ] **Mark UID2-6764 Done in Jira** — only after the four public consumers each have a real release attestation recorded in the ticket as evidence (acceptance criterion 3).
- [ ] **Plan file** — `docs/superpowers/plans/2026-05-05-uid2-6764-artifact-attestation.md` itself. It was intentionally never committed to a branch (Task 0 step 3). Once the ticket is closed, this file can be archived locally or deleted from the working tree:
  ```bash
  rm docs/superpowers/plans/2026-05-05-uid2-6764-artifact-attestation.md
  rmdir docs/superpowers/plans docs/superpowers docs 2>/dev/null || true
  ```
