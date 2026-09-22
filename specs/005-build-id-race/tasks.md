# Tasks: Build-id race — per-releasable serialization and a self-healing reuse

**Branch**: `005-build-id-race` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
| **Contract**: [contracts/versioning.md](./contracts/versioning.md) | **Issue**: #3

Order is dependency order: the constitution states the rule, the code implements it, the docs
restate it, the rows prove it, the bump ships it.

## Phase 1 — the rule

- [ ] **T001** Amend `.specify/memory/constitution.md` L92: the max-over-suffixes invariant holds
      across **serialized** derivations — the tag scan and the tag push are not atomic, so concurrent
      runs that both read the tag set before either pushes will both mint the same number. Note that
      step 1 detects and heals the residue. (FR-009, US4-1)
- [ ] **T002** Amend `.specify/memory/constitution.md` L123: replace the "serialize runs on the same
      branch" guard with per-**releasable** serialization — one concurrency group per tag namespace,
      because the number is global to the namespace; a per-branch group does not serialize `main`
      against `dev`. (FR-009, US4-2)

## Phase 2 — the heal

- [ ] **T003** `scripts/derive-version.sh`: in the step-1 candidate loop, compute
      `target="${TAG_PREFIX}v${MM}.${n}${suffix}"` and skip the candidate when `target` resolves to a
      tree other than `HEAD_TREE`. Continue the scan so the highest **usable** candidate wins.
      (FR-001, FR-002, FR-006, US1-1, US2-1, US2-2)
- [ ] **T004** `scripts/derive-version.sh`: emit `::warning title=Duplicate build id::…` naming the
      number and the conflicting tag when a candidate is skipped — degrades to a plain line outside
      Actions. (FR-003, US1-1)
- [ ] **T005** `scripts/derive-version.sh`: correct the header comment (L18–21) to state the
      invariant's precondition and point at the per-releasable group requirement. (FR-010)
- [ ] **T006** Verify by inspection that the exists-guard and step 2 are untouched, and that the heal
      sits inside the `build-id` arm only. (FR-004, FR-005, FR-007)

## Phase 3 — the rows

- [ ] **T007** `scripts/derive-version.test.sh`: add a `derive_err` helper (like `derive_out`, but
      returning stderr) so a row can assert the annotation `derive` currently swallows.
- [ ] **T008** Add **R1** (the wedge heals → `vMM.3`), **R1w** (stderr carries `::warning` and the
      number), **R1t** (both pre-existing tags untouched). (US1)
- [ ] **T009** Add **R2** — free target still reuses → `vMM.2-c`, not `vMM.3`. The row that pins the
      narrow predicate. (US2-1)
- [ ] **T010** Add **R3** — highest **usable** candidate wins → `vMM.1`. (US2-2, FR-002)
- [ ] **T011** Add **R4** and **R4'** — the heal is namespace-anchored; bare tags never poison a
      prefixed candidate. (FR-006)
- [ ] **T012** Run `npm run test:release`; confirm B7 and B8 pass **unchanged** and the whole
      existing matrix is green. (SC-003)

## Phase 4 — the restatements

- [ ] **T013** `README.md` L202 and L207: correct the invariant and replace "same-branch run
      serialization". (FR-010, US4-3)
- [ ] **T014** `CONSUMING.md` L116: drop "Collisions are structurally impossible, for any number of
      environments"; state the precondition and the required group. (FR-010)
- [ ] **T015** `CONSUMING.md` — all four recipes: group keyed on the releasable (bare `release`, or
      `release-<tag-prefix>` for the two-releasables recipe), `cancel-in-progress: false`,
      `queue: max`, with a comment explaining why `queue: max` is not optional (one pending run per
      group; a newer run cancels the pending one) and noting that groups are repository-scoped.
      (FR-008, US3-1, US3-2)
- [ ] **T016** `.github/workflows/release.yml` L17–20: same block as recipe A, byte-identical, and
      fix the comment. (FR-008, US3-3)
- [ ] **T017** `specs/001-extract-release-flow/plan.md` L53 and `research.md` L97: these describe
      001-as-delivered. Leave the historical record intact; add a one-line superseded-by pointer to
      this feature rather than rewriting history. (FR-010)

## Phase 5 — ship

- [ ] **T018** `package.json` `1.1.0` → `1.2.0`. (plan Rollout)
- [ ] **T019** Full gate green: `npm run test:release`.
- [ ] **T020** PR against `main`, issue #3 in the body. After merge: confirm the derived `v1.2.0`,
      then re-point the floating `v1` by hand (nothing in `release.yml` moves it).

## Dependencies

- T001–T002 before everything (the rule precedes its implementations).
- T003 before T004 (the annotation needs the skip site); T003–T004 before T008–T011.
- T007 before T008 (R1w needs the helper).
- T012 gates Phase 4; T019 gates T020.
- T015 and T016 must land together — they are the same block in two places (US3-3).
