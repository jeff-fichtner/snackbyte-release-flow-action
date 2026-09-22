# Implementation Plan: Build-id race — per-releasable serialization and a self-healing reuse

**Branch**: `005-build-id-race` | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md) | **Issue**: #3

## Summary

Three changes, in dependency order.

1. **Constitution** — the max-over-suffixes invariant gains its precondition (it holds across
   *serialized* derivations; the scan and the tag push are not atomic), and the serialization guard
   moves from "same branch" to "per releasable / one group per tag namespace". Everything else in
   this plan is downstream of these two lines, which is why they go first.

2. **`derive-version.sh`** — step 1's candidate filter gains one condition. A candidate number `n`
   found on HEAD's tree is usable only if this environment's target tag `<prefix>vMM.<n><suffix>` is
   absent or already points at HEAD's tree. A target owned by a *different* tree means concurrent
   derivations minted `n` twice; the candidate is skipped with a `::warning` annotation and the scan
   continues, so the **highest still-usable** candidate wins. An empty usable set falls through to
   the untouched step 2 (`max+1`). No new branch, no new fall-through path, and the exists-guard at
   the bottom is unchanged — a target tag on HEAD's *own* tree still reaches it and still fails.

3. **Concurrency** — all four `CONSUMING.md` recipes and this repo's `release.yml` key the group on
   the releasable rather than `github.ref_name`, and add `queue: max`. Without `queue: max` the
   wider group is a regression: GitHub holds only **one** pending run per group and cancels the
   pending one when a newer run queues, so collapsing `main` and `dev` into one group would trade
   the wedge for a silently dropped release.

Then the five downstream restatements of the invariant, the test rows, and the version bump.

## Technical Context

**Language/Version**: Bash + Node (unchanged). No new runtime, no new dependency.

**Primary Dependencies**: `git`, `node`, POSIX tools; GitHub Actions runner. Unchanged. The heal
uses `git rev-parse <tag>^{tree}` — already used by the same loop.

**Testing**: Extend `derive-version.test.sh` with the R-series (R1 heal, R2 narrow predicate, R3
highest-usable, R4 prefixed heal) plus a `derive_err` helper so a row can assert the warning
annotation, which `derive` currently swallows via `2>/dev/null`. B7 and B8 are the regression guards
and must pass **unchanged**. Run via `npm run test:release` and the CI gate.

**Target Platform**: GitHub Actions runners + local. Unchanged.

**Project Type**: Composite GitHub Action (unchanged layout).

**Performance**: one extra `git rev-parse` per reuse candidate. Candidates are only tags already
pointing at HEAD's tree — typically zero or one. Negligible.

**Constraints**: Tag-only, create-only (Constitution). The default path (no race in the tag set) must
remain byte-identical in effect to today's.

## Constitution Check

| Principle | Status |
|---|---|
| Tag format fixed | Unchanged — the heal picks a *number*, never a format. |
| Tree-hash reuse key | Unchanged — the reuse key is still the tree; the heal only rejects candidates whose target is owned elsewhere. |
| Tag only, never a commit | Unchanged — nothing is deleted, moved, or force-pushed (FR-005). |
| Fail loud | **Narrowed deliberately.** The already-released guard is untouched (FR-004); only the *unrecoverable* duplicate-number state changes from fail to warn-and-renumber. The warning is an Actions annotation, not just stderr, so the healed race stays visible on a green run (FR-003). |
| One-row-edit manifest | Unchanged — no manifest schema change. |
| Namespace blindness | Preserved — the heal is prefix-anchored in both directions (FR-006). |

**Amendment**: this feature *changes* the constitution (FR-009). Lines 92 and 123 assert an
unconditional invariant and a per-branch guard; production falsified both. Amending them is task 1,
before any code, so the rest of the work is checked against a true rule.

## Project Structure

```
.specify/memory/constitution.md      # amended: invariant precondition + per-releasable guard
scripts/derive-version.sh            # step-1 candidate filter + annotation; header comment
scripts/derive-version.test.sh       # derive_err helper; rows R1–R4
CONSUMING.md                         # 4 recipes' concurrency blocks; the "structurally impossible" line
README.md                            # the invariant restatement + "same-branch run serialization"
.github/workflows/release.yml        # this repo's own group — identical to recipe A
package.json                         # 1.1.0 -> 1.2.0
```

No new files outside `specs/005-build-id-race/`.

## Complexity Tracking

| Decision | Simpler alternative rejected | Why |
|---|---|---|
| Predicate = *target tag* owned by another tree | *Any* tag bearing the number (as issue #3 hedged) | The broad form fires when the target is free, splitting one tree across two build ids in a 3-environment repo — manufacturing the inconsistency the feature removes (spec US2). |
| Check folded into the candidate filter | Check the winner, then bail to `max+1` | Folding it in needs no new branch and naturally yields the highest *usable* candidate instead of burning a fresh number (FR-002). |
| `::warning` annotation | plain stderr | stderr is invisible on a green run. The heal makes the race survivable and therefore easy to stop noticing; the annotation is what keeps it observable (FR-003). |
| `queue: max` | the group change alone | One pending run per group — a newer queued run cancels the pending one. Without `queue: max` the fix silently drops releases. |

## Rollout

The heal reaches every existing consumer through the floating `@v1` with no workflow edit; the
concurrency fix reaches a consumer only when that consumer's workflow is edited. That asymmetry is
intentional and is why both halves ship: the heal repairs the installed base now, the group stops
the race for anyone who updates.

Release: `1.1.0` → **`1.2.0`** (a derivation behavior change visible to consumers, so a minor, not a
patch). Under `build-id` bumping MAJOR.MINOR restarts the patch scan on the `1.2` line, which is the
honest signal that derivation changed. After the tag lands, re-point the floating `v1` — nothing in
`release.yml` moves it; it is maintained by hand.

This repo's `release.yml` uses `uses: ./`, not `@v1`, so the heal is live here one step before
consumers see it — which makes this repo the end-to-end exercise of the healed path.
