# uid2-shared-actions

This repo contains shared actions and workflows that are consumed by the other uid2 workflows.

This simplifies the management and maintenance of the workflows.

## Release notes

All shared publish workflows generate release notes via the `actions/shared_create_releases` composite action, which wraps [`mikepenz/release-changelog-builder-action`](https://github.com/mikepenz/release-changelog-builder-action) (SHA-pinned). This is the canonical approach for this repo — chosen over GitHub-native auto-generated notes (`generate_release_notes: true`) because:

- The native format hardcodes `* TITLE by @AUTHOR in #NUMBER`. Authors are noise to the public consumers of these releases; mikepenz's `pr_template` lets us emit `- TITLE - ( PR: #NUMBER )` instead.
- The composite embeds a per-platform install snippet (`docker pull`, `pip install`, `dotnet add package`, Maven `<dependency>`) above the changelog.

`shared_create_releases` supports `publish_platform` values `Docker`, `Maven`, `PyPI`, `NuGet`, `iOS`. It runs three steps internally: Build Changelog (mikepenz) → Delete Draft Releases → Create Release (softprops, draft). When `is_release` is `false` (Snapshot/pre-release) the action is a no-op, so callers can invoke it unconditionally.

When adding a new publish workflow, call `IABTechLab/uid2-shared-actions/actions/shared_create_releases@v3` rather than inlining mikepenz. Do not set `continue-on-error: true` on it — the workflow must fail if release-notes generation fails. Decision documented in [UID2-6762](https://thetradedesk.atlassian.net/browse/UID2-6762).

## Tips and tricks

If you're trying to do something that should be simple, but can't find something that quite supports what you're trying to do, the [GitHub Script action](https://github.com/actions/github-script) gives you an authenticated GitHub API client and you can just provide a JavaScript script. For an example, see the "Tag commit" step in the [Commit, PR, and Merge](actions\commit-pr-and-merge\action.yaml) shared action.

If you use this and the script gets complicated, consider trying to find a simpler approach, or putting the script somewhere it can be maintained/tested outside of the YAML file.