# Tasks: Build once — a read-only lookup before the checks

**Input**: [spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md),
[contracts/interface.md](./contracts/interface.md)

Tests are required by the constitution (test-matrix discipline): each story's rows are written
first and run red before the code that makes them pass.

## Phase 1: Setup

- [x] T001 Confirm the baseline: `npm run test:release` green on the branch before any change (scripts/*.test.sh)

## Phase 2: Foundational

- [x] T002 Add a `derive_full` helper printing `version|tag|released-as` (or FAIL) and a `MODE` passthrough to the harness in scripts/derive-version.test.sh

## Phase 3: User Story 1 — a promotion knows it is one before the checks run (P1)

**Independent test**: L1, L3, L7, L10 pass.

- [x] T003 [US1] Write rows L1 (lookup reports reuse, tag set unchanged), L3 (lookup then tag agree, one new tag), L7 (first by name), L10 (prefixed) in scripts/derive-version.test.sh
- [x] T004 [US1] Read and validate `MODE` (`tag` default | `lookup`) at the top of scripts/derive-version.sh, beside the strategy check
- [x] T005 [US1] Compute `released_as` after step 1 when the number was reused (first tag by name in this namespace carrying the number on HEAD's tree), empty otherwise and under package-json, in scripts/derive-version.sh
- [x] T006 [US1] Stop after the exists-guard in lookup mode: write `version`, `tag`, `released-as` and exit without identity, tag or push; write `released-as` in tag mode too, in scripts/derive-version.sh
- [x] T007 [US1] Add input `mode` (default `tag`, mapped to `MODE` on the derive step) and output `released-as` to action.yml

## Phase 4: User Story 2 — new code is checked and built as always (P1)

**Independent test**: L2, L12 pass.

- [x] T008 [US2] Write rows L2 (minted number, empty released-as, no tag) and L12 (heal state: same answer as tag, empty released-as) in scripts/derive-version.test.sh

## Phase 5: User Story 4 — existing consumers see no change (P1)

**Independent test**: the whole existing matrix passes unedited; L8, L9 pass.

- [x] T009 [US4] Write rows L8 (tag mode reports released-as on a promotion) and L9 (package-json: empty released-as, no tag in lookup) in scripts/derive-version.test.sh
- [x] T010 [US4] Add I4 to scripts/action.test.sh: wiring of `mode`→`MODE` with default `tag`, output `released-as` from derive, and a replayed lookup then tag that agree

## Phase 6: User Story 3 — the look-up fails where tagging would (P2)

**Independent test**: L4, L5, L6, L11 pass.

- [x] T011 [US3] Write rows L4 (already-released target: FAIL), L5 (shallow: FAIL), L6 (bad mode: FAIL), L11 (no identity, no origin: succeeds) in scripts/derive-version.test.sh

## Phase 7: Polish

- [x] T012 Add a real `uses: ./` look-up to the PR gate (read-only token: proves lookup needs no write) in .github/workflows/test.yml
- [x] T013 Document `mode` and `released-as` in the interface reference of README.md and the inputs/outputs list in CLAUDE.md
- [x] T014 [P] Amend the constitution's I/O summary with `mode` and `released-as` (PATCH 1.2.0 → 1.2.1, Sync Impact Report) in .specify/memory/constitution.md
- [x] T015 Update the script header and the test header row index (L-series) in scripts/derive-version.sh and scripts/derive-version.test.sh
- [ ] T016 Run `npm run test:release` and actionlint; open the PR
- [ ] T017 After this feature is released: in a follow-up PR, add the build-once recipe and the interface reference to CONSUMING.md, pinned to the release that carries `mode` (an older pin ignores `mode` and would tag before the checks), and move the other recipe pins with it (FR-009)

## Dependencies

T001 → T002 → US1 (T003–T007) → US2, US4, US3 (rows only; any order) → Polish. T012 and T013
waited on PR #10: it rewrites test.yml, README.md, CLAUDE.md and CONSUMING.md, so they are done after
it merges and this branch is rebased, never alongside it. T017
waits on this feature's own release, whose pin the recipe needs.

## Parallel opportunities

T012, T013, T014 touch different files. The row-writing tasks share one file and run in sequence.

## Implementation strategy

US1 is the MVP and carries all the code; US2–US4 are rows that pin behavior the US1 code already
has. Ship as one PR; the recipe (T017) follows PR #10.
