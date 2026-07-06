# Feature Specification: Extract the manifest-driven release flow as a reusable Action

**Feature Branch**: `001-extract-release-flow`

**Created**: 2026-07-06

**Status**: Draft

**Input**: User description: "The first 001 spec — the basic transference of the release-flow code from snackbyte-base into this repo as a shareable GitHub Action (resolve-env + version derivation), including its tests. Extraction by parameterization, not rewrite."

## User Scenarios & Testing *(mandatory)*

The "users" of this feature are **maintainers of application repositories** who want their
CI to answer two questions on every branch push — "is this branch a deployable
environment?" and "what version tag does this push get?" — by referencing one shared,
versioned unit rather than copy-pasting scripts into each repo. A secondary user is the
**CI system itself**, which consumes the Action's outputs to gate downstream build/deploy
work.

### User Story 1 - Derive the correct version tag for an environment push (Priority: P1)

A maintainer pushes a commit to a branch that their `environments.json` declares as an
environment (e.g. `main` → production, `dev` → staging). They need CI to compute the one
correct version tag for that push and create it — reusing an existing build number when the
source tree is unchanged from an already-tagged commit (a promotion), and advancing to a
fresh number otherwise. The Action must create a tag and nothing else.

**Why this priority**: This is the core value. Without correct, reusable, tag-only version
derivation there is no release flow; every other story is supporting scaffolding around it.

**Independent Test**: Point a workflow (or a local harness) at a repo whose manifest
declares an environment, push commits that exercise mint / advance / reuse / promotion, and
assert the exact tag produced against the known-correct expectation for each case. Delivers
value on its own: a repo gets correct release tags even if nothing else in this feature
existed.

**Acceptance Scenarios**:

1. **Given** a repo with no version tags and a manifest declaring `main` as the
   production environment (empty suffix), **When** a commit is pushed to `main`, **Then**
   the Action creates the first tag `vMAJOR.MINOR.0` (MAJOR.MINOR from the repo's declared
   version) and reports it as an output.
2. **Given** existing tags up to `vMM.N` across any mix of environment suffixes, **When** a
   commit with a new source tree is pushed to an environment branch, **Then** the Action
   creates `vMM.(N+1)<suffix>` — the global max patch advanced by one, with that
   environment's suffix.
3. **Given** a commit whose exact source tree already carries a version number from another
   environment's tag (a promotion via fast-forward, merge, squash, or clean rebase),
   **When** it is pushed to a different environment branch, **Then** the Action reuses that
   same number with the new environment's suffix rather than minting a new number.
4. **Given** a merge or rebase that absorbs divergent changes (producing a source tree that
   differs from every tagged commit), **When** it is pushed to an environment branch,
   **Then** the Action mints a fresh number (no incorrect reuse).

### User Story 2 - Short-circuit pushes to non-environment branches (Priority: P1)

A maintainer pushes to a branch that is **not** an environment (a feature/fix/chore
branch). They need CI to recognize immediately that nothing should be built, tagged, or
deployed — before any expensive setup runs — and to say so clearly.

**Why this priority**: Equal-first with Story 1. It is the guard that makes the release
flow safe to wire into a broad push trigger: without it, non-environment pushes would fall
into derivation and fail loudly or waste CI. It is a distinct, independently useful answer
("is this an environment?") that consumers use as a gate.

**Independent Test**: Query the Action's environment-check result for a known environment
branch and for a known non-environment branch; assert `true` and `false` respectively,
independent of any tagging.

**Acceptance Scenarios**:

1. **Given** a manifest declaring `main` and `dev` as environments, **When** the check runs
   for `main`, **Then** it reports the branch **is** an environment.
2. **Given** the same manifest, **When** the check runs for `feature-x`, **Then** it reports
   the branch is **not** an environment, so downstream tag/deploy work is skipped.

### User Story 3 - Adopt and evolve environments as a one-row manifest edit (Priority: P2)

A maintainer wants to add, remove, or change a deployment environment (e.g. add a `qa`
environment on a `qa` branch with a `-qa` tag suffix) by editing exactly one row of
`environments.json`, with no change to any script, workflow wiring, or the Action itself.

**Why this priority**: This is the reusability promise that justifies extracting the flow
into a shared Action at all. It is P2 rather than P1 only because Stories 1 and 2 must work
first for it to be demonstrable — but a release flow that required editing tooling per
environment would fail its reason for existing.

**Independent Test**: In a throwaway repo, add one environment row to the manifest and
assert (a) the change touched only `environments.json`, (b) a push to the new branch
derives a tag with the new suffix, and (c) the environment check recognizes the new branch
and still rejects a non-environment branch.

**Acceptance Scenarios**:

1. **Given** a working release flow, **When** a maintainer adds one environment row to
   `environments.json` and nothing else, **Then** pushes to that environment's branch derive
   correctly-suffixed tags and the environment check recognizes it — with no other file
   changed.

### User Story 4 - Reference the flow as a versioned, shared unit (Priority: P2)

A maintainer wants to consume the release flow from another repository's workflow by
referencing this Action at a stable major version, rather than vendoring copies of the
scripts into each repo. When the Action improves, consumers pinned to the major version
receive the improvement without editing their repos.

**Why this priority**: This is the distribution rationale for the whole project. It is P2
because the flow's *behavior* (Stories 1–3) is the prerequisite; packaging it for reference
is the delivery mechanism layered on top.

**Independent Test**: From a consumer workflow, reference the Action at its major version,
supply a manifest and a branch, and observe that the environment-check and version outputs
are returned to the consuming workflow without the consumer having copied any script.

**Acceptance Scenarios**:

1. **Given** the Action published at a stable major version, **When** a consumer workflow
   references it and provides the required inputs, **Then** the consumer receives the
   environment-check result and (for an environment push) the derived version and tag as
   outputs it can gate later steps on.

### Edge Cases

- **Duplicate tag suffixes**: Two environments declaring the same suffix is permitted but
  must be surfaced as a non-blocking warning (their tags become indistinguishable); it must
  not corrupt derivation or fail the run.
- **Target tag already exists**: If the tag the derivation would create already exists
  (a re-run, a race, or an attempt to re-release a number), the Action must fail loudly and
  create nothing, rather than overwrite or silently reuse.
- **Truncated (shallow) history**: If the repository history is shallow, existing tags may
  be hidden and a number could be mis-derived; the Action must refuse to derive and say why,
  rather than produce a wrong number.
- **Unknown branch reaching derivation**: A push to a branch not declared in the manifest
  must be rejected by derivation with a clear message (it is normally short-circuited by the
  environment check first), never assigned a default environment.
- **Number gaps**: Because build numbers advance over the global maximum across all
  suffixes, gaps in the sequence are expected and correct and must not be treated as errors.
- **First push, empty vs. shallow**: Zero tags on a complete history is a legitimate first
  release (mint `.0`); zero tags on a shallow history is a truncation to refuse. The two
  must be distinguished, not conflated.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The release flow MUST determine, from a manifest of environments and a given
  branch, whether that branch is a deployable environment, and expose that yes/no answer as
  a consumable result.
- **FR-002**: The release flow MUST derive a single version tag of the fixed form
  `v<MAJOR>.<MINOR>.<PATCH><suffix>`, where MAJOR.MINOR come from the repository's declared
  version and the suffix is the pushed branch's environment suffix from the manifest.
- **FR-003**: The PATCH component MUST be a global, monotonic build number: it MUST be
  **reused** when the pushed commit's exact source tree already carries a number on any
  existing tag (regardless of suffix), and MUST otherwise **advance** to one greater than
  the maximum PATCH across all existing version tags of that MAJOR.MINOR (across every
  suffix).
- **FR-004**: Reuse MUST be keyed on the **source tree**, not the commit identity, so that a
  promotion which changes the commit but not the content (fast-forward, merge, squash, or
  clean rebase) reuses the number, while a change that alters the content mints a new number.
- **FR-005**: The release flow MUST create the derived tag and MUST NOT create a commit,
  push a branch, or otherwise modify repository history or the working tree.
- **FR-006**: The release flow MUST expose the derived version and tag as consumable results
  for downstream steps.
- **FR-007**: The release flow MUST fail loudly and create nothing when the target tag
  already exists, when history is shallow, or when the branch is not a declared environment.
- **FR-008**: The release flow MUST warn (without failing) when two environments declare the
  same tag suffix.
- **FR-009**: Adding, removing, or changing an environment MUST be achievable by editing only
  the manifest, with no change required to the release-flow logic or its wiring.
- **FR-010**: The release flow MUST be consumable as a single shared, versioned unit
  referenced from another repository's CI, parameterized by inputs for the branch, the
  manifest, and the MAJOR.MINOR source — rather than requiring each consumer to vendor the
  logic. Behavior MUST match the extracted source exactly except where a change is a
  deliberate, documented decision (no incidental divergence).
- **FR-011**: The extracted behavior MUST be covered by an executable acceptance suite that
  exercises the full set of distinct derivation behaviors (mint, advance across mixed
  suffixes, reuse-on-tree, promotion via merge/squash, collision guard, shallow refusal,
  unknown-branch refusal, hotfix gaps, single-environment self-increment) and the
  one-row-edit proof, and that suite MUST pass.

### Key Entities *(include if feature involves data)*

- **Environment manifest**: The declared set of environments the application deploys to; the
  single source of truth the flow reads. Each **environment** has independent, single-purpose
  facets: a name (reported identity), a driving branch, whether it is the public face,
  whether it is excluded from indexing, and a tag suffix stamped on its derived tags.
- **Version tag**: A git tag of the fixed form `v<MAJOR>.<MINOR>.<PATCH><suffix>`; the flow's
  only output artifact. MAJOR.MINOR is the repository's declared version line; PATCH is the
  global build number; suffix identifies the environment.
- **Source tree**: The content identity of a commit (independent of its commit identity); the
  key on which build-number reuse is decided.
- **Environment-check result**: The yes/no answer to "is this branch a deployable
  environment?", consumed as a gate by the CI that invokes the flow.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every distinct derivation behavior in the acceptance suite, the tag the
  flow produces matches the known-correct expected tag — 100% of acceptance rows pass.
- **SC-002**: A push to a non-environment branch results in no tag, no commit, and no build
  work, and reports "not an environment" — verified for at least one representative
  non-environment branch.
- **SC-003**: Adding one environment is achievable by changing exactly one file
  (`environments.json`) — verified by asserting the environment-addition change touches no
  other file while the new environment then derives correctly-suffixed tags.
- **SC-004**: In every successful run, the repository gains exactly one new tag and zero new
  commits and zero branch updates.
- **SC-005**: Each fail-loud condition (existing target tag, shallow history, unknown branch)
  produces a non-zero result and creates no tag — verified for each condition.
- **SC-006**: A consumer repository can obtain the environment-check result and the derived
  version/tag by referencing the shared unit and supplying inputs, without copying any of the
  flow's logic into the consumer — demonstrated once end-to-end.

## Assumptions

- **Extraction, not reinvention**: The derivation algorithm, the manifest convention, and the
  behavior matrix already exist and are battle-tested in `snackbyte-base`; this feature moves
  and parameterizes them. Any behavioral change from that source is a deliberate, documented
  decision, not an accident of re-implementation. (Constitution Principle VII.)
- **Manifest schema is settled**: The environment facets (name, branch, isPublicFace,
  noindex, tagSuffix) and the fixed tag format are the established contract and are not being
  redesigned in this feature.
- **Host platform**: The flow runs in a CI environment that provides a git checkout and can
  create and push tags; the consuming repository grants the flow permission to push a tag.
- **Full history available**: Consumers configure their checkout to include full history and
  tags; the flow refuses to proceed on a shallow checkout rather than guess.
- **Version source**: MAJOR.MINOR comes from the repository's declared version (its
  `package.json` version line by default), with the patch field there ignored; an input may
  override the source.
- **Distribution is an Action, not a package**: The delivery contract is a referenceable
  Action at a stable major version — not an installable library. (Constitution Principle VI.)
- **Publishing to a Marketplace and the Action's own release/versioning workflow are out of
  scope for this feature** and, if pursued, belong to a later feature; 001 delivers the
  extracted, parameterized, test-covered flow usable via a repository reference.
