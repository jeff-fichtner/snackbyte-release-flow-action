---
description: "Task list for 001-extract-release-flow"
---

# Tasks: Extract the manifest-driven release flow as a reusable Action

**Input**: Design documents from `specs/001-extract-release-flow/`

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: Test tasks ARE included — the spec explicitly requires them (FR-011..FR-014;
SC-001/003/005/006/007/008) and pins a behavior-complete matrix
([contracts/versioning.md](./contracts/versioning.md)) as the acceptance oracle. This is a
port: the source's own tests are the tests, extended with the extraction-delta rows.

**Organization**: By user story (US1–US4). Because this is an *extraction*, the two P1 stories
(US1 derive-version, US2 resolve-env) share a foundational spine — the parameterized scripts —
extracted in Phase 2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1/US2/US3/US4; Setup/Foundational/Polish carry no story label
- Every task names an exact file path

## Path Conventions

Single-project composite-Action layout (per [plan.md](./plan.md)): `action.yml` at repo root,
`scripts/` for logic + bash tests, `.github/workflows/` for CI. Source of truth for the port is
`snackbyte-base/scripts/` and its `resolve-env` CI job.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project scaffolding for a composite Action + bash test harness.

- [X] T001 Create the source layout: `scripts/` directory at repo root and `.github/workflows/` directory
- [X] T002 Create a dev-only `package.json` at repo root with a `test:release` script placeholder (chains the suites; carries NO `exports`/`files`/publish surface — Constitution VI) and `"private": true`
- [X] T003 [P] Add a real default `environments.json` at repo root (production/`main`/`""`, staging/`dev`/`-dev`) — the Action's own manifest and the default-path target; the ported test suites write their OWN stand-in manifests inline (P/A/C) per the source, so no separate fixture file is created

**Checkpoint**: Empty but correct skeleton exists; nothing runs yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extract and parameterize the two core scripts every user story builds on. This is
the extraction spine — US1 and US2 cannot proceed until the scripts exist and read inputs
(Constitution VII: parameterize, don't rewrite).

**⚠️ CRITICAL**: No user-story work begins until this phase is complete.

- [X] T004 Port `snackbyte-base/scripts/derive-version.sh` → `scripts/derive-version.sh` VERBATIM first (no logic change), preserving all guards (shallow refusal, collision, unknown-branch, dup-suffix warn) and the tree-hash reuse block
- [X] T005 Parameterize `scripts/derive-version.sh`: resolve the manifest from the `MANIFEST` **environment variable** (default `./environments.json`) instead of the literal `require('./environments.json')`, and MAJOR.MINOR from the `MAJOR_MINOR` **environment variable** (default: read `package.json`) instead of the literal `require('./package.json')` — branch stays a positional arg; algorithm untouched (research D1, D2, D5)
- [X] T006 [P] Extract the `resolve-env` predicate from `snackbyte-base/.github/workflows/ci-cd.yml` (the inline `node -e "...environments.some(e => e.branch === ...)"`) into `scripts/resolve-env.sh`, taking the branch as a positional arg (default `$GITHUB_REF_NAME`) and the manifest from the `MANIFEST` **environment variable** (default `./environments.json`) — same convention as T005 — writing `is-env=true|false` to stdout and `$GITHUB_OUTPUT` (research D3)
- [X] T007 `chmod +x scripts/derive-version.sh scripts/resolve-env.sh`

**Checkpoint**: Both scripts exist, run, and read their inputs — ready to be driven by tests and the Action.

---

## Phase 3: User Story 1 — Derive the correct version tag for an environment push (Priority: P1) 🎯 MVP

**Goal**: A push to an environment branch produces the one correct, tree-hash-reused-or-advanced,
tag-only version tag.

**Independent Test**: Run the derivation matrix against throwaway repos; every row's produced tag
matches the expected tag ([contracts/versioning.md](./contracts/versioning.md) B1–B15).

### Tests for User Story 1 ⚠️ (write/port FIRST; confirm they exercise the real script)

- [X] T008 [P] [US1] Port `snackbyte-base/scripts/derive-version.test.sh` → `scripts/derive-version.test.sh` (rows B1–B15, throwaway-repo fixtures written inline + local bare origin), adjusting only the path it copies the script from; keep `PKG_MM` support. Includes the fail-loud rows B7 (collision), B11 (unknown branch), B12 (shallow) — these satisfy SC-005
- [X] T009 [US1] Add extraction-delta rows P3–P5 to `scripts/derive-version.test.sh`: P3 non-default manifest path (`MANIFEST=config/envs.json` derives identical to B1), P4 `MAJOR_MINOR=2.7` override → `v2.7.0`, P5 default reads declared version → `vMM.0` (SC-007)

### Implementation for User Story 1

- [X] T010 [US1] Run `bash scripts/derive-version.test.sh`; make B1–B15 + P3–P5 green — fixing only parameterization wiring in `scripts/derive-version.sh`, never the algorithm (any intended deviation documented in [research.md](./research.md) per Constitution VII)

**Checkpoint**: Version derivation is correct and tag-only across every behavior; MVP-viable on its own.

---

## Phase 4: User Story 2 — Short-circuit pushes to non-environment branches (Priority: P1)

**Goal**: A push to a non-environment branch is recognized as such (no build/tag/deploy),
answered via `is-env`.

**Independent Test**: `resolve-env.sh` returns `is-env=true` for a declared environment branch
and `is-env=false` otherwise ([contracts/versioning.md](./contracts/versioning.md) P1–P2).

### Tests for User Story 2 ⚠️

- [X] T011 [P] [US2] Write `scripts/resolve-env.test.sh` covering P1 (`main` → `is-env=true`) and P2 (`feature-x` → `is-env=false`) against the fixture manifest (SC-002)

### Implementation for User Story 2

- [X] T012 [US2] Run `bash scripts/resolve-env.test.sh`; make P1–P2 green — fixing only `scripts/resolve-env.sh` wiring, preserving the exact source predicate

**Checkpoint**: The CI short-circuit works standalone; US1 and US2 together cover both P1 stories.

---

## Phase 5: User Story 3 — Adopt/evolve environments as a one-row manifest edit (Priority: P2)

**Goal**: Adding an environment is a one-row edit to `environments.json` with no other change.

**Independent Test**: Adding a `qa` row (a) touches only `environments.json`, (b) derives `vMM.0-qa`,
(c) resolve-env recognizes `qa` and rejects a non-env branch ([contracts/versioning.md](./contracts/versioning.md) add-env proof).

### Tests for User Story 3 ⚠️

- [X] T013 [P] [US3] Port `snackbyte-base/scripts/add-env.test.sh` → `scripts/add-env.test.sh`, adjusting paths; assert the diff-guard (only `environments.json` changed), `-qa` derivation, and the resolve-env recognize/reject checks (SC-003)

### Implementation for User Story 3

- [X] T014 [US3] Run `bash scripts/add-env.test.sh`; make it green (no script change expected — this proves the existing scripts already honor a one-row edit; if a change is needed, that itself is a finding)

**Checkpoint**: The one-row-edit promise is proven executable.

---

## Phase 6: User Story 4 — Reference the flow as a versioned, shared unit (Priority: P2)

**Goal**: The flow is consumable as a single referenced Action returning `is-env`/`version`/`tag`,
with no vendored logic.

**Independent Test**: Invoking `action.yml` against a fixture yields the correct outputs for both an
env push and a non-env push ([contracts/versioning.md](./contracts/versioning.md) I1–I2).

### Tests for User Story 4 ⚠️

- [X] T015 [P] [US4] Write `scripts/action.test.sh` (I1–I2): invoke the composite Action end-to-end against an inline fixture; assert env push → `is-env=true`, `version=MM.0`, `tag=vMM.0<suffix>` matching derivation, and non-env push → `is-env=false` with `version`/`tag` unset and no tag created (SC-006). Additionally assert INV-1/SC-004 automatically: after an env push exactly one new tag exists and the commit count (`git rev-list --count HEAD`) and branch head are unchanged

### Implementation for User Story 4

- [X] T016 [US4] Author `action.yml` at repo root: composite Action (`runs.using: composite`) with inputs `branch` (default `${{ github.ref_name }}`), `manifest` (default `./environments.json`), `major-minor` (default: read `package.json`) and outputs `is-env`, `version`, `tag`, wiring steps to `scripts/resolve-env.sh` then `scripts/derive-version.sh` per [contracts/action-io.md](./contracts/action-io.md) (research D4)
- [X] T017 [US4] Run `bash scripts/action.test.sh`; make I1–I2 green — fixing only `action.yml` wiring (input pass-through, output mapping, gating so a non-env push skips derivation)

**Checkpoint**: The Action's own interface is verified, not just the scripts underneath it.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Wire the mandatory CI gate and the single test entrypoint; final validation.

- [X] T018 Wire `package.json` `test:release` to chain all suites: `derive-version.test.sh` (B1–B15 + P3–P5), `resolve-env.test.sh` (P1–P2), `add-env.test.sh`, `action.test.sh` (I1–I2)
- [X] T019 Author `.github/workflows/test.yml`: on every push, checkout with `fetch-depth: 0`, run `npm run test:release`; the job MUST fail on any `FAIL>0` (SC-008, mandatory gate — Constitution V / base Principle VII)
- [X] T020 [P] Update `README.md` "Intended shape (deferred)" section to "built": document the real `action.yml` inputs/outputs and a consumer `uses:` example from [contracts/action-io.md](./contracts/action-io.md)
- [X] T021 [P] Update `CLAUDE.md` status from "build deferred" to "001 implemented" with a pointer to the scripts and `action.yml`
- [X] T022 Run the full [quickstart.md](./quickstart.md) validation locally; confirm `FAIL=0` across every suite (the INV-1/SC-004 one-tag-zero-commits assertion is now automated in T015, so this is the final end-to-end confirmation, not the sole check)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately.
- **Foundational (Phase 2)**: depends on Setup — **BLOCKS all user stories** (the scripts are the spine).
- **US1 (Phase 3)** and **US2 (Phase 4)**: depend on Foundational; independent of each other → parallelizable.
- **US3 (Phase 5)**: depends on Foundational (needs both scripts for its 3-part assertion). Independent of US1/US2 authoring but exercises both.
- **US4 (Phase 6)**: depends on Foundational (wraps both scripts). Its test (T015) can be written anytime; `action.yml` (T016) needs the scripts.
- **Polish (Phase 7)**: depends on all stories whose suites it chains and gates.

### User Story Dependencies

- **US1 (P1)**: after Foundational — no dependency on other stories.
- **US2 (P1)**: after Foundational — no dependency on other stories.
- **US3 (P2)**: after Foundational — reuses US1+US2 scripts but is independently testable.
- **US4 (P2)**: after Foundational — wraps US1+US2 scripts; independently testable via `action.test.sh`.

### Within Each User Story

- Port/write the test FIRST, confirm it drives the real script, then make it green.
- Foundational scripts before any story; `action.yml` (US4) after the scripts exist.
- Never edit the algorithm to pass a test — only parameterization wiring (Constitution VII).

### Parallel Opportunities

- T003 [P] runs alongside T001–T002.
- T006 [P] (resolve-env) is independent of T004–T005 (derive-version) within Foundational.
- Once Foundational completes, **US1 and US2 can proceed fully in parallel**; US3 and US4 tests (T013, T015) can be written in parallel too.
- Polish docs T020/T021 [P] run together.

---

## Parallel Example: after Foundational (Phase 2) completes

```bash
# US1 and US2 in parallel (different files, no shared incomplete deps):
Task: "Port derive-version.test.sh + add delta rows, make B1–B15/P3–P5 green (scripts/derive-version.test.sh)"
Task: "Write resolve-env.test.sh + make P1–P2 green (scripts/resolve-env.test.sh)"

# Within Foundational, the two extractions in parallel:
Task: "Port + parameterize scripts/derive-version.sh"
Task: "Extract scripts/resolve-env.sh from the inline CI job"
```

---

## Implementation Strategy

### MVP First (US1 + US2 — both P1)

1. Phase 1 Setup → Phase 2 Foundational (the extraction spine).
2. Phase 3 US1 (derive-version green) — this alone gives a repo correct release tags.
3. Phase 4 US2 (resolve-env green) — completes the two-question flow.
4. **STOP and VALIDATE**: run both suites; every row green, tag-only confirmed.

The MVP here is US1+US2 (not US1 alone) because the release flow's value is the *pair* — "is it
an environment?" gating "what tag?". Both are P1 and both fall out of the same extracted scripts.

### Incremental Delivery

1. Setup + Foundational → spine ready.
2. US1 + US2 → the flow works locally (MVP).
3. US3 → the one-row-edit promise proven.
4. US4 → the Action interface wrapped and verified end-to-end.
5. Polish → CI gate + docs; the flow is now a referenceable, CI-guarded shared unit.

### Notes

- [P] = different files, no incomplete dependencies.
- This is a PORT: prefer verbatim copy then minimal parameterization; a large diff from source is a smell (Constitution VII).
- Commit after each task or logical group; keep the suite green at every step.
- Out of scope for 001 (candidate 002): Marketplace publish, the Action's own `v1` release workflow, inline-JSON manifest form.
