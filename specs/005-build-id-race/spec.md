# Feature Specification: Build-id race — per-releasable serialization and a self-healing reuse

**Feature Branch**: `005-build-id-race`

**Created**: 2026-09-22

**Status**: Draft

**Input**: Under `version-strategy: build-id` the PATCH is a **global** build id across every
environment branch of a releasable, but every published recipe serializes releases **per branch**
(`group: release-${{ github.ref_name }}`). A `main` push and a `dev` push whose derivations overlap
therefore both read the same max and both mint the same number — for *different* trees. The
duplicate itself is survivable; the consequence is not. The next promotion of that dev tree to
`main` is **permanently wedged**: step-1 reuse (tree-keyed, suffix-agnostic) finds the `-dev` tag on
its own tree, derives the number the bare namespace already gave to another tree, and the
exists-guard refuses. No rerun clears it — recovery is a manual tag deletion. Observed 2026-09-21 in
`jeff-fichtner/snackbyte-base` consuming `@v1` (= v1.1.0); reported as issue #3.

The root cause is a false invariant recorded in the constitution — "taking the max over every
suffix makes two commits sharing a number impossible" — which is true only across **serialized**
derivations. The scan and the tag push are not atomic. That line, and its companion guard "serialize
runs on the **same branch**", are what licensed the per-branch group in all four recipes and in this
repo's own workflow.

Close it on three fronts: amend the constitution to state the invariant's real precondition;
serialize per **releasable** (one concurrency group per tag namespace) with `queue: max` so a queued
release is not silently dropped; and make step-1 reuse **self-healing** so the wedge that today
needs a human becomes a warning line — which also repairs every existing consumer at `@v1` without
them editing a workflow.

## User Scenarios & Testing *(mandatory)*

The users are **maintainers of a repository consuming the Action under `build-id`** with more than
one environment branch (the concrete case: `snackbyte-base`, `main` + `dev`) and, unchanged, **every
existing consumer**, who must see no behavioral difference except in the already-broken case.

> **Terminology**: a **releasable** is one unit that produces versions — one tag namespace (one
> `tag-prefix`), one `package.json` version line, one or more environment branches. The build id is
> global *to the releasable*, not to the branch and not to the repository.

### User Story 1 - A wedged promotion heals itself (Priority: P1)

A maintainer whose `main` and `dev` pushes raced now pushes the dev tree to `main`. Instead of a
permanent failure, the derivation notices the number it would reuse is already taken by a different
tree, warns, and mints the next free number.

**Why this priority**: This is the reported outage. It is the only state that is *unrecoverable*
without manual tag surgery, and it reaches existing consumers through the floating `@v1` without any
workflow edit — the fastest path from "wedged" to "releasing".

**Independent Test**: Construct the post-race state directly (bare `vMM.2` on tree A, `vMM.2-a` on
tree B), push the `main` environment on tree B, assert the derivation produces `vMM.3` rather than
failing.

**Acceptance Scenarios**:

1. **Given** bare `vMM.2` on tree A and `vMM.2-a` on tree B, **When** the `""`-suffix environment is
   pushed at tree B, **Then** the derivation emits a warning annotation naming the duplicate and
   tags `vMM.3`.
2. **Given** that same state, **When** the derivation runs, **Then** no tag is deleted, moved, or
   force-updated — the pre-existing `vMM.2` and `vMM.2-a` are untouched.
3. **Given** a tree whose target tag exists on **that same tree** (a genuine re-run of an already
   released push), **When** the derivation runs, **Then** it still FAILS loudly — the self-heal MUST
   NOT swallow the "already released" guard.

### User Story 2 - A free target tag still reuses the number (Priority: P1)

A repository with three environments is in the post-race state on two of them. A push to the third
environment, whose own tag for that number is still free, must **reuse** the number — keeping one
tree to one build id — not advance to a fresh one.

**Why this priority**: Under `build-id` the number is the artifact identity; one tree MUST mean one
number. A self-heal scoped too broadly (firing whenever *any* tag carries the number) would give a
single tree two different build ids across its environments — manufacturing the very inconsistency
this feature exists to remove. This story is what pins the predicate to the narrow form.

**Independent Test**: With bare `vMM.2` on tree A and `vMM.2-a` on tree B, push the `-c` environment
at tree B and assert `vMM.2-c` — the number is reused, because `vMM.2-c` was free.

**Acceptance Scenarios**:

1. **Given** bare `vMM.2` (tree A) and `vMM.2-a` (tree B), **When** the `-c` environment is pushed at
   tree B, **Then** the tag is `vMM.2-c` (reuse), NOT `vMM.3`.
2. **Given** a tree carrying several reusable numbers, some of whose target tags are taken by other
   trees, **When** the derivation runs, **Then** it reuses the **highest still-usable** number
   rather than advancing to max+1.

### User Story 3 - The race stops happening (Priority: P2)

A maintainer adopting the published recipe gets a concurrency group that actually serializes every
derivation for the releasable, and queued releases wait their turn instead of being cancelled.

**Why this priority**: P2 because it only reaches a consumer when that consumer edits their workflow
— it cannot be shipped through `@v1`. It is nonetheless the actual fix: Story 1 heals the residue,
this prevents it.

**Independent Test**: Inspection — the recipes and this repo's workflow key the group on the
releasable (the `tag-prefix`), not on `github.ref_name`, and set `queue: max`.

**Acceptance Scenarios**:

1. **Given** the recipes in `CONSUMING.md`, **When** a reader copies one, **Then** the concurrency
   group is per releasable and carries `queue: max` with `cancel-in-progress: false`.
2. **Given** two releasables in one repository, **When** both release at once, **Then** they are in
   **different** groups (keyed on their prefixes) and do not serialize against each other.
3. **Given** this repository's own `release.yml`, **When** compared to recipe A, **Then** their
   concurrency blocks are identical — the reference implementation follows its own advice.

### User Story 4 - The constitution states a true invariant (Priority: P2)

A future feature touching derivation is validated against a rule that production has not falsified.

**Why this priority**: Under Spec Kit the constitution is what plans and specs are checked against.
Left as-is, `/speckit-analyze` confirms the code matches the constitution — because it does — while
both are wrong. Every downstream restatement (the script header, README, CONSUMING, the workflow
comment) is a faithful copy of the constitutional line and must follow it.

**Acceptance Scenarios**:

1. **Given** the constitution, **When** the max-over-suffixes invariant is read, **Then** it states
   its precondition: it holds across **serialized** derivations, because the scan and the tag push
   are not atomic.
2. **Given** the constitution's mandatory guards, **When** the serialization guard is read, **Then**
   it requires one concurrency group per **releasable** (tag namespace), not per branch.
3. **Given** the repository, **When** every restatement of the invariant is located, **Then** none
   still claims collisions are unconditionally impossible.

### Edge Cases

- **Genuine re-run** — target tag on HEAD's own tree: still fail-loud (US1 #3). The self-heal
  distinguishes "another tree owns this tag" from "we already released this tag".
- **`package-json` strategy**: unreachable. The self-heal lives inside the `build-id` arm; a library
  release is unaffected.
- **Prefixed namespace**: the heal is anchored on the prefix like every other scan — a prefixed
  derivation heals off prefixed tags and stays blind to bare ones, and vice versa.
- **No candidate is usable**: every number on this tree has its target tag taken by another tree →
  the candidate set is empty → step 2 (max+1) runs, which is the correct answer.
- **The race itself is not reproducible in the test suite** — two concurrent derivations racing a tag
  scan are not reachable from a shell harness. The post-race *state* is fully constructible with
  `git tag`, and that is what the rows assert. The concurrency group is correct-by-inspection only;
  this is a stated limit, not an oversight.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Step-1 reuse MUST treat a candidate number as usable only when this environment's
  target tag for it (`<prefix>vMM.<n><suffix>`) is either absent or already points at HEAD's tree.
- **FR-002**: When a candidate is rejected under FR-001, the derivation MUST continue to the next
  candidate and select the **highest usable** one; only an empty usable set falls through to max+1.
- **FR-003**: A rejected candidate MUST emit a GitHub Actions warning annotation naming the number
  and the conflicting tag, and MUST degrade to an ordinary printed line outside Actions.
- **FR-004**: The exists-guard MUST be unchanged: a target tag already on HEAD's own tree still
  fails loudly.
- **FR-005**: No tag may be deleted, moved, or force-updated. Tag-only, create-only, as today.
- **FR-006**: The heal MUST be anchored on `TAG_PREFIX` — blind to other namespaces, in both
  directions.
- **FR-007**: The heal MUST NOT be reachable under `version-strategy: package-json`.
- **FR-008**: All four `CONSUMING.md` recipes and this repository's `release.yml` MUST key the
  concurrency group on the releasable (the `tag-prefix`, or a bare `release` for a single
  releasable), keep `cancel-in-progress: false`, and add `queue: max`.
- **FR-009**: The constitution MUST state the max-over-suffixes invariant with its serialization
  precondition, and MUST require per-releasable serialization.
- **FR-010**: Every restatement of the invariant in the repository MUST be corrected to match
  FR-009.

### Key Entities

- **Candidate number** — a patch integer parsed from a tag that points at HEAD's tree, in this
  namespace. The set step 1 chooses from.
- **Target tag** — `<prefix>vMM.<n><suffix>`: the tag this derivation would create for a candidate.
  Its owner (absent / HEAD's tree / another tree) is the whole of the new decision.
- **Poisoned number** — a candidate whose target tag belongs to another tree: evidence that
  concurrent derivations minted one number twice.

## Success Criteria *(mandatory)*

- **SC-001**: The reported wedge resolves without human intervention: the derivation that fails
  today produces a tag, and says why it renumbered.
- **SC-002**: A tree keeps **one** build id per environment it is released to — the narrow predicate
  never splits a tree across two numbers where a reuse was available.
- **SC-003**: Existing behavior is unchanged everywhere else: the full existing matrix passes
  untouched, B7 and B8 included.
- **SC-004**: A consumer copying a recipe cannot reconstruct the race, and cannot silently lose a
  queued release to pending-run cancellation.
- **SC-005**: No document in the repository asserts that collisions are unconditionally impossible.

## Assumptions

- GitHub's `queue: max` is available to these repositories (public repo, GitHub-hosted runners) and
  admits up to 100 waiting runs per group, cancelling beyond that. Accepted: 100 queued releases is
  far past any real burst.
- Serializing `main` against `dev` for one releasable costs promotion latency in a burst (each run
  takes full CI time). Accepted as the price of a correct global counter.
- A bare `group: release` is repository-scoped and could collide with an unrelated workflow in a
  consumer that happens to use the same group name. Documented in the recipe comment; not otherwise
  mitigated.
