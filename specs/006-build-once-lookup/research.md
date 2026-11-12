# Research: Build once — a read-only lookup before the checks

## R1 — Where the look-up comes from

- **Decision**: a `mode` input on the same Action (`tag` | `lookup`), running the same script.
- **Rationale**: Jeff's ruling (2026-11-11): look up early, tag at the end, same job. One code path
  means the look-up cannot drift from what tagging will do; it is the same derivation stopped before
  it writes.
- **Passed over**: tag first and check after (a tag could exist before checks pass); each consumer
  computing reuse in its own YAML (the logic copied into ~16 repos); a second Action in this repo
  (two `uses:` paths to pin and keep in step, for no gain).

## R2 — Where lookup stops

- **Decision**: after the exists-guard, before the identity fallback and `git tag`.
- **Rationale**: every refusal tag mode can make before tagging then applies to lookup, so the job
  fails before spending its checks (FR-006). Nothing after the guard can fail without writing.

## R3 — What `released-as` holds

- **Decision**: one existing tag in this namespace carrying the reused number on HEAD's tree, the
  first by name; empty when the number was minted, and always under `package-json`.
- **Rationale**: a promotion needs one handle to find staging's build. Several environments may
  already carry the number on the tree; picking the first by name is deterministic and any of them
  names the same build.
- **Passed over**: a `reused: true|false` flag (a consumer would still have to work out which tag);
  a list of every such tag (awkward in step outputs, and no consumer needs more than one).

## R4 — Output name

- **Decision**: `released-as`.
- **Rationale**: it reads as the fact it reports ("this tree was released as v1.4.7-dev") and stays
  true in tag mode, where the number has just been stamped again.
