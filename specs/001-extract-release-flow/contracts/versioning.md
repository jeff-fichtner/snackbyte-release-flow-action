# Contract: Version derivation behavior matrix

The pinned acceptance contract for derive-version, ported from
`snackbyte-base/scripts/derive-version.test.sh`. The matrix is sized by **distinct behaviors
of the rule**, not by how many environments an app declares — adding an environment needs no
new row (it runs an existing stand-in's code path).

Stand-in environments used by the fixtures:
- `P` — public face, suffix `""`, branch `main`
- `A` — non-public, suffix `-a`, branch `aaa`
- `C` — non-public, suffix `-c`, branch `ccc`

`MM` = the fixture's `package.json` MAJOR.MINOR (default `0.1`).

| Row | Behavior | Setup | Push | Expected |
|---|---|---|---|---|
| B1  | mint, first ever | no tags | P (`main`) | `vMM.0` |
| B1' | mint, first ever, non-public | no tags | A (`aaa`) | `vMM.0-a` |
| B2  | advance over global max | `vMM.0` exists | P on new commit | `vMM.1` |
| B3  | advance over MIXED suffixes | `vMM.0`, `vMM.1-a` | A on new commit | `vMM.2-a` |
| B4  | reuse on HEAD (promotion, suffix dropped) | commit carries `vMM.2-a` | P on it | `vMM.2` |
| B5  | reuse, opposite direction (resync) | commit carries `vMM.5` | A on it | `vMM.5-a` |
| B6  | N envs on ONE commit share ONE number | commit carries `vMM.4` | A then C on it | `vMM.4-a`, `vMM.4-c` |
| B7  | collision guard (target exists on HEAD) | HEAD carries `vMM.2` and `vMM.2-a` | P | **FAIL**, no tag |
| B8  | resume after promotion (no jam) | prior commit carries `vMM.2`+`vMM.2-a` | P on NEW untagged commit | `vMM.3` |
| B9  | hotfix gap (skip consumed numbers) | `vMM.5..8` consumed | A on new commit | `vMM.9-a` |
| B10 | diverged merge → fresh number | two diverged tagged sides, 2-parent merge keeping both | P on merge | `vMM.7` |
| B11 | unknown branch (not in manifest) | any | `feature-x` | **FAIL**, no tag |
| B12 | shallow refusal | shallow clone hides tags | P | **FAIL**, no tag |
| B13 | single-env self-increment | manifest has only P | P, then P on new commit | `vMM.0`, then `vMM.1` |
| B14 | promotion across MERGE commit reuses number | dev tagged `vMM.1-a` on own commit; `--no-ff` merge carries dev's tree | P on merge | `vMM.1` |
| B15 | promotion across SQUASH reuses number | same intent via `merge --squash` (new commit, dev's tree) | P on squash | `vMM.1` |

Plus the **one-row-edit proof** (`add-env.test.sh`): adding a `qa` row to the manifest
(a) touches only `environments.json`, (b) derives `vMM.0-qa` for the `qa` branch, and
(c) resolve-env recognizes `qa` and rejects a non-environment branch.

## Extraction-delta rows (behaviors 001 adds over the source)

The rows above verify the *unchanged algorithm*. These verify the *new* behaviors this
feature introduces (the parameterization surface) — the only place a port defect can live.
Behavior-complete, not enumerative: one row per distinct new behavior.

| Row | Behavior | Setup | Invocation | Expected |
|---|---|---|---|---|
| P1 | resolve-env standalone — is an environment | default manifest | check `main` | `is-env=true` |
| P2 | resolve-env standalone — not an environment | default manifest | check `feature-x` | `is-env=false` |
| P3 | manifest at a NON-default path derives identically | manifest at `config/envs.json`, no tags | derive P, `manifest=config/envs.json` | `vMM.0` (identical to B1) |
| P4 | `major-minor` override drives the version line | override `major-minor=2.7`, no tags | derive P | `v2.7.0` |
| P5 | default `major-minor` reads the declared version | no override, declared version `MM.x`, no tags | derive P | `vMM.0` |
| I1 | Action interface end-to-end — env push | fixture manifest + version | invoke the Action for an env branch | outputs `is-env=true`, `version=MM.0`, `tag=vMM.0<suffix>` matching derivation |
| I2 | Action interface end-to-end — non-env push | fixture manifest | invoke the Action for a non-env branch | output `is-env=false`; `version`/`tag` unset; no tag created |

## CI gate

The full suite (algorithm rows B1–B15 + one-row-edit proof + extraction-delta rows P1–P5,
I1–I2) MUST run green in continuous integration on every push — `FAIL=0`, exit zero. A red
suite blocks. This mirrors the source project's quality-gate principle that the test script
MUST run successfully on a fresh copy.

## Invariants (must hold for every row)

- **INV-1 (tag-only)**: a successful run adds exactly one tag, zero commits, zero branch
  updates.
- **INV-2 (tree reuse key)**: reuse is decided by `HEAD^{tree}` vs each tag's `^{tree}`;
  never by commit SHA.
- **INV-3 (global monotonic PATCH)**: advance is `max(PATCH over ALL vMM.* tags, every
  suffix) + 1`; two distinct commits can never share a PATCH; gaps are correct.
- **INV-4 (fixed format)**: every produced tag matches `^vMM\.[0-9]+(-[A-Za-z0-9._-]+)?$`.
- **INV-5 (fail-loud)**: existing-target-tag, shallow, and unknown-branch each exit non-zero
  and create nothing.
- **INV-6 (dup-suffix warns, never fails)**: duplicate `tagSuffix` emits a warning and
  proceeds.

## Acceptance

The suite MUST pass all algorithm rows (B1–B15) and the add-env proof (SC-001, SC-003,
SC-005), the extraction-delta rows P1–P5 and I1–I2 (SC-002, SC-006, SC-007), and MUST run
green in CI on every push (SC-008). Any intended deviation from a source row is a documented
amendment (Principle VII), recorded in [research.md](../research.md), not a silent change.
