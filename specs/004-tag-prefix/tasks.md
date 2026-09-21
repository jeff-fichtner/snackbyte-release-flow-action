---
description: "Task list for 004-tag-prefix"
---

# Tasks: Tag prefix — two releasables in one repository

**Input**: [plan.md](./plan.md), [spec.md](./spec.md), [contracts/](./contracts/)

**Tests**: Included (FR-009 mandates them). Discipline: the un-prefixed path is byte-for-byte
unchanged (Constitution VII) — the existing matrix proves it; the new work is the prefix parameter
+ its rows.

## Phase 1: Tests first (define the target)

- [X] T001 [P] [US2] Add prefixed rows T1–T8 to `scripts/derive-version.test.sh` per [contracts/versioning.md](./contracts/versioning.md), with a `derive_out` helper for T8 (version|tag)
- [X] T002 [P] [US1] Add TP-default (explicit empty == absent) and the blindness rows T3/T3' (un-prefixed ignores prefixed tags)
- [X] T003 [P] Add invalid-prefix rows X2a–X2d + X2n (tag list unchanged)
- [X] T004 [P] [US2] Add wiring facts (`TAG_PREFIX` mapped; default `""`) and the I3 prefixed replay row to `scripts/action.test.sh`

## Phase 2: Implementation

- [X] T005 [US2] In `scripts/derive-version.sh`: read `TAG_PREFIX` (default `""`); validate it beside `version-strategy` (regex + `git check-ref-format`), before any resolve/guard work; regex-escape it (`PFXE`); anchor `patch_re` and both `git tag -l` globs on it; build `tag="${TAG_PREFIX}v${version}${suffix}"`. Leave `version` bare
- [X] T006 [US2] Add `tag-prefix` input to `action.yml` (default `""`) and map it to the derive step as `env: TAG_PREFIX: ${{ inputs.tag-prefix }}`; update the `tag` output description

## Phase 3: Green + regression

- [X] T007 Run `bash scripts/derive-version.test.sh` against the OLD script: T-series/X2 rows FAIL there (they discriminate); against the NEW script: entire matrix green, existing rows byte-identical to the pre-change baseline (SC-001)
- [X] T008 Run the full `npm run test:release`; all suites green (SC-007)
- [X] T009 By-hand two-releasable scenario against one throwaway repo; record tag list + both derivations (SC-008)

## Phase 4: Governance + docs

- [X] T010 Amend Constitution III (1.0.0 → 1.1.0): optional namespace prefix; max/reuse within the namespace; Sync Impact Report updated
- [X] T011 [P] `CONSUMING.md`: `tag-prefix` in the inputs reference; "Two releasables in one repository" under "Consuming from a subdirectory" (one workflow per releasable, `paths:` filter + trade-off, repository-tree reuse key); correct the `<app>/package.json` claim
- [X] T012 [P] `README.md`: `tag-prefix` in the inputs line

## Dependencies

- Phase 1 (tests) before Phase 2 (impl) — the new rows fail before T005/T006 (proved in T007).
- Phase 3 gates on Phase 2. Phase 4 after green.

## Notes

- The package.json-location gap (subdirectory library under `package-json`) is an open point in
  plan.md, not a task here.
- This repo keeps versioning ITSELF un-prefixed; the release is a minor bump cut by the maintainer.
