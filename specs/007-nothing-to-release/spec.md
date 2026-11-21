# Feature Specification: Nothing to release — a library push without a version bump stays green

**Feature Branch**: `007-nothing-to-release`

**Created**: 2026-11-21

**Status**: Implemented (awaiting review)

**Input**: snackbyte-ops request #1a9838, from snackbyte-npm-base (its request #aa73b9, PR
jeff-fichtner/snackbyte-npm-base#11). Under `version-strategy: package-json`, every push to a release
branch that does not bump `package.json`'s version fails at the exists-guard (`Tag v<version>
already exists - refusing to overwrite`), so docs, chore and Dependabot merges leave a red run on
`main` (spec-render's `main` was red for weeks).

Jeff's ruling, 2026-11-08: a merge that is not meant to be a release must not fail; keep the guard
for a real collision.

Two consumers already work around it with their own step before the Action: snackbyte-npm-base
(skip when `v<version>` exists, is an ancestor of HEAD, and the version is out: on npm, or the
package is private) and snackbyte-auth's `release-client-node.yml` (tag exists and on npm). Every
`package-json` consumer needs the same step, so the Action absorbs the part of it that is about tags.

## User Scenarios & Testing *(mandatory)*

The users are **maintainers of a library consuming the Action under `package-json`**, and,
unchanged, **every existing consumer**, who must see no difference unless they adopt the look-up.

### User Story 1 - A merge without a bump is green and says why (Priority: P1)

A maintainer merges a docs change to `main` without bumping the version. The release job's look-up
reports that `v1.4.0` is already released on an earlier commit of `main`, with a notice "Nothing to
release". The job skips its checks, the tag step and the publish, and the run is green.

**Independent Test**: In a scratch repository, release `v1.4.0` under `package-json`, add a commit
without a bump, and run the look-up: it succeeds with released-as `v1.4.0`, the notice, and an
unchanged tag set (rows NR1, NR6).

**Acceptance Scenarios**:

1. **Given** `v1.4.0` on an earlier commit of `main` and `package.json` still at `1.4.0`, **When** the
   look-up runs, **Then** it succeeds with version `1.4.0`, tag `v1.4.0`, released-as `v1.4.0`, a
   "Nothing to release" notice, and creates nothing.
2. **Given** the same state, **When** the tag step runs, **Then** it still refuses, naming the cause
   and the way out (bump, or look up first).
3. **Given** a bump to `1.5.0`, **When** the look-up runs, **Then** released-as is empty and the job
   releases as before.

### User Story 2 - A real collision still fails loudly (Priority: P1)

The guard stays for every case that is not "a later push on the same line of history":

1. **Given** the tag on HEAD itself (a re-run of the release push), **When** the look-up runs,
   **Then** it fails, as before.
2. **Given** the tag on a commit that is not in this branch's history, **When** the look-up runs,
   **Then** it fails, as before.
3. **Given** `build-id`, **When** the target exists on an earlier commit with the same tree, **Then**
   the look-up fails, as before: the change is `package-json` only.

### User Story 3 - Channels and namespaces keep their own tags (Priority: P2)

Under `package-json` with several channels or a tag prefix, only this channel's own tag in this
namespace counts: `v1.4.0` on `main` does not make channel A's `v1.4.0-a` released, and a bare
`v1.4.0` does not make `lib-v1.4.0` released.

### Edge Cases

- A lightweight tag counts like an annotated one (the tag is resolved to its commit).
- A version set back to one already released on this line (a reverted bump) reads as nothing to
  release. Not guarded: the Action does not second-guess the version a maintainer wrote.
- A tagged version whose publish failed: the Action knows nothing about registries, so a later push
  without a bump looks up as released. The recipe's skip branch checks the registry for a public
  package and fails if the version is missing (see [quickstart.md](./quickstart.md)).

## Requirements *(mandatory)*

- **FR-001**: Under `package-json` in `lookup` mode, when the target tag exists and its commit is an
  ancestor of HEAD other than HEAD itself, the Action MUST succeed, set `released-as` to that tag,
  set `version` and `tag` as usual, emit a `::notice` titled "Nothing to release", and create
  nothing.
- **FR-002**: In `tag` mode the same state MUST still fail, with a message naming the earlier commit
  and the two ways out.
- **FR-003**: Every other existing-target state MUST fail in both modes, as before.
- **FR-004**: `build-id` behaviour MUST NOT change.
- **FR-005**: A consumer that does not adopt the look-up MUST see no change in outcome (tag mode is
  unchanged).

## Success Criteria *(mandatory)*

- **SC-001**: Rows NR1–NR10 and I5 pass; every existing row passes unedited.
- **SC-002**: The real `uses: ./` look-up in the PR gate reports released-as for a library version
  tagged on HEAD's parent and creates nothing.
- **SC-003**: A consumer following the updated Recipe B gets a green run on a merge without a bump.

## Clarifications

### Session 2026-11-21

Answered as Jeff's stand-in; each is also a decision in the PR.

- Q: Absorb into the Action, or close the request saying the consumer-side step is the intended
  shape? → A: Absorb the part about tags (is the tag on an earlier commit of this branch?). The
  registry part (is the version on npm?) stays in the recipe: the Action is registry-agnostic.
- Q: Which mode reports it? → A: `lookup` only. `tag` keeps refusing. A library recipe needs the
  look-up anyway, because its checks run before the tag, and a look-up creates nothing, so turning
  its refusal into a report is safe by default and needs no new input.
- Q: How is it reported? → A: Through the existing `released-as` output (set to the tag itself)
  plus a notice. No new output name.
- Q: Does a re-run of the release push count? → A: No. The tag on HEAD itself still fails, so
  "re-run all jobs" of a release whose publish failed stays loud instead of turning green unpublished.
- Q: `build-id` too? → A: No. There every new tree mints a new number, so a push with nothing to
  release does not arise.
