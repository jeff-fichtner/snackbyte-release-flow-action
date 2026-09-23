# Tasks: Build-id race — per-releasable serialization and a self-healing reuse

**Branch**: `005-build-id-race` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
| **Contract**: [contracts/versioning.md](./contracts/versioning.md) | **Issue**: #3

Order is dependency order: the constitution states the rule, the code implements it, the docs
restate it, the rows prove it, the bump ships it.

## Phase 1 — the rule

- [x] **T001** Amend `.specify/memory/constitution.md` L92: the max-over-suffixes invariant holds
      across **serialized** derivations — the tag scan and the tag push are not atomic, so concurrent
      runs that both read the tag set before either pushes will both mint the same number. Note that
      step 1 detects and heals the residue. (FR-009, US4-1)
- [x] **T002** Amend `.specify/memory/constitution.md` L123: replace the "serialize runs on the same
      branch" guard with per-**releasable** serialization — one concurrency group per tag namespace,
      because the number is global to the namespace; a per-branch group does not serialize `main`
      against `dev`. (FR-009, US4-2)

## Phase 2 — the heal

- [x] **T003** `scripts/derive-version.sh`: in the step-1 candidate loop, compute
      `target="${TAG_PREFIX}v${MM}.${n}${suffix}"` and skip the candidate when `target` resolves to a
      tree other than `HEAD_TREE`. Continue the scan so the highest **usable** candidate wins.
      (FR-001, FR-002, FR-006, US1-1, US2-1, US2-2)
- [x] **T004** `scripts/derive-version.sh`: emit `::warning title=Duplicate build id::…` naming the
      number and the conflicting tag when a candidate is skipped — degrades to a plain line outside
      Actions. (FR-003, US1-1)
- [x] **T005** `scripts/derive-version.sh`: correct the header comment (L18–21) to state the
      invariant's precondition and point at the per-releasable group requirement. (FR-010)
- [x] **T006** Verify by inspection that the exists-guard and step 2 are untouched, and that the heal
      sits inside the `build-id` arm only. (FR-004, FR-005, FR-007)

## Phase 3 — the rows

- [x] **T007** `scripts/derive-version.test.sh`: add a `derive_log` helper (like `derive_out`, but
      returning the run's diagnostic output) so a row can assert the annotation `derive` swallows.
      **Named `derive_log`, not `derive_err` as planned**: GitHub reads workflow commands from
      stdout, never stderr, so the annotation is emitted on stdout (via fd 3, to stay clear of the
      candidate stream) and the helper must capture both streams.
- [x] **T008** Add **R1** (the wedge heals → `vMM.3`), **R1w** (the log carries `::warning` and the
      number), **R1t** (both pre-existing tags untouched). (US1)
- [x] **T009** Add **R2** — free target still reuses → `vMM.2-c`, not `vMM.3`. The row that pins the
      narrow predicate. (US2-1)
- [x] **T010** Add **R3** — highest **usable** candidate wins → `vMM.1`. (US2-2, FR-002)
- [x] **T011** Add **R4** and **R4'** — the heal is namespace-anchored; bare tags never poison a
      prefixed candidate. (FR-006)
- [x] **T012** Run `npm run test:release`; confirm B7 and B8 pass **unchanged** and the whole
      existing matrix is green. (SC-003)

## Phase 4 — the restatements

- [x] **T013** `README.md` L202 and L207: correct the invariant and replace "same-branch run
      serialization". (FR-010, US4-3)
- [x] **T014** `CONSUMING.md` L116: drop "Collisions are structurally impossible, for any number of
      environments"; state the precondition and the required group. (FR-010)
- [x] **T015** `CONSUMING.md` — all four recipes: group keyed on the releasable (bare `release`, or
      `release-<tag-prefix>` for the two-releasables recipe), `cancel-in-progress: false`,
      `queue: max`, with a comment explaining why `queue: max` is not optional (one pending run per
      group; a newer run cancels the pending one) and noting that groups are repository-scoped.
      (FR-008, US3-1, US3-2)
- [x] **T016** `.github/workflows/release.yml` L17–20: same block as recipe A, byte-identical, and
      fix the comment. (FR-008, US3-3)
- [x] **T017** `specs/001-extract-release-flow/plan.md` L53 and `research.md` L97: these describe
      001-as-delivered. Leave the historical record intact; add a one-line superseded-by pointer to
      this feature rather than rewriting history. (FR-010)

## Phase 5 — ship

- [x] **T018** `package.json` `1.1.0` → `1.2.0`. (plan Rollout)
- [x] **T019** Full gate green: `npm run test:release`.
- [ ] **T020** PR against `main`, issue #3 in the body. After merge: confirm the derived `v1.2.0`,
      then re-point the floating `v1` by hand (nothing in `release.yml` moves it).

## Dependencies

- T001–T002 before everything (the rule precedes its implementations).
- T003 before T004 (the annotation needs the skip site); T003–T004 before T008–T011.
- T007 before T008 (R1w needs the helper).
- T012 gates Phase 4; T019 gates T020.
- T015 and T016 must land together — they are the same block in two places (US3-3).


## Implementation notes (things the plan did not predict)

- **`git rev-parse -q --verify` is load-bearing.** A bare `git rev-parse <missing-ref>^{tree}`
  PRINTS the unresolved argument to stdout before failing (exit 128). The `|| true` required to
  survive that failure under `set -e` also swallows the exit code, so the echoed string landed in
  `target_tree`: every absent target read as "owned by another tree" and every ordinary reuse was
  healed away into a fresh number. Caught immediately by the existing rows — B4, B5, B6a/B6c, B14,
  B15, T5 all failed before R2/R3/R4' did.
  (Measured 2026-09-22. An earlier note in this file said "exits 0"; that was a mis-measurement —
  the `$?` being read belonged to the enclosing `echo`, not to git. The fix is unchanged; the
  reason is not. The bottom exists-guard uses the exit code directly, with no `|| true`, and was
  verified to behave correctly on a missing tag.)
- **No apostrophes in comments inside the step-1 command substitution.** bash 3.2 (the system bash
  on macOS, where the suite runs locally) treats one as an opening quote even inside a comment, and
  the whole script fails to parse. Linux CI runs a newer bash and would NOT have caught it. A note
  to this effect is in the script at the top of the loop.
- **The annotation goes to stdout on fd 3.** Workflow commands are read from stdout, so `>&2` would
  never produce an annotation; but the loop's stdout is the candidate stream feeding `sort`, so
  writing there corrupts the derivation. fd 3 is bound to the real stdout before the command
  substitution captures stdout.

## Self-review outcomes (applied before requesting review)

Reviewing the branch as a whole turned up five defects in it, all fixed here:

- **The constitution named a vendor keyword.** Principle V required `queue: max` by name, in a
  document that otherwise speaks only of tags, trees and manifests — and that would go stale if
  GitHub renamed it. Restated as the requirement ("MUST NOT drop a release it defers"); the
  keyword lives in CONSUMING.md, where it can be corrected.
- **An over-strong MUST NOT.** The constitution forbade two releasables sharing a group. Sharing
  is merely slower, not incorrect; stating it as law put a performance preference in a correctness
  document. Softened to MAY, with the real prohibition kept: one releasable MUST NOT be split
  across two groups.
- **Recipe A pointed at the wrong risk.** The comment said to pick a group name no other workflow
  uses. That inverts the cost: a shared group costs wall-clock, while a *split* releasable is the
  original bug. Replaced with a note saying which way to err.
- **Garbled generated comments** in both two-releasables recipes — one read "keyed on the
  RELEASABLE (keyed on the library's tag-prefix)", and a sentence ran across `cancel-in-progress`
  and `queue` as if describing them. Rewritten.
- **Two hygiene defects in the script**: the bash-3.2 editor note sat *inside* the command
  substitution, after a comment it was meant to protect, so an editor adding a line above it would
  never see it — lifted above the substitution; and fd 3 was opened for the annotation but never
  closed, leaking into the `git tag`/`git push` children — now closed after the scan.

Added **PORT1**, a portability row asserting no comment inside the step-1 substitution carries an
apostrophe. Verified it fails when one is injected (and that the other 44 failures it triggers give
no usable diagnostic, which is why the row earns its place).
