# Feature Specification: Build once — a read-only lookup before the checks

**Feature Branch**: `006-build-once-lookup`

**Created**: 2026-11-11

**Status**: Draft

**Input**: snackbyte-ops request #75e3f7 (Jeff, 2026-11-11, GitHub Actions cost review). A `dev` →
`main` promotion rebuilds the image and reruns the push-side checks for a tree staging already built
and tested: about 450 Actions minutes a month across consumers. The goal is that production deploys
the exact build staging runs, and that `main` skips the rebuild and the repeat checks when its tree
is one `dev` already released.

The recipes run the checks in the tag-writing job **before** the Action (Jeff's ruling, 2026-11-11,
PR #10), so a failed check leaves no tag: a tag on a tree is proof that tree passed its checks. But
the Action learns whether this push's number is **reused** (its tree already released) only while
tagging, at the end of the job, after the checks have already been paid for.

Jeff's ruling, 2026-11-11: split the Action into an early **look-up** step and the existing **tag**
step, in the same job. The look-up says, before any check runs, "this exact tree is already released
as `v1.4.7-dev`"; the job then skips its checks and its build, and the tag step stamps the number for
this environment at the end, as today.

## User Scenarios & Testing *(mandatory)*

The users are **maintainers of a repository consuming the Action under `build-id`** that promotes
between environment branches (the concrete case: every Snackbyte app, `dev` → `main`), and,
unchanged, **every existing consumer**, who must see no difference unless they opt in.

### User Story 1 - A promotion knows it is one before the checks run (Priority: P1)

A maintainer fast-forwards `main` to a `dev` commit that was released as `v1.4.7-dev`. The release
job's first step looks up the push and reports that the tree is already released as `v1.4.7-dev`,
without creating anything. The job skips its checks and its build; the tag step then tags `v1.4.7`.

**Why this priority**: This is the whole saving. Every promotion today pays for checks and a build
that staging already paid for.

**Independent Test**: In a scratch repository with `vMM.N-dev` on tree T, run the look-up for the
`""`-suffix environment at tree T: it reports version `MM.N`, tag `vMM.N`, released-as `vMM.N-dev`,
and the tag set is unchanged.

**Acceptance Scenarios**:

1. **Given** `vMM.N-dev` on tree T, **When** the look-up runs for the production branch at tree T,
   **Then** it reports released-as `vMM.N-dev`, version `MM.N`, tag `vMM.N`, and creates no tag.
2. **Given** the same state, **When** the look-up and then the tag step run in one job, **Then** the
   tag step creates exactly the tag the look-up reported.
3. **Given** a promotion whose tree also carries the number under a third environment's suffix,
   **When** the look-up runs, **Then** released-as is one of those tags, chosen the same way every
   time (the first by name).

### User Story 2 - New code is checked and built as always (Priority: P1)

A maintainer pushes a tree no tag carries. The look-up reports the number a new tag would get and
an empty released-as, so the checks and the build run, and the tag step mints that number.

**Why this priority**: Skipping checks on new code would ship untested code. An empty released-as
must be the only result for a tree with no release.

**Independent Test**: At a tree no tag carries, the look-up reports version `MM.(max+1)` and an empty
released-as; the tag set is unchanged.

**Acceptance Scenarios**:

1. **Given** a tree no tag carries, **When** the look-up runs, **Then** released-as is empty and the
   version is the one the tag step will mint.
2. **Given** a tree whose only same-number tag is owned by another tree for this environment (the
   duplicate-heal case of feature 005), **When** the look-up runs, **Then** it reports what the tag
   step would do, warning included, and released-as follows the number actually chosen.

### User Story 3 - The look-up fails where tagging would, and earlier (Priority: P2)

Every state in which the tag step would refuse (an already-released re-run, a shallow clone, a bad
input, an unreadable manifest) makes the look-up refuse too, so the job stops before spending its
checks.

**Why this priority**: A look-up that succeeded where the tag step later fails would spend the
checks and the build and then fail anyway, and could mislead a promotion into a skipped check.

**Acceptance Scenarios**:

1. **Given** the target tag already exists on this tree, **When** the look-up runs, **Then** it fails
   loudly with the same message as the tag step.
2. **Given** a shallow clone or an invalid input, **When** the look-up runs, **Then** it fails as the
   tag step would.
3. **Given** a branch not in the manifest, **When** the look-up runs, **Then** is-env is `false` and
   nothing else is derived, as for the tag step.

### User Story 4 - Existing consumers see no change (Priority: P1)

A consumer that never sets the new input gets today's behavior byte for byte, plus one new output
they may ignore.

**Acceptance Scenarios**:

1. **Given** no mode input, **When** the Action runs, **Then** it tags exactly as before, and the full
   existing matrix passes unchanged.
2. **Given** a promotion in tag mode, **When** the Action runs, **Then** released-as is also reported,
   so a workflow that tags first can still find staging's build.

### Edge Cases

- **`package-json` strategy**: no number is ever reused, so released-as is always empty and the
  look-up only previews the tag. Build once for libraries is out of scope.
- **Prefixed namespace**: the look-up reads only this releasable's tags, like every scan; released-as
  carries the prefix, like `tag`.
- **Read-only token**: the look-up needs no write permission and no git identity.
- **Look-up and tag disagreeing**: inside the releasable's serialized concurrency group no other
  derivation can change the tag set between the two steps, so they see the same tags and agree. A
  workflow that drops the group loses this, as it already loses the build-id guarantees.
- **Older tags**: a tag made before a consumer put its checks in the tag-writing job may not prove
  the checks ran. Whether to trust it is the consumer's call; the Action reports the fact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Action MUST accept a `mode` input: `tag` (default, today's behavior) or `lookup`.
  Any other value MUST be refused before any work, naming the input.
- **FR-002**: In `lookup` mode the Action MUST run resolve-env and the full derivation (input checks,
  shallow-clone refusal, reuse, the duplicate heal, the exists-guard) and MUST NOT create or push
  any tag.
- **FR-003**: In `lookup` mode the Action MUST report `is-env`, `version` and `tag` exactly as the tag
  step would for the same repository state.
- **FR-004**: In both modes, under `build-id`, the Action MUST report `released-as`: when the chosen
  number is reused from a tag on this tree, an existing tag in this namespace carrying that number
  on this tree, the first by name; otherwise empty.
- **FR-005**: Under `package-json`, `released-as` MUST be empty.
- **FR-006**: `lookup` mode MUST fail in every case where tag mode would fail before creating the tag,
  with the same message.
- **FR-007**: `lookup` mode MUST need no write permission and no git identity.
- **FR-008**: With `mode` unset, behavior MUST be unchanged; the existing test matrix MUST pass
  without edits.
- **FR-009**: The recipes MUST show the build-once pattern (look-up, checks and build gated on an
  empty released-as, tag, deploy of staging's build when released-as is set). This lands once PR #10
  is merged, since both change the same recipe text.

### Key Entities

- **Mode** — `tag` or `lookup`: whether this run creates the tag or only reports it.
- **Released-as** — an existing tag that already carries this push's number on this exact tree:
  the handle a promotion uses to find the build staging made.

## Success Criteria *(mandatory)*

- **SC-001**: A promotion that follows the recipe runs no checks and no build: its release job costs
  only checkout, look-up and tag.
- **SC-002**: The look-up and the tag step agree on version and tag in every tested state.
- **SC-003**: No look-up run creates, moves or deletes a tag.
- **SC-004**: Every existing test passes unchanged.

## Assumptions

- Consumers follow the recipe's rule that checks run before the tag, so a tag proves its tree passed.
- Staging's build can be found from released-as (images tagged by release tag or version). Making
  images environment-free, reporting the production version from a promoted image, and looking up
  the image by digest are the template's part, filed to `snackbyte-base` after this lands.
- The build-once recipe text lands after PR #10 merges.
