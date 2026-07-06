# Implementation Plan: Extract the manifest-driven release flow as a reusable Action

**Branch**: `001-extract-release-flow` | **Date**: 2026-07-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-extract-release-flow/spec.md`

## Summary

Extract the battle-tested, manifest-driven release flow from `snackbyte-base` into this
repo as a **composite GitHub Action** exposing two capabilities — resolve-env ("is this
branch an environment?") and derive-version ("what tag does this push get?") — that create a
tag and nothing else. The algorithm, manifest convention, and behavior matrix are done and
proven; the work is **parameterization**: replace the source's hard-coded
`require('./environments.json')` and `require('./package.json')` reads and its fixed script
paths with Action inputs (`branch`, `manifest`, `major-minor`), and repackage the inline
`resolve-env` CI job as an Action output. Per Constitution Principle VII this is a
parameterizing port, not a rewrite: behavior must match the source, verified by porting its
15-row derivation matrix (B1–B15) plus the one-row-edit proof and keeping them green.

## Technical Context

**Language/Version**: Bash (POSIX-ish, `set -euo pipefail`) + Node.js (for the JSON reads
the manifest/version already require; Node is present on every GitHub-hosted runner). No new
runtime introduced — this mirrors the source exactly.

**Primary Dependencies**: `git` (tag/tree plumbing), `node` (JSON parse via `node -p`/`node -e`),
standard POSIX tools (`sed`, `sort`). GitHub Actions runner as host platform.

**Storage**: N/A (git tags are the only persisted artifact; no database, no files written
except `$GITHUB_OUTPUT`).

**Testing**: Bash acceptance harness ported from `snackbyte-base/scripts/derive-version.test.sh`
(rows B1–B15, self-contained throwaway-repo fixtures with a local bare origin) and
`add-env.test.sh` (one-row-edit proof). Run via a single `test:release`-style entrypoint.
Optionally a workflow-level smoke test that invokes the composite Action.

**Target Platform**: GitHub Actions runners (ubuntu-latest primarily); the scripts are
runner-agnostic bash+git+node and also run locally for the test harness.

**Project Type**: Reusable composite GitHub Action (distribution unit), with bundled bash
scripts and a bash test suite. Single-project layout.

**Performance Goals**: Not a hot path. resolve-env must be cheap enough to gate on before any
`npm ci` (single manifest read, `fetch-depth: 1`). Derivation scans existing `vMM.*` tags
once — linear in tag count, negligible at real repo scale.

**Constraints**: Tag-only (never a commit/branch push); refuse shallow clones; anchored-regex
tag parsing; fail-loud on existing target tag / unknown branch; same-branch run serialization
is the consumer's workflow concurrency concern (documented, not enforced in-script).

**Scale/Scope**: ~120-line derivation script + ~40-line resolve-env logic + `action.yml` +
~300 lines of ported tests. One manifest schema, five facets, one tag-format contract.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|---|---|---|
| I. Tag-Only, Never a Commit | Port must preserve `git tag`-only side effect; no commit/branch push added. | PASS — source already tag-only; port copies `git tag -a` + `git push origin <tag>` verbatim. |
| II. Tree-Hash Is the Reuse Key | Reuse keyed on `HEAD^{tree}` vs each tag's `^{tree}`, never SHA. | PASS — source logic (lines 83–94 of derive-version.sh) ported unchanged. |
| III. Fixed, Derived Tag Format | `v${MM}.${PATCH}${suffix}`; MM from version, PATCH = reuse-or-max+1 over all suffixes. | PASS — anchored `patch_re`, `sort -n | tail -1` ported unchanged. |
| IV. Manifest Is the Product (one-row edit) | Adding an env stays a one-row edit; facets independent. | PASS — parameterizing the manifest *path/content* does not touch the schema; `add-env.test.sh` ported as the proof. |
| V. Fail Loud, Never Silent | Existing-tag, shallow, unknown-branch, dup-suffix-warn guards preserved. | PASS — all four guards ported verbatim (lines 41–65, 108–111, 54–56). |
| VI. Distributed as an Action, Not a Package | Deliver `action.yml` + (later) moving `v1` tag; no npm publish surface. | PASS — composite `action.yml`; no `package.json` `exports`/`files`/publish added. A dev-only `package.json` for the test script is permitted (it is not a publish manifest). |
| VII. Extract by Parameterization, Not Rewrite | Behavior identical to source except deliberate, documented changes. | PASS — only parameterization changes: input-sourced `branch`/`manifest`/`major-minor`; algorithm untouched. Divergences (if any) recorded in research.md. |

**Result**: All gates PASS. No entries required in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-extract-release-flow/
├── plan.md              # This file (/speckit-plan output)
├── spec.md              # WHAT/WHY (/speckit-specify output)
├── research.md          # Phase 0 — parameterization decisions
├── data-model.md        # Phase 1 — manifest + tag + I/O entities
├── quickstart.md        # Phase 1 — how to run the tests / invoke the Action
├── contracts/
│   ├── action-io.md     # action.yml inputs/outputs contract
│   └── versioning.md    # derivation behavior matrix (ported B1–B15 + invariants)
├── checklists/
│   └── requirements.md   # spec quality checklist (/speckit-specify output)
└── tasks.md             # Phase 2 (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
action.yml                     # composite Action: inputs (branch, manifest, major-minor),
                               #   outputs (is-env, version, tag); runs the bundled scripts
scripts/
├── derive-version.sh          # ported from snackbyte-base; reads inputs, not fixed files
├── resolve-env.sh             # the resolve-env check, extracted from the inline CI job
├── derive-version.test.sh     # ported B1–B15 matrix (throwaway-repo fixtures)
└── add-env.test.sh            # ported one-row-edit proof
package.json                   # dev-only: the `test:release` entrypoint (NOT a publish manifest)
README.md                      # already present — usage + design rationale
.github/workflows/
└── test.yml                   # CI: run the release test suite (+ optional Action smoke test)
```

**Structure Decision**: Single-project composite-Action layout. Scripts live at
`scripts/` (mirroring `snackbyte-base` so the port is a near-copy + parameterize diff), the
Action manifest at repo root (`action.yml`) so consumers reference `owner/repo@v1` directly.
resolve-env graduates from an inline `ci-cd.yml` job into `scripts/resolve-env.sh` invoked by
the composite Action, exposing `is-env` as an output. A dev-only `package.json` provides the
`test:release` script; it deliberately carries no publish surface (Principle VI).

## Complexity Tracking

> No Constitution Check violations. No entries required.
