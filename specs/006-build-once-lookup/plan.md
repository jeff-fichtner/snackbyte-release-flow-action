# Implementation Plan: Build once — a read-only lookup before the checks

**Branch**: `006-build-once-lookup` | **Date**: 2026-11-11 | **Spec**: [spec.md](./spec.md) | **Request**: snackbyte-ops #75e3f7

## Summary

One new input and one new output, both additive.

1. **`derive-version.sh`** reads `MODE` (`tag` default | `lookup`), validated first with the other
   inputs. The whole derivation runs unchanged in both modes, through the exists-guard. Only after
   the guard does `lookup` stop: it writes the outputs and creates nothing. No git identity is set,
   no tag is made, nothing is pushed.
2. **`released-as`**: the reuse scan already finds the reused number. After it, when step 1 chose
   a number (not step 2's max+1), the script lists this namespace's tags carrying that number on
   HEAD's tree and takes the first by name. It is written in both modes. Under `package-json` it is
   empty.
3. **`action.yml`** gains the `mode` input (mapped to `MODE` on the derive step) and the
   `released-as` output (from the derive step).
4. **Recipes**: the build-once pattern in `CONSUMING.md` lands after PR #10 merges (FR-009).

## Technical Context

**Language/Version**: Bash + Node (unchanged). No new runtime, no new dependency.

**Primary Dependencies**: `git`, `node`, POSIX tools; GitHub Actions runner. Unchanged.

**Testing**: New L-series rows in `derive-version.test.sh` (lookup reports what tag would make,
creates nothing, agrees with tag mode, fails where tag mode fails, released-as rules, prefix,
package-json, no identity, bad mode), and I4 in `action.test.sh` (wiring of `mode` and
`released-as`; a replayed look-up then tag). The full existing matrix must pass unedited (FR-008).
Run via `npm run test:release` and the PR gate.

**Target Platform**: GitHub Actions runners + local. Unchanged.

**Project Type**: Composite GitHub Action (unchanged layout).

**Performance**: one extra `git tag -l` + per-tag `rev-parse` over the reused number only, and only
on a reuse. Negligible.

**Constraints**: Tag-only, create-only. `mode` unset = today's behavior byte for byte.

## Constitution Check

| Principle | Status |
|---|---|
| I. Tag only, never a commit | Upheld — `lookup` creates nothing; `tag` unchanged. |
| II. Tree hash is the reuse key | Upheld — `released-as` is read from the same tree-keyed reuse; no new key. |
| III. Fixed, derived tag format | Upheld — `released-as` is an existing tag; the format is untouched. |
| IV. One-row edit | Upheld — no manifest change. |
| V. Fail loud | Upheld and extended — `lookup` refuses in every case `tag` refuses (same code path, up to the guard); a bad `mode` is refused before any work. |
| VI. Distributed as an Action | Upheld — no package surface. |
| VII. Extract by parameterization | Upheld — the derivation algorithm is unchanged; the mode only decides whether its result is applied. The constitution's I/O summary gains `mode` and `released-as` (PATCH amendment, wording only). |

Post-design re-check: no violations.

## Project Structure

```
action.yml                          # + input mode, + output released-as
scripts/derive-version.sh           # + MODE validation, + released-as, + lookup stop after the guard
scripts/derive-version.test.sh      # + L-series rows
scripts/action.test.sh              # + I4 wiring and replay
.specify/memory/constitution.md     # I/O summary: + mode, + released-as (PATCH)
README.md, CONSUMING.md, CLAUDE.md  # interface reference; build-once recipe after PR #10
```

## Phases

- Phase 0: [research.md](./research.md) — the decisions and what was passed over.
- Phase 1: [contracts/interface.md](./contracts/interface.md), [quickstart.md](./quickstart.md).
  The data model is two values (mode, released-as), defined in the contract; no separate file.
