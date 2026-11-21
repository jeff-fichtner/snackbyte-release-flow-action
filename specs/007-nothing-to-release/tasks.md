# Tasks: Nothing to release

**Input**: [spec.md](./spec.md), [plan.md](./plan.md), [contracts/interface.md](./contracts/interface.md)

Tests first: each row was written and run red against the unchanged script before the code.

## Phase 1: Setup

- [x] T001 Baseline: `npm run test:release` green on main before any change

## Phase 2: User Story 1 — a merge without a bump is green (P1)

- [x] T002 [US1] Rows NR1, NR2, NR5, NR6, NR9 in scripts/derive-version.test.sh (red against the unchanged script: NR1, NR2, NR6, NR9 fail)
- [x] T003 [US1] `already_released` check and the look-up report, plus tag mode's clearer refusal, in scripts/derive-version.sh

## Phase 3: User Story 2 — a real collision still fails (P1)

- [x] T004 [US2] Rows NR3 (re-run), NR4 (another line of history), NR10 (build-id unchanged)

## Phase 4: User Story 3 — channels and namespaces (P2)

- [x] T005 [US3] Rows NR7 (channel suffix), NR8 (tag prefix)

## Phase 5: Interface and end to end

- [x] T006 I5 in scripts/action.test.sh (`invoke_action` gains a strategy argument)
- [x] T007 A real `uses: ./` look-up in .github/workflows/test.yml's merge gate
- [x] T008 action.yml descriptions (`mode`, `released-as`), README inputs/outputs and failure list, CONSUMING.md reference, constitution 1.2.2

## Phase 6: After the release that carries 007

- [ ] T010 CONSUMING.md Recipe B: the look-up shape from [quickstart.md](./quickstart.md), pinned to that release's SHA; ritual step 4 reworded
- [ ] T011 Rollout: `ops request` to each `package-json` consumer (snackbyte-npm-base and its spin-outs, snackbyte-auth's client-node release) to move the pin and replace its own look-up step with the Action's
