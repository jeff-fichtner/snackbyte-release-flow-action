---
description: "Task list for 002-version-strategy"
---

# Tasks: Pluggable version strategy (build-id | package-json)

**Input**: [plan.md](./plan.md), [spec.md](./spec.md), [contracts/](./contracts/)

**Tests**: Included (FR-008 mandates them). Discipline: build-id path is byte-for-byte unchanged
(Constitution VII) — B1–B15 prove it; the new work is the package-json branch + its rows.

## Phase 1: Tests first (define the target)

- [X] T001 [P] [US2] Add package-json rows S1–S7 to `scripts/derive-version.test.sh` per [contracts/versioning.md](./contracts/versioning.md): S1 `v1.4.0`, S2 `v1.4.0-a`, S3 ignores existing tags → `v2.0.0`, S4 collision FAIL, S5 prerelease `v1.4.0-rc.1`, S6 major-minor ignored, S7 unknown branch FAIL. Pass `VERSION_STRATEGY=package-json` and per-fixture `package.json` versions
- [X] T002 [P] [US1] Add row BD-default to `scripts/derive-version.test.sh`: `derive main` (no strategy) equals `derive main VERSION_STRATEGY=build-id` (proves default = build-id)
- [X] T003 [P] Add invalid-strategy row X1 to `scripts/derive-version.test.sh`: `VERSION_STRATEGY=bogus` → FAIL, no tag
- [X] T004 [P] [US2] Add a wiring assertion to `scripts/action.test.sh`: `action.yml` maps `inputs.version-strategy` to the derive step's `VERSION_STRATEGY` env

## Phase 2: Implementation

- [X] T005 [US2] In `scripts/derive-version.sh`, read `VERSION_STRATEGY` env (default `build-id`). After the shared setup (suffix lookup, dup-suffix warn, shallow guard) and BEFORE the build-id derivation block, branch: if `package-json`, set `version` = `node -p "require('./package.json').version"` verbatim and skip the build-id engine; if `build-id`, run the existing derivation unchanged; else fail loud (X1). Keep the shared tail (collision guard, identity fallback, tag + push, outputs) common to both
- [X] T006 [US2] Add `version-strategy` input to `action.yml` (default `build-id`) and map it to the derive step as `env: VERSION_STRATEGY: ${{ inputs.version-strategy }}`

## Phase 3: Green + regression

- [X] T007 Run `bash scripts/derive-version.test.sh`; confirm B1–B15 UNCHANGED green (zero regression, SC-001) AND S1–S7 (SC-002/003), BD-default, X1 (SC-004) green. S7 exercises strategy-independence of the unknown-branch guard (SC-005)
- [X] T008 Run the full `npm run test:release`; all suites green including the action.test.sh wiring row and the CI gate (SC-006)

## Phase 4: Docs

- [X] T009 [P] Update `README.md` Usage: document `version-strategy` (build-id for apps = default; package-json for libraries), with the library `uses:` + `npm publish` example from [contracts/action-io.md](./contracts/action-io.md)
- [X] T010 [P] Update `CLAUDE.md` non-negotiables/status: note the two strategies and that libraries use package-json

## Dependencies

- Phase 1 (tests) before Phase 2 (impl) — TDD; the new rows should fail before T005/T006.
- T005 before T006 (the input is meaningless until the script honors it) — though both land together.
- Phase 3 gates on Phase 2. Phase 4 docs [P] after green.

## Parallel

- T001–T004 are different test additions / files → parallel.
- T009–T010 docs → parallel.

## Notes

- build-id is NOT re-touched beyond wrapping it in the strategy branch (Constitution VII).
- This repo keeps versioning ITSELF with build-id (it is a deployable-style repo); package-json is
  for library consumers like snackbyte-npm-base.
