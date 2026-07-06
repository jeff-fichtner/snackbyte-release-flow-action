# Feature Specification: Marketplace publish + the Action's own release channel

**Feature Branch**: `003-marketplace-release` (not created yet)

**Created**: 2026-07-06

**Status**: STUB — deferred, not scheduled. Captured so the scope isn't lost; do not treat
the sections below as complete or ratified. Expand with `/speckit-specify` when actually picked up.

> **This is a placeholder.** These are the *delivery/distribution* mechanics that sit on top of the
> Action — not the release-flow logic itself, which is shipped. Realistically untouched for a
> long time.

## Why this exists (the remaining distribution gap)

The Action is built, tested, self-versioning, and consumable at a `@v1` alias. What remains is the
distribution polish that sits on top of a working Action:

1. **Automated moving `v1` alias.** A `v1` tag exists (cut by hand) so `@v1` resolves today, but
   nothing *re-points* it automatically on each release — moving `vMAJOR` forward on every new
   `vMAJOR.MINOR.PATCH` is manual. This feature owns automating that (and the `v1`→`v2` bump policy
   for a deliberate breaking change).
2. **A GitHub Marketplace listing** so the Action is discoverable and installable like any published
   Action (the "VS Code extension → Marketplace" half of the mental model in the root README).
3. **Inline-JSON manifest form** — the `manifest` input accepts a path; accepting inline JSON is a
   deferred convenience noted in 001's research.

## Context

The repo versions itself with its own Action (`.github/workflows/release.yml`, `build-id`),
producing point releases (`v0.1.0`, `v0.2.1`, …). The `v1` alias is maintained by hand until the
automation in item 1 lands.

## Candidate scope (to be refined when picked up)

- **Moving major-version alias**: on each new `vMAJOR.MINOR.PATCH` release, (re)point `vMAJOR`
  (e.g. `v1`) at it. Decide: force-push the alias tag vs. a release-please-style bot; who is allowed
  to move it; how a breaking change bumps `v1` → `v2`.
- **Marketplace publish**: add the `branding` (already present in `action.yml`), a proper release
  with release notes, and publish through the GitHub Marketplace flow (a human, one-time, gated step
  — likely can't be fully automated).
- **Release notes / changelog**: how release notes are generated for each tag.
- **SemVer discipline for the Action itself**: distinct from the build-id PATCH the Action *derives*
  for consumers — this is the Action's OWN version. Clarify the two version lines so they don't get
  conflated (the Action's semver vs. the monotonic build id it produces).
- **Consumer pinning guidance**: docs on `@v1` (moving) vs. `@vX.Y.Z` (pinned) vs. `@<sha>` (locked).

## Explicitly NOT in scope here

- Any change to the derivation algorithm or manifest schema (that is 001's settled contract).

## Open questions (for the eventual `/speckit-clarify`)

- Does the Action's own version follow the same `environments.json`-derived scheme, or a plain
  hand-cut SemVer? (It currently self-tags via its own flow → the former, but the moving `v1` alias
  is orthogonal and still needed.)
- Marketplace listing owner/namespace: stays under `jeff-fichtner`, or moves to a `snackbyte` org
  (the root README's `uses: snackbyte/…@v1` implies an org move — a separate decision with its own
  visibility/permissions implications).

## Next step when resumed

Run `/speckit-specify` against this stub to produce a real spec, then `/speckit-plan` etc. Nothing
in this file is binding.
