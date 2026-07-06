# Contract: version-strategy behavior

Extends the 001 versioning contract. The `build-id` rows (B1–B15) are unchanged and MUST still pass
(zero regression, FR-002). The rows below verify the new `package-json` strategy and the
invalid-strategy guard. `PKG` = the fixture's `package.json` version.

Stand-in channels (same manifest shape as 001): `P` suffix `""` on `main`; `A` suffix `-a` on `aaa`.

## build-id (default / explicit) — unchanged

| Row | Behavior | Expected |
|---|---|---|
| B1–B15 | the entire existing matrix | unchanged; run under no-input AND under `VERSION_STRATEGY=build-id` |
| BD-default | no strategy input defaults to build-id | `derive main` (no strategy) == `derive main VERSION_STRATEGY=build-id` |

## package-json (new)

`version-strategy: package-json` → tag = `v{package.json version}{tagSuffix}`, verbatim; no reuse, no
max+1.

| Row | Behavior | Setup | Push | Expected |
|---|---|---|---|---|
| S1 | tag the declared SemVer, default channel | pkg `1.4.0`, no tags | P (`main`), strategy=package-json | `v1.4.0` |
| S2 | tag the declared SemVer, suffixed channel | pkg `1.4.0` | A (`aaa`), strategy=package-json | `v1.4.0-a` |
| S3 | NO build-id derivation (ignores existing tags) | pkg `2.0.0`, tags `v1.4.0`,`v1.4.9` exist | P, strategy=package-json | `v2.0.0` (not `v1.4.10`) |
| S4 | collision = "bump package.json" guard | pkg `1.4.0`, tag `v1.4.0` already exists | P, strategy=package-json | **FAIL**, no tag |
| S5 | prerelease version tagged verbatim | pkg `1.4.0-rc.1` | P, strategy=package-json | `v1.4.0-rc.1` |
| S6 | `major-minor` input ignored under package-json | pkg `1.4.0`, MAJOR_MINOR=9.9 set | P, strategy=package-json | `v1.4.0` (not `v9.9.*`) |
| S7 | unknown branch still refused (shared resolve) | pkg `1.4.0` | `feature-x`, strategy=package-json | **FAIL**, no tag |

## invalid strategy

| Row | Behavior | Push | Expected |
|---|---|---|---|
| X1 | unrecognized strategy fails loud | P, strategy=`bogus` | **FAIL**, no tag, non-zero exit |

## Shared invariants (hold under BOTH strategies)

- **INV-1 (tag-only)**: exactly one tag, zero commits, zero branch updates.
- **INV-strategy-independence**: resolve-env answer, shallow refusal, unknown-branch refusal,
  dup-suffix warning, existing-tag refusal, and the git-identity fallback behave identically whether
  strategy is `build-id` or `package-json`.
- **INV-format**: every produced tag matches `^v<version>(-[A-Za-z0-9._-]+)?$` (build-id: version is
  `MM.P`; package-json: version is the declared string, which may itself contain a prerelease `-`).

## Acceptance

All build-id rows (B1–B15 + BD-default) pass unchanged (SC-001); package-json rows S1–S7 pass
(SC-002/003, FR-003/005/007); invalid-strategy X1 passes (SC-004, FR-006); strategy-independence
verified (SC-005). Full suite green in CI (SC-006).
