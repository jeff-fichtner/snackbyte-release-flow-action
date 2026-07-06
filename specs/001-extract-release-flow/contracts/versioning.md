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

The ported suite MUST pass all rows (B1–B15) and the add-env proof (SC-001, SC-003, SC-005).
Any intended deviation from a source row is a documented amendment (Principle VII), recorded
in [research.md](../research.md), not a silent change.
