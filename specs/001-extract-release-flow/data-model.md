# Phase 1 Data Model

This feature has no database. Its "data model" is the manifest schema, the tag grammar, and
the Action's I/O — the contract entities the logic reads and produces. All are inherited from
`snackbyte-base` and restated here as the port's reference.

## Entity: Environment (manifest row)

One entry in `environments.json`'s `environments` array. Facets are independent,
single-purpose switches (Constitution Principle IV) — no facet implies another.

| Field | Type | Meaning | Used by this feature? |
|---|---|---|---|
| `name` | string | Identity reported at `/api/version` and to app code | No (consumed by app, not the flow) |
| `branch` | string | The git branch that drives this environment | **Yes** — resolve-env match + suffix lookup |
| `isPublicFace` | boolean | Hide dev-only affordances when false | No (app-side) |
| `noindex` | boolean | Emit `X-Robots-Tag: noindex` | No (app-side) |
| `tagSuffix` | string | Stamped on this environment's derived tags (`""`, `-dev`, …) | **Yes** — appended to the derived tag |

**Validation / rules**:
- A `branch` not present in any row is **not an environment**: resolve-env returns false;
  derivation refuses (fail-loud).
- Two rows sharing a `tagSuffix` is **permitted but warned** (their tags become
  indistinguishable) — non-blocking.
- The flow reads only `branch` and `tagSuffix`; the other three facets exist for app-side
  consumers and MUST be preserved by the manifest untouched (one-row-edit integrity).

## Entity: Version tag

The single output artifact. Fixed grammar (Constitution Principle III):

```
tag     = "v" MAJOR "." MINOR "." PATCH SUFFIX
MAJOR   = integer   (from package.json version, component 1)
MINOR   = integer   (from package.json version, component 2)
PATCH   = integer   (derived global build id)
SUFFIX  = "" | "-" <[A-Za-z0-9._-]+>   (the environment's tagSuffix)
```

Anchored parse regex (suffix-agnostic, one regex serves reuse + mint):
`^v<MM-escaped>\.([0-9]+)(-[A-Za-z0-9._-]+)?$`

**Derivation rules** (see [contracts/versioning.md](./contracts/versioning.md) for the full
behavior matrix):
- **Reuse**: if any `vMM.*` tag sits on a commit whose `^{tree}` equals `HEAD^{tree}`, reuse
  that PATCH (highest wins on ties). Keyed on **tree**, not SHA (Principle II).
- **Advance**: else PATCH = `max(PATCH over all vMM.* tags, every suffix) + 1` (empty set →
  0, the first tag).
- **Collision**: if the resulting tag already exists → fail, create nothing (Principle V).

## Entity: Source tree

The content identity of `HEAD` (`git rev-parse "HEAD^{tree}"`). The reuse key. Distinct
commits with an identical tree (fast-forward, merge that keeps both sides only when trees
coincide, squash, clean rebase) share a tree and therefore a build number; a merge/rebase
that absorbs divergent content yields a different tree and a fresh number.

## Entity: Action inputs (parameterization surface)

The decoupling this feature adds (see [contracts/action-io.md](./contracts/action-io.md)).

| Input | Default | Replaces (in source) |
|---|---|---|
| `branch` | `${{ github.ref_name }}` | `$1` / `$GITHUB_REF_NAME` positional |
| `manifest` | `./environments.json` | hard-coded `require('./environments.json')` |
| `major-minor` | (read `package.json`) | hard-coded `require('./package.json')` |

## Entity: Action outputs (consumable results)

| Output | Shape | Producer |
|---|---|---|
| `is-env` | `"true"` \| `"false"` | resolve-env |
| `version` | `MM.P` (e.g. `0.1.4`) | derive-version (env pushes only) |
| `tag` | `vMM.P<suffix>` (e.g. `v0.1.4-dev`) | derive-version (env pushes only) |

**State/flow**: resolve-env runs first and gates. `is-env=false` → no derivation, no tag,
`version`/`tag` unset. `is-env=true` → derivation runs, producing `version`+`tag` or failing
loudly (existing tag / shallow / unknown branch).
