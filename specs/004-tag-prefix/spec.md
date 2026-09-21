# Feature Specification: Tag prefix — two releasables in one repository

**Feature Branch**: `004-tag-prefix`

**Created**: 2026-09-21

**Status**: Draft

**Input**: A repository that holds **two releasables** — a deployed app under `build-id` and a
published library under `package-json` — cannot use the Action for both today: their tags share one
namespace. Both start at `v0.1.0`, so the second to land fails the exists-guard; and the app's
"highest `vMM.*` tag" scan counts the library's tags, corrupting its build numbers. This is the
"tag-collision design question" `snackbyte-base`'s `SUBDIR-LAYOUT.md` flags and leaves open. Close
it with one optional input, `tag-prefix`, that puts a releasable's tags in their own namespace
(`client-node-v0.1.0`) and makes every derivation blind to any other namespace. Default empty —
today's behavior byte for byte. A second input, `package-json` (path, default `./package.json`),
closes the gap found while building it: the Action read `package.json` from the checkout root
only, so a releasable in a subdirectory could not supply its own version (a library under
`package-json` strategy had no way at all). Both defaults are byte-identical to today.

## User Scenarios & Testing *(mandatory)*

The users are **maintainers of a repository with more than one releasable** (the concrete case:
`snackbyte-auth`, with `packages/service/` deployed beside `packages/client-node/` published to npm)
and, unchanged, **every existing consumer** (who never sets the input and must see no difference).

> **Terminology**: a **tag namespace** is the set of tags sharing one prefix — the bare `v…` tags
> (prefix `""`) or `<prefix>v…` tags. Each releasable owns exactly one namespace. The manifest,
> resolve-env, the suffix, and every guard are namespace-independent: the prefix only decides
> *which* tags a derivation can see and *what* it names the one it creates.

### User Story 1 - Existing consumers see no change (Priority: P1)

A consumer that does not set `tag-prefix` gets exactly today's behavior: the same tags, the same
reuse and mint decisions, the same guards.

**Why this priority**: The Action tags live repos (including itself). "Do no harm" outranks the new
capability; the default must be empty and byte-identical.

**Independent Test**: Run the entire existing matrix (B1–B15, P3–P5, BD-default, S1–S7, X1) with
the input absent; every row produces its current tag. Then run one row with the input explicitly
empty and assert it equals the absent-input result.

**Acceptance Scenarios**:

1. **Given** no `tag-prefix` input, **When** any push derives, **Then** the tag and every decision are
   identical to the current behavior.
2. **Given** `tag-prefix: ""` explicitly, **When** a push derives, **Then** the result equals the
   absent-input result (an empty prefix is not a distinct code path).
3. **Given** no `tag-prefix` and a *prefixed* tag present in the repository (a library joined the
   repo), **When** the un-prefixed derivation runs, **Then** it neither reuses nor counts the prefixed
   tag — the un-prefixed namespace is blind to prefixed tags.

### User Story 2 - A second releasable gets its own tag namespace (Priority: P1)

A maintainer sets `tag-prefix: client-node-` on the library's workflow. The Action tags
`client-node-v<version><suffix>`, reads only `client-node-v…` tags when reusing or minting, and
checks the exists-guard against the prefixed tag. The app's bare `v…` tags are invisible to it, and
it is invisible to them.

**Why this priority**: This is the feature's reason to exist — without it the repository cannot hold
a second releasable. Equal-first with US1: the two together are the whole feature (preserve the
un-prefixed namespace; add prefixed ones).

**Independent Test**: In a repo where the bare `v0.1.0` (and higher) already exist, derive with
`tag-prefix: client-node-`; assert `client-node-v0.1.0` — not a collision, not `client-node-v0.1.5`.

**Acceptance Scenarios**:

1. **Given** `tag-prefix: client-node-` and no prefixed tags, **When** a push derives under
   `build-id`, **Then** the tag is `client-node-vMM.0<suffix>` and `version` is `MM.0`.
2. **Given** bare `v0.1.0`, `v0.1.1` on earlier commits and bare `v0.1.4` on HEAD's own tree,
   **When** the prefixed derivation runs, **Then** it mints `client-node-v0.1.0` (it neither reuses
   4 by tree nor mints 5 by max — the bare namespace is invisible to it).
3. **Given** the library's dev commit carries `client-node-v0.1.1-a` (and, on the same tree, the
   app's bare `v0.1.7-a`), **When** main is promoted by a `--no-ff` merge and the prefixed
   derivation runs, **Then** it reuses **1** → `client-node-v0.1.1` (tree-keyed reuse, matched only
   within its namespace).
4. **Given** `tag-prefix: client-node-` and `version-strategy: package-json` with `package.json`
   `1.4.0`, and the bare `v1.4.0` already tagged, **When** a push derives, **Then** the tag is
   `client-node-v1.4.0` — no collision with the bare tag.
5. **Given** `client-node-v1.4.0` already exists, **When** the prefixed `package-json` derivation
   runs, **Then** it FAILS loudly (the "bump `package.json`" guard, in the prefixed namespace).
6. **Given** any prefixed derivation, **When** it succeeds, **Then** the `tag` output carries the
   prefix and the `version` output does not.

### User Story 3 - A releasable in a subdirectory reads its own `package.json` (Priority: P1)

A maintainer whose releasable lives under `packages/<name>/` passes
`package-json: packages/<name>/package.json` beside `manifest:`. The Action reads the version from
that file — `MAJOR.MINOR` under `build-id`, the whole version under `package-json` — instead of
the checkout root's.

**Why this priority**: Without it the two-releasable layout this feature exists for cannot be
wired: a `uses:` step runs at the checkout root regardless of the caller's `working-directory`,
so a subdirectory library under `package-json` strategy would tag and publish the root's version.
`tag-prefix` is necessary but not sufficient; this input completes it.

**Independent Test**: With the root `package.json` at `0.1.0` and `packages/app/package.json` at
`3.4.0`, derive with `package-json: packages/app/package.json`; assert `v3.4.0` (not `v0.1.0`).
Repeat under `package-json` strategy with a prerelease version.

**Acceptance Scenarios**:

1. **Given** no `package-json` input, or `./package.json` explicitly, **When** a push derives under
   either strategy, **Then** the result is identical to today's (the root file is read).
2. **Given** `package-json: packages/app/package.json` at `3.4.0` and a root file at `0.1.0`,
   **When** a push derives under `build-id`, **Then** the tag is `v3.4.0` (the 3.4 line).
3. **Given** `package-json: packages/lib/package.json` at `3.4.0-rc.1`, **When** a push derives
   under `package-json` strategy, **Then** the tag is `v3.4.0-rc.1`.
4. **Given** `manifest:`, `package-json:`, `version-strategy: package-json` and `tag-prefix: lib-`
   all pointed at `packages/lib/`, **When** a push derives, **Then** the tag is `lib-v<lib version>`.
5. **Given** `major-minor` set under `build-id`, **When** a push derives, **Then** the `package-json`
   file is not read (today's behavior) — even if it does not exist.
6. **Given** a `package-json` path that does not exist, **When** it would be read, **Then** the Action
   FAILS loudly naming the input and creates nothing.

### Edge Cases

- **Invalid prefix**: anything other than empty or `[A-Za-z0-9._-]` starting alphanumeric and ending
  in `-` MUST fail loudly before any resolve/guard/tag work — the way an unknown `version-strategy`
  is refused. A prefix without the trailing `-` (`client-node`) is refused so a namespace can never
  be a typo away from a bare `v` tag. A prefix that git itself rejects as a ref-name fragment
  (`a..b-`) is refused by the same gate.
- **Prefix is a prefix of another prefix** (`client-` and `client-node-`): the `v` immediately follows
  the prefix in every match, so `client-v…` never matches `client-node-v…` and vice versa.
- **Two namespaces on one commit**: the app and the library both tagging the same commit at the same
  number (`v0.1.0` + `client-node-v0.1.0`) is the normal first-push state, not a collision.
- **The reuse key is the *repository* tree hash** (Constitution II) — unchanged. A library-only
  change alters the tree for the app too; if the app's workflow ran on that push it would mint a
  fresh (spurious but harmless and still unique) number. Consumers scope each workflow with a
  `paths:` filter so it does not run; documented, not changed here.
- **Shared guards still apply**: shallow refusal, unknown-branch refusal, dup-suffix warning, and
  tag-only behave identically with and without a prefix.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Action MUST accept an optional `tag-prefix` input, default `""`.
- **FR-002**: With the input absent or empty, behavior MUST be byte-for-byte identical to today; the
  existing matrix (B1–B15, P3–P5, BD-default, S1–S7, X1) MUST pass unchanged.
- **FR-003**: With a prefix set, the created tag MUST be `<prefix>v<version><suffix>`; the `tag`
  output MUST carry the prefix and the `version` output MUST NOT.
- **FR-004**: Every read of existing tags that decides reuse or mint (the tree-keyed reuse scan and the
  max-patch scan) MUST match only tags carrying the exact same prefix, anchored, so tags with a
  different prefix and un-prefixed tags are invisible.
- **FR-005**: The un-prefixed derivation MUST be blind to prefixed tags — verified by test, not assumed.
- **FR-006**: The exists-guard MUST check the full prefixed tag.
- **FR-007**: The input MUST be validated before any resolve/guard/tag work: empty, or
  `[A-Za-z0-9._-]` starting alphanumeric and ending in `-`, and a valid git tag-name fragment;
  anything else MUST fail loudly and create nothing.
- **FR-008**: The prefix MUST apply identically under both version strategies; resolve-env, the
  manifest, `is-env`, the suffix, and every shared guard MUST be prefix-independent.
- **FR-009**: The change MUST be covered by acceptance tests: the unchanged matrix (FR-002), prefixed
  mint/reuse/guard rows (FR-003/004/006), the un-prefixed-blind row (FR-005), the invalid-prefix
  guard (FR-007), prefixed `package-json` rows (FR-008), and an `action.yml` wiring/replay row.
- **FR-010**: The Action MUST accept an optional `package-json` input (a path, default
  `./package.json`), resolved from the checkout root exactly as `manifest` is; with the default the
  behavior MUST be byte-identical to today.
- **FR-011**: Every read of the version — `MAJOR.MINOR` under `build-id` (when `major-minor` is
  unset) and the whole version under `package-json` — MUST come from that file; a missing file MUST
  fail loudly naming the input. Under `build-id` with `major-minor` set the file MUST NOT be read.
- **FR-012**: FR-010/011 MUST be covered by tests: the default is byte-identical (both strategies);
  a non-root path is read under both strategies; the missing-file guard; an `action.yml` wiring row.

### Key Entities *(include if feature involves data)*

- **tag-prefix**: an optional namespace label prepended to the tag (`client-node-`). A single input;
  not stored anywhere; the manifest schema is unchanged.
- **Tag namespace**: all tags sharing one prefix. Reuse and mint are computed within a namespace;
  namespaces never see each other.
- **Version tag**: `<prefix>v<version><suffix>`; with prefix `""` this is 001's `v<version><suffix>`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With no input and with an explicit empty prefix, 100% of the existing matrix rows produce
  their current tags — zero regressions.
- **SC-002**: With `tag-prefix: client-node-` and bare `v0.1.*` tags present (including one on HEAD's
  tree), the derivation tags `client-node-v0.1.0` — verified.
- **SC-003**: With prefixed tags present and no prefix set, the derivation tags `v0.1.0` — verified.
- **SC-004**: A prefixed promotion across a merge commit reuses the prefixed number, ignoring a bare tag
  on the same tree — verified.
- **SC-005**: A prefixed existing target tag fails non-zero and creates nothing; the bare tag at the
  same number does not block — verified under both strategies.
- **SC-006**: Each invalid-prefix form fails non-zero and leaves the tag list untouched — verified.
- **SC-007**: The full suite (old + new) runs green in CI on every push.
- **SC-008**: The two-releasable scenario (app at `v0.1.0`, library at `client-node-v0.1.0`, each then
  minting its next number) is exercised by hand against one repository and recorded.
- **SC-009**: With `package-json:` pointed into a subdirectory, the derivation tags that file's
  version under both strategies; with the default, every existing row is unchanged — verified.

## Assumptions

- **Backward compatibility is paramount**: the default is empty; no existing consumer changes.
- **The manifest schema is unchanged**: the prefix is an Action input, not a manifest facet. A
  releasable may point at its own manifest (`manifest:`), as the subdirectory recipe already does.
- **The reuse key stays the repository tree hash** (Constitution II). Scoping it to a subtree is a
  separate design question, not taken here.
- **`package.json` is a path input, like the manifest** — resolved from the checkout root; the
  caller's `working-directory` never reaches a `uses:` step, so the recipe passes the path explicitly.
- **Constitution III is amended** to name the optional namespace prefix (the format within a namespace
  is unchanged), rather than carried as a standing deviation.
