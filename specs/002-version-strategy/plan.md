# Implementation Plan: Pluggable version strategy (build-id | package-json)

**Branch**: `002-version-strategy` | **Date**: 2026-07-06 | **Spec**: [spec.md](./spec.md)

## Summary

Add a `version-strategy` input (`build-id` default | `package-json`) so the one Action serves both
deployable apps (build-id, today's tree-reused monotonic PATCH) and published libraries
(package-json, tag the intentional SemVer verbatim). resolve-env, the manifest, tag-only, and every
guard are shared and strategy-independent; only the version-number rule branches. `build-id` is
byte-for-byte unchanged (the existing B1–B15 matrix must still pass); `package-json` is a small new
code path (~10 lines) that reuses the shared spine and skips the build-id derivation engine.

## Technical Context

**Language/Version**: Bash + Node (unchanged from 001). No new runtime.

**Primary Dependencies**: `git`, `node`, POSIX tools; GitHub Actions runner. Unchanged.

**Testing**: Extend the existing bash suites — `derive-version.test.sh` gains `package-json` rows
(S-series) and an invalid-strategy guard row; the build-id matrix (B1–B15) runs unchanged to prove
zero regression; `action.test.sh` gains a wiring row for the new input. Run via `npm run test:release`
and the CI gate.

**Target Platform**: GitHub Actions runners + local. Unchanged.

**Project Type**: Composite GitHub Action (unchanged layout).

**Constraints**: Backward compatibility is paramount — default `build-id`, existing consumers and this
repo's own self-versioning unaffected. `package-json` tags `package.json`'s version verbatim (no SemVer
parsing/validation). Invalid strategy fails loud.

**Scale/Scope**: ~1 new input in `action.yml`; a strategy branch in `derive-version.sh` wrapping the
existing derivation; ~4–6 new test rows.

## Constitution Check

*GATE: Must pass before implementation.*

| Principle | Gate | Status |
|---|---|---|
| I. Tag-Only, Never a Commit | Both strategies tag only. | PASS — the branch is only in *how the version string is chosen*; the `git tag`/push is shared, unchanged. |
| II. Tree-Hash Is the Reuse Key | build-id keeps tree reuse; package-json legitimately has none. | PASS — reuse is a build-id property; package-json deliberately does not reuse (SemVer is human-chosen). No change to build-id's reuse. |
| III. Fixed, Derived Tag Format | Format stays `v{version}{suffix}`. | PASS — both produce `v…`; build-id derives `MM.P`, package-json uses the declared version. Same grammar `v<version>[-suffix]`. |
| IV. Manifest Is the Product (one-row edit) | No manifest schema change. | PASS — a library reuses `environments.json` as-is; no new facet added. One-row-edit preserved. |
| V. Fail Loud, Never Silent | New guard: invalid strategy; existing guards shared. | PASS — invalid `version-strategy` fails loud (FR-006); existing-tag/shallow/unknown-branch guards run under both strategies. |
| VI. Distributed as an Action, Not a Package | Still tags; does not publish. | PASS — package-json produces a SemVer *tag*; turning it into `npm publish` is the consumer's downstream workflow, not this Action. No publish surface added. |
| VII. Extract by Parameterization, Not Rewrite | build-id path unchanged. | PASS — the existing derivation is wrapped by a strategy check, not rewritten; B1–B15 proves it byte-for-byte. |

**Result**: All gates PASS. No Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/002-version-strategy/
├── plan.md              # this file
├── spec.md              # WHAT/WHY
├── contracts/
│   ├── action-io.md     # the version-strategy input + package-json semantics
│   └── versioning.md    # package-json rows (S-series) + invalid-strategy guard + shared invariants
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks output
```

### Source Code (changed files only)

```text
action.yml                     # + input: version-strategy (default build-id); passed to derive as env
scripts/derive-version.sh      # + strategy branch: build-id (existing) | package-json (new ~10 lines)
scripts/derive-version.test.sh # + S-series package-json rows + invalid-strategy guard row
scripts/action.test.sh         # + wiring assertion: version-strategy input mapped to the derive step
README.md / CONSUMING.md       # document both strategies + when to use which
```

**Structure Decision**: No new files for logic — the strategy lives inside the existing
`derive-version.sh` as an early branch. The shared spine (resolve-env call, suffix lookup, shallow
guard, collision guard, identity fallback, tag + push) runs for both strategies; only the block that
computes `version` differs. This keeps "one Action, one script, pluggable policy" literal.

## Complexity Tracking

> No Constitution violations. No entries.
