# uid2-shared-actions

This repo contains shared actions and workflows that are consumed by the other uid2 workflows.

This simplifies the management and maintenance of the workflows.

## Release notes

All shared publish workflows generate release notes via the `actions/shared_create_releases` composite action, which wraps [`mikepenz/release-changelog-builder-action`](https://github.com/mikepenz/release-changelog-builder-action) (SHA-pinned). This is the canonical approach for this repo — chosen over GitHub-native auto-generated notes (`generate_release_notes: true`) because:

- The native format hardcodes `* TITLE by @AUTHOR in #NUMBER`. Authors are noise to the public consumers of these releases; mikepenz's `pr_template` lets us emit `- TITLE - ( PR: #NUMBER )` instead.
- The composite embeds a per-platform install snippet (`docker pull`, `pip install`, `dotnet add package`, Maven `<dependency>`) above the changelog.

`shared_create_releases` supports `publish_platform` values `Docker`, `Maven`, `PyPI`, `NuGet`, `iOS`. Internally it builds the changelog (mikepenz), deletes stale drafts, and creates the release (softprops); on the pre-release path it additionally resolves the previous published tag (gh) and verifies the `v<version>` tag exists before publishing. The `prerelease` input (default `'false'`) controls the release type:

- omitted / `prerelease: 'false'` (default) — creates a **draft** release (the original behaviour, still requires a manual "Publish" click). The Maven/PyPI/NuGet/iOS (registry/SDK) workflows keep this default for now.
- `prerelease: 'true'` — publishes a **pre-release** immediately (durable + fetchable by tag, without claiming GA). The shared docker workflows set this for deployed-service builds. `Latest` is never set automatically — it stays a deliberate manual promotion. The `v<version>` tag must already exist (pushed earlier by `commit_pr_and_merge`); the action verifies this and fails rather than letting softprops auto-create the tag at the wrong commit.

When `is_release` is `false` (Snapshot/pre-release build) the action is a no-op, so callers can invoke it unconditionally.

For pre-release (`prerelease: 'true'`) cuts the changelog's `fromTag` is resolved automatically to the most recent **published** release, so a run that tags but fails to publish doesn't drop a slice of notes — the next run's changelog self-heals back over the gap. Pass the optional `from_tag` input to override this (e.g. manual backfill, or non-sequential tag names); on a first-ever release, and for draft releases, it falls back to mikepenz's git-tag auto-detection.

When adding a new publish workflow, call `IABTechLab/uid2-shared-actions/actions/shared_create_releases@v3` rather than inlining mikepenz. Do not set `continue-on-error: true` on it — the workflow must fail if release-notes generation fails. Decision documented in [UID2-6762](https://thetradedesk.atlassian.net/browse/UID2-6762).

## Tips and tricks

If you're trying to do something that should be simple, but can't find something that quite supports what you're trying to do, the [GitHub Script action](https://github.com/actions/github-script) gives you an authenticated GitHub API client and you can just provide a JavaScript script. For an example, see the "Tag commit" step in the [Commit, PR, and Merge](actions\commit-pr-and-merge\action.yaml) shared action.

If you use this and the script gets complicated, consider trying to find a simpler approach, or putting the script somewhere it can be maintained/tested outside of the YAML file.