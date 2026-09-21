# Contract: tag-prefix behavior

Extends the 001 and 002 versioning contracts. Every existing row (B1–B15, P3–P5, BD-default,
S1–S7, X1) is unchanged and MUST still pass with the prefix absent (zero regression, FR-002). The
rows below verify the prefixed namespace and the invalid-prefix guard. `PFX` = `client-node-`;
`MM` = the fixture's `package.json` MAJOR.MINOR (default `0.1`); stand-ins P/`""`/`main` and
A/`-a`/`aaa` as in 001.

## un-prefixed (default / explicit empty) — unchanged

| Row | Behavior | Expected |
|---|---|---|
| B1–B15, P3–P5, BD-default, S1–S7, X1 | the entire existing matrix, prefix absent | unchanged |
| TP-default | explicit empty prefix equals absent | `derive main` == `derive main TAG_PREFIX=` |

## prefixed namespace (new)

| Row | Behavior | Setup | Push | Expected |
|---|---|---|---|---|
| T1 | prefixed mint, first ever | no tags | P, prefix | `PFXvMM.0` |
| T1' | prefixed mint, suffixed env | no tags | A, prefix | `PFXvMM.0-a` |
| T2 | prefixed derivation BLIND to bare tags (reuse and mint) | bare `vMM.0`, `vMM.1` on earlier commits; bare `vMM.4` on HEAD's tree | P, prefix | `PFXvMM.0` (not 4 by reuse, not 5 by max; no collision with bare `vMM.0`) |
| T3 | un-prefixed derivation BLIND to prefixed tags | `PFXvMM.9` earlier; `PFXvMM.4` on HEAD's tree; no bare tags | P, no prefix | `vMM.0` |
| T3' | max is per-namespace | bare `vMM.2`; `PFXvMM.9` | P on new commit, no prefix | `vMM.3` |
| T4 | prefixed collision guard (B7 in the namespace) | HEAD carries `PFXvMM.2-a` and `PFXvMM.2` | P, prefix | **FAIL**, no tag |
| T4' | guard checks the PREFIXED tag, not the bare one | HEAD carries bare `vMM.2-a` and `vMM.2` (B7's state) | P, prefix | `PFXvMM.0` |
| T5 | prefixed promotion across MERGE reuses the prefixed number (B14 in the namespace) | base `PFXvMM.0`; dev commit carries `PFXvMM.1-a` AND bare `vMM.7-a` (decoy, same tree); `--no-ff` merge | P on merge, prefix | `PFXvMM.1` |
| T6 | prefixed package-json, bare tag at the same version present | pkg `1.4.0`; bare `v1.4.0` exists | P, prefix, strategy=package-json | `PFXv1.4.0` |
| T7 | prefixed package-json collision | pkg `1.4.0`; `PFXv1.4.0` exists | P, prefix, strategy=package-json | **FAIL**, no tag |
| T8 | outputs: `tag` carries the prefix, `version` does not | no tags | P, prefix | `version=MM.0`, `tag=PFXvMM.0` |

## invalid prefix

| Row | Prefix | Expected |
|---|---|---|
| X2a | `client-node` (no trailing `-`) | **FAIL**, non-zero |
| X2b | `bad prefix-` (illegal character) | **FAIL**, non-zero |
| X2c | `-` (leading dash) | **FAIL**, non-zero |
| X2d | `a..b-` (git ref rule) | **FAIL**, non-zero |
| X2n | after all four | tag list unchanged (nothing created) |

## action.yml wiring (action.test.sh)

| Row | Behavior | Expected |
|---|---|---|
| wire | `inputs.tag-prefix` mapped to the derive step as `TAG_PREFIX`; default `""` | both facts true |
| I3 | env push replayed with `tag-prefix: client-node-` | `is-env=true`, `version=0.1.0`, `tag=client-node-v0.1.0` |

## Namespace invariants (hold for every row)

- **INV-ns-1 (blindness)**: a derivation with prefix *p* reads only tags matching `^p v…` anchored;
  tags with any other prefix, including `""`, are invisible to reuse, mint, and (as a different
  name) to the exists-guard.
- **INV-ns-2 (symmetry)**: the `""` namespace is blind to every prefixed namespace.
- **INV-ns-3 (format)**: every produced tag matches `^<prefix>vMM\.[0-9]+(-[A-Za-z0-9._-]+)?$`
  (build-id) or `^<prefix>v<version>(-…)?$` (package-json); with prefix `""` these are 001/002's
  INV-4 / INV-format unchanged.
- **INV-ns-4 (version output)**: `version` never contains the prefix.
- **INV-1, INV-2, INV-5, INV-6** (tag-only, tree reuse key, fail-loud, dup-suffix warns) hold
  unchanged in every namespace.

## By-hand scenario (SC-008)

One throwaway repository; the app's derive (`build-id`, no prefix, root manifest) and the library's
derive (`package-json`, `client-node-`, its own manifest) run as two "workflows":

1. First push to `main`: app → `v0.1.0`; library → `client-node-v0.1.0` (same commit, no collision).
2. App change on `dev`: app → `v0.1.1-dev`.
3. Fast-forward `dev`→`main`: app → `v0.1.1` (reuse); library re-run → FAIL on its own guard.
4. Library bump to `0.1.1` on `main`: library → `client-node-v0.1.1`.
5. App run on that library-only commit (no `paths:` filter): app → `v0.1.2` (fresh tree — the
   documented repository-tree trade-off).
6. Re-run either unchanged: each FAILS on its own guard, never the other's.

Final namespace: `client-node-v0.1.0 client-node-v0.1.1 v0.1.0 v0.1.1 v0.1.1-dev v0.1.2`.

## Acceptance

All existing rows pass unchanged (SC-001); T1–T8 pass (SC-002/003/004/005); X2 passes (SC-006);
wiring + I3 pass; full suite green in CI (SC-007); the by-hand scenario recorded (SC-008).
