<!--
Sync Impact Report
==================
Version change: 1.1.0 → 1.2.0 (2026-09-22, feature 005-build-id-race)
Rationale: MINOR — guidance materially expanded after production falsified a stated invariant
(issue #3). Principle III asserted that taking the max over every suffix makes two commits
sharing a number IMPOSSIBLE; that holds only across SERIALIZED derivations, because the tag
scan and the tag push are not atomic. Principle V's serialization guard said "same branch",
which is the wrong granularity — the build id is global to the RELEASABLE, so a per-branch
group lets `main` and `dev` race, and the resulting duplicate permanently wedges the next
promotion. III now states the precondition and requires reuse to skip a number owned by
another tree; V now requires one group per tag namespace, forbids a serialization that silently
drops a deferred release, and requires a healed duplicate to be visible. V states the requirement
without naming a vendor keyword — the mechanism (GitHub's `queue: max`) belongs in CONSUMING.md,
where it can be corrected if the platform changes, not in a document that otherwise speaks only
of tags, trees and manifests. No principle removed or redefined, hence MINOR not MAJOR.

Principles modified:
  III. Fixed, Derived Tag Format — invariant gains its serialization precondition; reuse must
       skip a candidate whose target tag belongs to a different tree.
  V.  Fail Loud — serialization guard restated per-releasable (was per-branch); adds the
       must-not-drop-a-deferred-release rule and the heal-must-be-visible rule.

Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check references this file generically.
  ✅ .specify/templates/spec-template.md — no mandatory-section conflict.
  ✅ .specify/templates/tasks-template.md — no change.

Follow-up TODOs: none.

--- previous report (1.1.0) ---
Version change: 1.0.0 → 1.1.0 (2026-09-21, feature 004-tag-prefix)
Rationale: MINOR — Principle III materially expanded. The tag format gains an optional tag
NAMESPACE prefix (`${tagPrefix}v…`, default empty) so a repository can hold more than one
releasable; reuse and max are computed within a namespace. Within a namespace the format and
the one-rule derivation are unchanged. The Additional Constraints inputs list gains `tag-prefix`
and `package-json` (the path the version is read from; a parameterization of the hard-coded
`./package.json` read, in the spirit of VII) — and, catching up, `version-strategy` from 002.

Principles modified:
  III. Fixed, Derived Tag Format — optional namespace prefix; max/reuse per namespace.

Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check references this file generically.
  ✅ .specify/templates/spec-template.md — no mandatory-section conflict.
  ✅ .specify/templates/tasks-template.md — no change.

Follow-up TODOs: none.

--- previous report (1.0.0) ---
Version change: (none) → 1.0.0
Rationale: Initial ratification. First concrete constitution replacing the template stub.

Principles defined:
  I.   Tag-Only, Never a Commit
  II.  Tree-Hash Is the Reuse Key
  III. Fixed, Derived Tag Format (NON-NEGOTIABLE)
  IV.  The Manifest Is the Product (One-Row Edit)
  V.   Fail Loud, Never Silent
  VI.  Distributed as an Action, Not a Package
  VII. Extract by Parameterization, Not Rewrite

Added sections:
  - Additional Constraints (manifest schema + action.yml I/O)
  - Development Workflow (Spec Kit gates, test-matrix discipline)
  - Governance

Removed sections: none (template stub replaced wholesale)

Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check gate references this file
     generically; no principle-specific edits required.
  ✅ .specify/templates/spec-template.md — no mandatory-section conflict.
  ✅ .specify/templates/tasks-template.md — versioning/testing task types already
     accommodated by principles III & VII.

Follow-up TODOs: none. RATIFICATION_DATE set to today (project's first constitution).
-->

# snackbyte-release-flow-action Constitution

A shareable GitHub Action that turns a repo's `environments.json` manifest into its
release flow: resolve-env ("is this pushed branch a deployable environment?") and
derive-version ("what version tag does this push get?"). These principles are the
non-negotiable contract the Action's behavior MUST satisfy.

## Core Principles

### I. Tag-Only, Never a Commit

The Action MUST create a git **tag** and nothing else. It MUST NOT create a commit,
push a branch, amend history, or mutate the working tree. The single side effect of a
successful run is exactly one new tag on the pushed commit.

Rationale: The release flow observes and labels history; it does not author it. Keeping
the side effect to a single tag makes runs auditable and safe to re-drive, and keeps the
Action usable in workflows with protected branches.

### II. Tree-Hash Is the Reuse Key

The build-number reuse decision MUST key on the git **tree hash**, never the commit SHA.
If any number is already tagged on a commit carrying this exact source tree (regardless
of `tagSuffix`), that number MUST be reused.

Rationale: Promoting dev→main must reuse the dev build number when the promotion is a
fast-forward, merge, squash, or clean rebase — all of which leave the tree identical. A
rebase that absorbs divergent changes yields a *different* tree and MUST correctly mint a
new number. The commit SHA changes across all these operations; the tree hash is the only
key that expresses "same source, therefore same build."

### III. Fixed, Derived Tag Format (NON-NEGOTIABLE)

The tag format MUST be exactly `${tagPrefix}v${MAJOR}.${MINOR}.${PATCH}${tagSuffix}`, where
`tagPrefix` is the optional **tag namespace** (the `tag-prefix` input; default `""`, giving the
bare `v…` form).
- `MAJOR.MINOR` MUST come from `package.json` (or the `major-minor` input), never from a
  tag.
- `PATCH` MUST be a global, monotonic build id within its namespace: reuse per Principle II,
  otherwise `max(PATCH over ALL <prefix>vMM.* tags in this namespace, across every suffix) + 1`.
- Taking the max over every suffix makes two trees sharing a number impossible **across
  serialized derivations only**. The tag scan and the tag push are NOT atomic: two runs that
  both read the tag set before either pushes will both mint the same number, for different
  trees. Serialization is therefore a mandatory guard, not an optimization (Principle V), and
  reuse MUST heal the residue when it happens anyway — a candidate number whose target tag is
  owned by a different tree MUST be skipped, not reused.
- Gaps in the PATCH sequence are expected and correct for a build id and MUST NOT be treated
  as errors.
- A namespace MUST be blind to every other namespace: a derivation reads only tags carrying
  its exact prefix (anchored), and the un-prefixed namespace reads only bare `v…` tags. A
  repository holding more than one releasable gives each its own prefix; nothing else changes.

Rationale: A single, mechanical format with one derivation rule for every environment is
what lets the manifest stay a one-row edit (Principle IV). Any per-environment special
casing of the format breaks that guarantee. The namespace prefix exists so a second
releasable in the same repository does not corrupt the first's numbers; within a namespace
the rule is unchanged.

### IV. The Manifest Is the Product (One-Row Edit)

`environments.json` is the single source of truth for the release flow. Adding, removing,
or changing an environment MUST be achievable as a **one-row edit** to the manifest, with
no other change to the release tooling. Facets (`name`, `branch`, `isPublicFace`,
`noindex`, `tagSuffix`) MUST remain independent, single-purpose switches — no facet may
imply or override another.

Rationale: The reusable invention is the manifest convention, not any one consumer script.
The one-row-edit property is the whole value proposition and MUST be provable by test.

### V. Fail Loud, Never Silent

The Action MUST fail loudly rather than proceed on ambiguous or unsafe state. Mandatory
guards:
- Refuse to overwrite an already-existing target tag (fail, do not force).
- Refuse shallow clones — they hide tags and would corrupt the max/reuse computation.
- Parse tags with anchored regexes only; a near-match MUST NOT be silently accepted.
- Serialize runs per **releasable** — ONE concurrency group per tag namespace, covering every
  environment branch of that releasable. The number is global to the namespace, so a per-branch
  group does NOT serialize `main` against `dev` and they will race to the same number. The
  group MUST let runs WAIT: if a run is held back, it MUST actually run later, never be thrown
  away. Two different releasables MAY share a group (it only costs time); one releasable MUST NOT
  be split across two groups, which is this defect all over again.
- When a duplicate number reaches the tag set regardless, reuse MUST skip it and say so
  visibly (an annotation, not only stderr) rather than deriving a number another tree owns.
- A push to a branch not listed in the manifest MUST be rejected by derivation and
  short-circuited by resolve-env — never assigned a default environment.

Rationale: A version-derivation tool that guesses is worse than one that stops. Every
guard converts a silent-corruption failure mode into a visible, actionable error.

### VI. Distributed as an Action, Not a Package

The distribution contract is `action.yml` + a moving `v1` tag + (optionally) a Marketplace
listing. The project MUST NOT acquire npm-package publish surface (no `exports` map, no
`files` allowlist, no tarball, no `npm publish`). Consumers adopt it via
`uses: snackbyte/…@v1`.

Rationale: An Action is a distinct distribution axis from an npm module, the way a VS Code
extension is distinct from a library. Conflating the two adds publish surface that serves
no consumer of this tool.

### VII. Extract by Parameterization, Not Rewrite

The algorithm, manifest, and test matrices already exist and are battle-tested in
`snackbyte-base`. When built, this Action MUST be produced by **parameterizing** that
source (replacing hard-coded `./environments.json` and `./package.json` reads with Action
inputs), not by reimplementing the logic. Any behavioral divergence from the extracted
contract MUST be a deliberate, documented amendment — never an incidental rewrite artifact.

Rationale: The value is in a proven algorithm with a formal contract and a 15-row test
matrix. Rewriting risks silently dropping a guarantee the matrix encodes; parameterization
preserves it by construction.

## Additional Constraints

**Manifest schema.** Each `environments.json` entry has: `name` (identity reported at
`/api/version`), `branch` (the git branch driving the environment), `isPublicFace`
(hide dev-only affordances when false), `noindex` (emit `X-Robots-Tag: noindex`), and
`tagSuffix` (stamped on derived tags; `''`, `-dev`, …). Two entries sharing a `tagSuffix`
is permitted but MUST be warned (their tags become indistinguishable).

**Inputs / outputs (intended `action.yml`).** Inputs: `branch` (default
`github.ref_name`), `manifest` (path or inline JSON, default `./environments.json`),
`package-json` (path, default `./package.json`), `major-minor` (default: read the
`package-json` file), `version-strategy` (`build-id` default | `package-json`), `tag-prefix`
(default `""`). Outputs: `is-env` (resolve-env result),
`version` (`MM.P`, never prefixed), `tag` (`<prefix>vMM.P<suffix>`).

## Development Workflow

- **Spec Kit gates.** Features flow through `/speckit-specify` → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-implement`. Each plan MUST include a Constitution Check
  confirming the seven principles above are upheld.
- **Test-matrix discipline.** The extracted derivation test matrix (rows B1–B15) and the
  one-row-edit proof (`add-env.test.sh`) are the acceptance gate for any change to
  derivation or manifest handling. A change that alters derivation behavior MUST update
  the matrix in the same change, never after.
- **Build status.** The build is deliberately deferred until explicitly resumed; the
  design (README.md), the source location (`snackbyte-base`), and this constitution stand
  in its place until then.

## Governance

This constitution supersedes ad-hoc practice for the release flow. Amendments MUST be made
by editing this file, MUST bump the version per the policy below, and MUST update the Sync
Impact Report and any dependent templates in the same change.

Versioning policy (semantic):
- **MAJOR** — a backward-incompatible governance or principle removal/redefinition.
- **MINOR** — a new principle or materially expanded guidance.
- **PATCH** — clarifications, wording, or non-semantic refinements.

Compliance: every plan's Constitution Check and every PR review MUST verify conformance to
these principles. Any deviation MUST be justified in writing or the change MUST be revised.

**Version**: 1.2.0 | **Ratified**: 2026-07-06 | **Last Amended**: 2026-09-22
