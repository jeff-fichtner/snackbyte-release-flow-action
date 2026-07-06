<!--
Sync Impact Report
==================
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

The tag format MUST be exactly `v${MAJOR}.${MINOR}.${PATCH}${tagSuffix}`.
- `MAJOR.MINOR` MUST come from `package.json` (or the `major-minor` input), never from a
  tag.
- `PATCH` MUST be a global, monotonic build id: reuse per Principle II, otherwise
  `max(PATCH over ALL vMM.* tags, across every suffix) + 1`.
- Taking the max over every suffix makes two commits sharing a number impossible. Gaps in
  the PATCH sequence are expected and correct for a build id and MUST NOT be treated as
  errors.

Rationale: A single, mechanical format with one derivation rule for every environment is
what lets the manifest stay a one-row edit (Principle IV). Any per-environment special
casing of the format breaks that guarantee.

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
- Serialize runs on the same branch so two pushes cannot race to the same number.
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
`major-minor` (default: read `package.json`). Outputs: `is-env` (resolve-env result),
`version` (`MM.P`), `tag` (`vMM.P<suffix>`).

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

**Version**: 1.0.0 | **Ratified**: 2026-07-06 | **Last Amended**: 2026-07-06
