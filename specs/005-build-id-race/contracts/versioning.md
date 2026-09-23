# Contract: self-healing reuse after a duplicated build id

Extends the 001, 002 and 004 versioning contracts. Every existing row (B1–B15, P3–P5, BD-default,
S1–S7, X1, T1–T8, TP-default, X2, PJ-*, X3) is unchanged and MUST still pass (zero regression,
SC-003). `MM` = the fixture's `package.json` MAJOR.MINOR (default `0.1`); `PFX` = `client-node-`;
stand-ins P/`""`/`main`, A/`-a`/`aaa`, C/`-c`/`ccc` as in 001.

## The decision, stated once

Step 1 collects every patch number tagged (in this namespace) on a commit carrying **HEAD's tree**.
A collected number `n` is a **usable candidate** iff its *target tag* for this push —
`<PFX>vMM.<n><suffix>` — is one of:

| Target tag state | Usable? | Why |
|---|---|---|
| absent | **yes** | nothing to collide with; this is ordinary reuse |
| points at HEAD's tree | **yes** | we already released it; reuse `n`, then the exists-guard fails loudly (a re-run) |
| points at a **different** tree | **no** | concurrent derivations minted `n` twice; reusing it would wedge |

The **highest usable** candidate wins. An empty usable set falls through to step 2 (`max+1`),
unchanged. A rejected candidate emits a warning annotation and is skipped — no tag is ever deleted,
moved, or force-updated.

## new rows

| Row | Behavior | Setup | Push | Expected |
|---|---|---|---|---|
| R1 | the reported wedge heals | tree A: `vMM.2`; tree B: `vMM.2-a` | P at tree B | `vMM.3` (today: **FAIL**) |
| R1w | the heal is announced | as R1 | P at tree B | stderr contains `::warning` and the number `MM.2` |
| R1t | the heal destroys nothing *while healing* | as R1 | P at tree B | `vMM.2` and `vMM.2-a` still on their original trees, AND the tag set is exactly those two plus the new `vMM.3` — the tag set is asserted because without it the row passes when the derivation fails and writes nothing |
| R2 | a FREE target still reuses (narrow predicate) | tree A: `vMM.2`; tree B: `vMM.2-a` | C at tree B | `vMM.2-c` — **not** `vMM.3` |
| R3 | highest **usable** candidate wins | tree A: `vMM.2`; tree B carries `vMM.1-a` AND `vMM.2-c` | P at tree B | `vMM.1` — not `vMM.3`, not `vMM.2` |
| R4 | the heal is namespace-anchored | tree A: `PFXvMM.2`; tree B: `PFXvMM.2-a` | P at tree B, prefix | `PFXvMM.3` |
| R4' | bare tags do not poison a prefixed candidate | tree A: bare `vMM.2`; tree B: `PFXvMM.2-a` | P at tree B, prefix | `PFXvMM.2` (reuse — the bare namespace is invisible) |

## portability guard

| Row | Behavior | Expected |
|---|---|---|
| PORT1 | no apostrophe in any COMMENT line inside the step-1 command substitution — bash 3.2 (macOS system bash) reads one as an opening quote and the script fails to parse, while a newer bash (Linux CI) does not. Also asserts the scan ANCHOR matched, so reindenting the substitution cannot silently retire the guard | `found\|` |

## regression guards (existing rows, must pass unchanged)

| Row | Why it matters now |
|---|---|
| B7 | target tag on HEAD's **own** tree → still **FAIL**. The heal must not swallow "already released". |
| B8 | resume after promotion, nothing tagged on HEAD → still `vMM.3`. The filter must not disturb the empty-candidate path. |
| B4, B5, B6 | ordinary reuse (one, opposite-direction, three-env) — target tags are absent, so the new condition is a no-op. |
| T4, T4' | the prefixed guard still checks the prefixed tag. |
| S1–S7 | `package-json` cannot reach the heal (it lives in the `build-id` arm). |

## not testable here

The **race** itself — two derivations concurrently reading the tag set before either pushes — is not
reachable from a shell harness. Only its resulting *state* is constructible (`git tag`), and that is
what R1–R4 assert. The concurrency group that prevents the race is verified by inspection
(spec US3), not by a row. Stated so the gap is a known limit rather than an oversight.
