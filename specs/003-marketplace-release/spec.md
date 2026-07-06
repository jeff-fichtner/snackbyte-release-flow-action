# Feature Specification: Marketplace publish + the Action's own release channel

**Feature Branch**: `003-marketplace-release` (not created yet)

**Created**: 2026-07-06

**Status**: STUB — deferred, not scheduled. Captured so the scope isn't lost; do not treat
the sections below as complete or ratified. Expand with `/speckit-specify` when actually picked up.

> **This is a placeholder.** Feature 001 (the built Action) explicitly scoped these items OUT.
> They are the *delivery/distribution* mechanics that sit on top of the working Action, not the
> release-flow logic itself. Realistically untouched for a long time.

## Why this exists (the gap 001 left)

001 delivered a working, tested composite Action referenced by path (`uses: ./`) and by branch/SHA.
Two distribution capabilities were deliberately deferred:

1. **A stable, moving `v1` tag** so consumers can write `uses: jeff-fichtner/snackbyte-release-flow-action@v1`
   and receive non-breaking improvements without editing their workflows. The 001 README already
   *documents* `@v1`, but no `v1` tag exists — so that reference does not resolve yet.
2. **A GitHub Marketplace listing** so the Action is discoverable and installable like any published
   Action (the "VS Code extension → Marketplace" half of the mental model in the root README).

## Partial progress already landed (outside this feature)

- The repo now **versions itself** with its own Action (`.github/workflows/release.yml`): a push to
  an environment branch derives and pushes `vMM.P<suffix>`. This produces the *point* release tags
  (`v0.1.0`, `v0.1.1`, …) — but NOT a **moving `v1`** alias, which is what consumers pin to. Moving
  the `v1`/`vMAJOR` alias forward on each release is the missing piece this feature owns.

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
