# snackbyte-release-flow-action

> **Status: built (feature 001).** The Action is implemented — `action.yml`, the two
> bundled scripts (`scripts/derive-version.sh`, `scripts/resolve-env.sh`), and a
> behavior-complete bash test suite (`npm run test:release`) all exist and pass. See
> **Usage** below. The design rationale that follows is retained as the "why". Out of
> scope for 001 (candidate 002): a Marketplace listing and the Action's own moving-`v1`
> release workflow.
>
> **Naming note:** the idea started as "extract `derive-version`," but the reframe
> below concluded the real unit is the manifest-driven **release flow** (resolve-env
> + version derivation), of which derivation is one component — hence the name
> `snackbyte-release-flow-action`.

## Usage

Add `environments.json` at your repo root (one row per environment), then call the
Action from your workflow on push. It answers whether the branch is an environment and,
if so, derives and pushes its version **tag only** — never a commit.

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0            # full history + tags — the derivation refuses a shallow clone
- id: release
  uses: jeff-fichtner/snackbyte-release-flow-action@v1
  # inputs all default: branch=github.ref_name, manifest=./environments.json,
  # major-minor read from package.json's version (first two components)
- if: steps.release.outputs.is-env == 'true'
  run: echo "Deploying ${{ steps.release.outputs.tag }} (version ${{ steps.release.outputs.version }})"
```

To push the tag, the job needs `permissions: contents: write`.

**Inputs**: `branch` (default `github.ref_name`), `manifest` (default `./environments.json`),
`major-minor` (default: read `package.json`). **Outputs**: `is-env` (`"true"`/`"false"`),
`version` (`MM.P`, env pushes only), `tag` (`vMM.P<suffix>`, env pushes only). Full contract:
[`specs/001-extract-release-flow/contracts/action-io.md`](specs/001-extract-release-flow/contracts/action-io.md).

**Tests**: `npm run test:release` runs the behavior-complete matrix (B1–B15), the
parameterization deltas (P3–P5), resolve-env (P1–P2), the one-row-edit proof, and the
`action.yml` interface replay (I1–I2). CI runs the same suite plus a real `uses: ./` smoke
test on every push.

A **shareable GitHub Action** that turns a repo's `environments.json` manifest into
its release flow: it answers *"is this pushed branch a deployable environment?"* and,
if so, *"what version tag does this push get?"* — creating a tag, never a commit. It
is the extraction of the already-battle-tested manifest-driven release machinery from
`snackbyte-base`.

---

## The reframe: the manifest is the product, not the derivation

This started as "extract `derive-version.sh` into an Action." That's too small.
`derive-version.sh` is **one of six consumers** of a single convention — the
**environment manifest** (`environments.json`) — and the manifest is the actual
reusable invention. From the manifest file's own header: it is *"the single source of
truth for the release flow: the version derivation, the CI trigger, the build-time
identity bake, the noindex header, and the version chip all read this file."*

Every consumer reads that one file:

| Consumer (in `snackbyte-base`) | What it derives from the manifest |
|---|---|
| `scripts/derive-version.sh` | branch → `tagSuffix` for the derived tag |
| `.github/workflows/ci-cd.yml` `resolve-env` job | branch → *"is this an environment?"* (short-circuits non-env pushes) |
| `scripts/resolve-env.mjs` (build) | env name → baked build identity |
| `src/environments.ts` (server) | typed reader; `/api/version` reports it |
| noindex header + version chip | `noindex` / `isPublicFace` facets |
| `scripts/add-env.test.sh` | proves adding an env is a **one-row edit** |

**The design goal, stated in three separate files, is the reusable idea:** *"adding
an environment is a one-row edit to `environments.json`, and nothing else in the
reusable release tooling changes."* `derive-version.sh` is merely the piece that
happens to be pure bash+git and therefore trivially extractable. The Action should
ship the **manifest-driven release flow**, with derivation as a component — not the
derivation alone.

## What it is (and the mental model)

This is a **GitHub Action** in the same sense a VS Code extension is an extension: a
self-contained, distributable unit for a *host platform*. The parallel is exact:

| | VS Code extension | This tool |
|---|---|---|
| **Host platform** | VS Code | GitHub Actions runner |
| **Distribution channel** | VS Code Marketplace | GitHub Marketplace / `owner/repo@v1` ref |
| **Manifest** | `package.json` + `contributes` | `action.yml` (`inputs`/`outputs`/`runs`) |
| **How consumers use it** | install; it hooks into the editor | `uses: snackbyte/…@v1` in a workflow |
| **Versioning** | its own semver, tagged | its own semver, moving `v1` tag |

The key consequence: **an Action is a different distribution axis than an npm
package.** It shares almost none of the npm publish surface (no `exports` map, no
`files` allowlist, no tarball, no `npm publish --provenance`). Its "publish contract"
is `action.yml` + a moving `v1` tag + a Marketplace listing. So this was never a phase
of the npm-library template — it's its own kind of thing.

## Why it exists (the decision trail)

This came out of a conversation while setting up `snackbyte-npm-base` (the npm-library
template). The chain:

1. **`snackbyte-npm-base` got Spec Kit + a constitution + phase specs** — all about
   *npm packages* (publish contract, SemVer, provenance).
2. **Question raised:** is the versioning logic in `snackbyte-base` "ripe for a package
   (not necessarily npm)?"
3. **Finding:** `derive-version.sh` is a self-contained algorithm with a **formal
   contract** and a **15-row test matrix** — but it's a **bash+git** tool consumed by
   *CI workflows*, not an `import`able JS module. Its natural distribution is a GitHub
   Action, not npm.
4. **Reframe (the user's):** "I basically wrote a shareable GitHub Action — like a VS
   Code extension." Correct. It's already an Action, just living inline in one repo.
5. **Template question:** should there be a third template sibling
   (`snackbyte-action-base`)? **Decision: no** — a template earns itself at the *second*
   instance, and this is the only Action likely to be built. Ship the one Action
   standalone.
6. **Second reframe (the user's):** derive-version is too small; the real thing is the
   **manifest**, with derivation as a component. Hence this doc is manifest-centric.

## The manifest (the schema)

`environments.json` — one entry per environment the app deploys to. Facets are
independent single-purpose switches:

```jsonc
{
  "environments": [
    { "name": "production", "branch": "main", "isPublicFace": true,  "noindex": false, "tagSuffix": ""     },
    { "name": "staging",    "branch": "dev",  "isPublicFace": false, "noindex": true,  "tagSuffix": "-dev" }
  ]
}
```

- **`name`** — identity reported at `/api/version` and to app code.
- **`branch`** — the git branch that drives this environment.
- **`isPublicFace`** — hide dev-only affordances (e.g. the version chip) when false.
- **`noindex`** — emit `X-Robots-Tag: noindex`.
- **`tagSuffix`** — stamped on this environment's derived tags (`''`, `-dev`, …).

Rules: two entries sharing a `tagSuffix` is allowed but warned (their tags become
indistinguishable); a push to a branch not listed here is rejected by the derivation
and short-circuited by resolve-env. Tag format is fixed:
`v${MAJOR}.${MINOR}.${PATCH}${tagSuffix}` — MAJOR.MINOR from `package.json`, PATCH is
the derived global build id.

## What the flow does (the two components)

**1. resolve-env (the CI short-circuit).** The `on:` trigger can't read the manifest
(GitHub evaluates it before checkout), so a lightweight job reads `environments.json`
and answers whether the pushed branch is one of its environments. A push to a
non-environment branch short-circuits — nothing is built, tagged, or deployed, and no
expensive `npm ci` runs.

**2. derive-version (the tag).** The version PATCH is **not** stored in `package.json`
(which holds only MAJOR.MINOR); it's a global, monotonic build id derived from existing
tags. One rule, every environment:

- **Reuse** — if any number is already tagged on a commit carrying *this exact source
  tree* (any suffix), reuse it. The reuse key is the **tree hash**, not the commit SHA,
  so promoting dev→main reuses the dev number whether the promotion fast-forwards,
  merges, squashes, or rebases cleanly (all leave the tree identical). A rebase that
  absorbs divergent changes yields a *different* tree and correctly mints a new number.
- **Advance** — otherwise `max(patch over ALL vMM.* tags) + 1`. Max over every suffix
  makes two commits sharing a number impossible; gaps are expected and correct for a
  build id.

CI creates a **tag only** — never a commit or branch push. Guards: fail-loud on an
existing target tag, refuse shallow clones (they hide tags), anchored regex parsing,
same-branch run serialization.

## Source to extract from (`snackbyte-base`)

- **Derivation:** `scripts/derive-version.sh` (~120 lines bash)
- **resolve-env:** the `resolve-env` job in `.github/workflows/ci-cd.yml`, and the
  `is_env` one-liner in `scripts/add-env.test.sh` / `scripts/resolve-env.mjs`
- **Tests:** `scripts/derive-version.test.sh` (15 rows B1–B15) + `scripts/add-env.test.sh`
  (the one-row-edit proof), run via `npm run test:release`
- **Contract:** `specs/002-derived-tag-staging/contracts/versioning.md` (12-row matrix +
  invariants) and `specs/003-env-manifest/contracts/versioning.md`
- **Typed reader (reference, don't extract):** `src/environments.ts`

## Intended shape (deferred — NOT built)

When actually built, the work is small — the algorithm, the manifest, and the test
matrices are done. The only real change is **parameterization**: the machinery
currently hard-`require`s `./environments.json` and `./package.json`; those become
Action inputs.

- **`action.yml`** — a composite Action declaring:
  - `inputs.branch` — the pushed branch (default `github.ref_name`).
  - `inputs.manifest` — path to `environments.json` (default `./environments.json`),
    or the manifest JSON inline — decoupling the logic from the fixed filename.
  - `inputs.major-minor` — replaces the `package.json` read (default: read `package.json`).
  - `outputs.is-env` — the resolve-env short-circuit result.
  - `outputs.version` (`MM.P`) and `outputs.tag` (`vMM.P<suffix>`).
- **`derive-version.sh`** — extracted, sourcing `MM`/`suffix` from inputs, no algorithm
  change.
- **Test matrices** — extracted; they already accept `PKG_MM` and an injectable manifest
  via env, so they port with minimal edits.
- **Action's own versioning** — its own semver + a moving `v1` tag; a Marketplace listing
  if/when published.

## Related reusable patterns (observed, NOT extracted here)

These surfaced in the same review as adjacent-but-coupled reusable ideas. Documented so
they aren't lost; each has a reason it's not a clean copy-out.

- **The manifest *convention* itself** — the facet schema + "facets are independent
  single-purpose switches" philosophy + the tag-format contract. Reusable, but it has
  **two implementations kept in sync** (bash `node -p` in the script, typed TS in
  `src/environments.ts`). A shareable form is a JSON schema + spec doc, or a tiny reader
  library — a design decision, not a copy-paste. Bundling the *bash* half with this
  Action covers the release-flow use; the typed reader stays per-app.
- **The spin-up / resolver choreography** (`snackbyte-base` `SPIN-UP.md` + `init.mjs`) —
  the *pattern* generalizes: de-template (rename placeholders, strip the template guard,
  activate the inert `ci-cd.yml.disabled` → `ci-cd.yml`, clear inherited tags), and the
  **agent-safety STOP-gates** (ask before the `gh api` workflow-permissions escalation,
  ask before pushing to `main`, "committed-but-not-pushed is the correct stopping
  point"). But `init.mjs` (14KB) is coupled to *that app's* mode/render axes
  (`server`/`static`, `prerender`/`dynamic`). The **choreography** is worth documenting
  per template (it's already what `snackbyte-npm-base`'s Phase 0 spec calls for); the
  **script** is not a shared artifact.

## Where this is referenced

`~/Snackbyte/tools/project-setup/SETUP-CHECKLIST.md` lists "Add the manifest-driven
release flow" as a new-project step and points its source at this folder.

**None of the implementation above exists in this folder yet. This document is the whole
of it.**
