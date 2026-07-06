# Feature Specification: Pluggable version strategy (build-id | package-json)

**Feature Branch**: `002-version-strategy`

**Created**: 2026-07-06

**Status**: Draft

**Input**: The Action's derive-version currently only produces a global monotonic build-id PATCH
(tree-reused) — the right model for deploy-per-branch **apps** (snackbyte-base). **Libraries**
(snackbyte-npm-base) need intentional SemVer instead: the published version is a human promise
about compatibility, chosen in `package.json`, not a build counter. Add a `version-strategy` input
so one Action serves both: `build-id` (today's behavior, the default) and `package-json` (tag the
`package.json` SemVer as-is). resolve-env, the manifest, tag-only, and all guards are shared; only
the version-derivation rule is pluggable.

## User Scenarios & Testing *(mandatory)*

The users are **maintainers of application repos** (who keep today's build-id behavior unchanged)
and **maintainers of library/npm repos** (who need the version to come from `package.json` so their
CI-on-tag publish releases an intentional SemVer). Both consume the same Action; the strategy input
selects the version rule.

> **Terminology**: a release **channel** is simply an `environments.json` row (the same entity 001
> calls an *environment*). For an app it maps to a deploy target; for a library it maps to an npm
> dist-tag (e.g. `latest`, `next`). No schema change — "channel" is the library-facing word for the
> exact same manifest row, resolved by the same resolve-env logic.

### User Story 1 - App consumer keeps build-id behavior unchanged (Priority: P1)

An existing app consumer (or snackbyte-base-style repo) references the Action with no new input and
gets exactly today's behavior: the tree-reused, global-monotonic build-id PATCH.

**Why this priority**: Backward compatibility is non-negotiable — the Action already tags real
repos (this one self-versions with it). A regression here breaks live consumers. It is P1 because
"do no harm to what works" outranks the new capability.

**Independent Test**: Run the full existing derivation matrix (B1–B15) with the strategy input
absent and with it explicitly `build-id`; every row produces the identical tag it does today.

**Acceptance Scenarios**:

1. **Given** a repo and no `version-strategy` input, **When** a push derives a version, **Then** the
   result is identical to the current build-id behavior (default is `build-id`).
2. **Given** `version-strategy: build-id` explicitly, **When** a push derives a version, **Then** the
   result matches the default — the explicit value is a no-op alias for today's behavior.

### User Story 2 - Library consumer tags the package.json SemVer (Priority: P1)

A library maintainer sets `version-strategy: package-json`. On a push to a release-channel branch,
the Action tags `v{package.json version}{tagSuffix}` — the intentional SemVer the maintainer chose —
and does NOT derive a build-id. The created tag is the trigger their publish workflow keys off.

**Why this priority**: This is the feature's reason to exist — without it a library cannot consume
the Action without publishing a meaningless build-counter PATCH (the "SemVer lie"). Equal-first with
US1: the two together are the whole feature (preserve apps, enable libs).

**Independent Test**: In a repo whose `package.json` is `1.4.0`, push to a channel branch with
`version-strategy: package-json`; assert the tag is exactly `v1.4.0` (or `v1.4.0<suffix>` on a
suffixed channel), with no build-id derivation involved.

**Acceptance Scenarios**:

1. **Given** `package.json` version `1.4.0` and `version-strategy: package-json` on the default
   channel (empty suffix), **When** a push derives, **Then** the tag is `v1.4.0`.
2. **Given** the same on a channel with suffix `-next`, **When** a push derives, **Then** the tag is
   `v1.4.0-next`.
3. **Given** `version-strategy: package-json` and the target tag `v1.4.0` already exists, **When** a
   push derives, **Then** it FAILS loudly and creates nothing — this is the "you must bump
   `package.json` before releasing again" discipline (the collision guard, reused).
4. **Given** `version-strategy: package-json`, **When** the pushed branch is not a channel in the
   manifest, **Then** it is rejected/short-circuited exactly as build-id does (resolve-env is shared).

### Edge Cases

- **Invalid `version-strategy` value**: an unrecognized strategy MUST fail loudly (not silently fall
  back to a default), so a typo can't ship the wrong versioning.
- **`package-json` strategy + `major-minor` input**: `major-minor` is a build-id concept (it supplies
  MAJOR.MINOR for the derived PATCH). Under `package-json` the whole version comes from
  `package.json`, so `major-minor` MUST be ignored (documented), not silently combined.
- **`package.json` version is a prerelease already** (e.g. `1.4.0-rc.1`): the tag is
  `v1.4.0-rc.1<suffix>` — the strategy tags what `package.json` says verbatim; it does not parse or
  re-compose the SemVer.
- **Shared guards still apply**: shallow-clone refusal, unknown-branch refusal, dup-suffix warning,
  and tag-only all behave identically regardless of strategy.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Action MUST accept a `version-strategy` input with values `build-id` and
  `package-json`, defaulting to `build-id`.
- **FR-002**: With `build-id` (or the default), version derivation MUST be byte-for-byte identical to
  the current behavior (tree-reused global-monotonic PATCH); the existing matrix B1–B15 MUST pass
  unchanged.
- **FR-003**: With `package-json`, the derived tag MUST be `v{package.json version}{tagSuffix}`, where
  the version is taken verbatim from the manifest-resolved channel's `package.json` and the suffix is
  the channel's `tagSuffix`. No build-id derivation, no tree reuse, no max+1 occurs.
- **FR-004**: All shared behavior MUST be strategy-independent: resolve-env / channel resolution,
  tag-only (never a commit or branch push), shallow-clone refusal, unknown-branch refusal,
  duplicate-suffix warning, existing-target-tag refusal, and the git-identity fallback.
- **FR-005**: Under `package-json`, an existing target tag MUST fail loudly (serving as the
  "bump `package.json` before re-releasing" guard); the Action MUST NOT overwrite or reuse it.
- **FR-006**: An unrecognized `version-strategy` value MUST fail loudly and create nothing.
- **FR-007**: Under `package-json`, the `major-minor` input MUST be ignored (it is a build-id
  concept); this MUST be documented in the I/O contract.
- **FR-008**: The change MUST be covered by acceptance tests: the unchanged build-id matrix (proving
  FR-002), new `package-json` rows (FR-003/005), the invalid-strategy guard (FR-006), and the
  strategy-independence of resolve-env + guards (FR-004).

### Key Entities *(include if feature involves data)*

- **version-strategy**: The policy selecting how the version number is chosen — `build-id` (derive a
  monotonic build counter) or `package-json` (use the declared SemVer verbatim). A single input; not
  stored anywhere.
- **Release channel (manifest row)**: Unchanged from 001 — the same `environments.json` row. For a
  library the mental model is an npm dist-tag / channel (`latest`, `next`) rather than a deploy
  environment, but the schema and resolve-env logic are identical.
- **Version tag**: `v{version}{suffix}`. Under `build-id`, `version = MM.P` (derived). Under
  `package-json`, `version` = the `package.json` version verbatim.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With no strategy input and with `build-id`, 100% of the existing B1–B15 matrix rows
  produce their current tags — zero regressions.
- **SC-002**: With `package-json` and `package.json` = `1.4.0`, a push to the default channel tags
  exactly `v1.4.0`, and to a `-next` channel tags `v1.4.0-next` — verified by acceptance rows.
- **SC-003**: With `package-json`, re-deriving when `v1.4.0` already exists fails non-zero and creates
  no tag — verified.
- **SC-004**: An invalid `version-strategy` value fails non-zero and creates no tag — verified.
- **SC-005**: resolve-env, tag-only, and every guard behave identically under both strategies —
  verified by running the shared checks under each.
- **SC-006**: The full suite (old + new) runs green in CI on every push.

## Assumptions

- **Backward compatibility is paramount**: `build-id` stays the default so existing consumers and
  this repo's own self-versioning are unaffected. (This repo currently tags itself via `build-id`;
  it MAY later switch its own workflow, but that is not required by this feature.)
- **The manifest schema is unchanged**: a library reuses `environments.json` as-is; naming a facet
  `npmTag` or similar is a consumer convention, out of scope here. This feature adds no manifest field.
- **`package-json` tags verbatim**: the strategy does not parse, validate, or re-compose SemVer — it
  trusts `package.json`. Enforcing SemVer shape is the consumer's / a later feature's concern.
- **Publishing is downstream**: turning a tag into an `npm publish` is the consumer's workflow, not
  this Action (Constitution VI: the Action tags; it does not publish). Consumer wiring is documented
  separately (CONSUMING.md), not built here.
- **Extraction discipline (Constitution VII) still applies to `build-id`**: the existing algorithm is
  not rewritten; the strategy branch wraps it, leaving its code path intact.
