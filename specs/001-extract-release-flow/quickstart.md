# Quickstart / Validation Guide

How to prove this feature works end-to-end. Implementation details live in `tasks.md`;
this is the run/validate guide.

## Prerequisites

- `bash`, `git`, `node` on PATH (all present on GitHub-hosted runners and standard dev machines).
- This repo checked out with full history (the test harness builds its own throwaway repos, so
  it does not depend on this repo's own tags).

## Validate the derivation behavior (local, no network)

The acceptance suite builds throwaway git repos with a local bare "origin" and drives every
distinct behavior, asserting the exact tag produced.

```bash
# from repo root
bash scripts/derive-version.test.sh
# or, once package.json wires it:
npm run test:release
```

**Expected**: every row B1–B15 prints `ok`, then the chained add-env proof prints its `ok`
lines, and the run ends `PASS=<n> FAIL=0` with a zero exit code. Maps to SC-001, SC-003,
SC-005 and the versioning contract ([contracts/versioning.md](./contracts/versioning.md)).

Override the pretend MAJOR.MINOR the fixtures use:

```bash
PKG_MM=1.4 bash scripts/derive-version.test.sh   # asserts against v1.4.* tags
```

## Validate resolve-env in isolation

```bash
# true for a declared environment branch, false otherwise
bash scripts/resolve-env.sh main        # -> is-env=true   (with the default manifest)
bash scripts/resolve-env.sh feature-x   # -> is-env=false
```

**Expected**: exit status / printed `is-env` reflects manifest membership (SC-002).

## Validate the parameterization surface (extraction deltas)

The behaviors this feature adds over the source — the only place a port defect can hide — are
covered by dedicated rows (P1–P5, I1–I2 in [contracts/versioning.md](./contracts/versioning.md)):

```bash
bash scripts/resolve-env.test.sh    # P1-P2: standalone true/false
# P3-P5 (non-default manifest path, major-minor override/default) run inside:
bash scripts/derive-version.test.sh
```

**Expected**: `FAIL=0`. Maps to SC-002 and SC-007.

## Validate the composite Action end-to-end (required, not optional)

```bash
bash scripts/action.test.sh         # I1-I2: invoke action.yml, assert is-env/version/tag
```

Invokes the Action itself against a fixture manifest and asserts the `is-env`/`version`/`tag`
outputs match the derivation — so a correct algorithm wired to a broken `action.yml` cannot
pass. Maps to SC-006. A true cross-repo consumer invocation is the stronger confirmation; the
same-repo invocation is the enforced gate.

## The whole suite must be green in CI

`.github/workflows/test.yml` runs the full suite (algorithm + extraction-delta + Action
interface) on every push. A red suite blocks (SC-008) — "tests pass" is enforced, not local-only.

## Validate the one-row-edit promise directly

```bash
bash scripts/add-env.test.sh
```

**Expected**: `ok add-env touched only environments.json`, `ok qa derives vMM.0-qa`,
`ok resolve-env recognizes qa`, `ok resolve-env rejects non-env branch`;
`add-env verification: FAIL=0` (SC-003).

## Definition of done for the feature

- All rows in [contracts/versioning.md](./contracts/versioning.md) pass — algorithm B1–B15,
  extraction-delta P1–P5 / I1–I2, and the add-env proof (`FAIL=0`).
- `action.yml` exposes `is-env`, `version`, `tag` per [contracts/action-io.md](./contracts/action-io.md),
  verified by an end-to-end Action invocation (I1–I2), not scripts-in-isolation alone.
- A successful derive adds exactly one tag and zero commits/branches (INV-1).
- Each fail-loud path exits non-zero and creates nothing (INV-5).
- The full suite runs green in CI on every push (SC-008); a red suite blocks.
