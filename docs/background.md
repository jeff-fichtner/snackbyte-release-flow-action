# Background: why this exists and how it was designed

This is the design record behind the Action: where it came from, the reasoning that shaped it,
and what was deliberately left out. For using the Action, see the [README](../README.md) and
[`CONSUMING.md`](../CONSUMING.md).

The release machinery began inside `snackbyte-base`, a private app template, and was extracted
here so other repositories could use it. The idea started as "extract `derive-version`," but the
real unit is the manifest-driven **release flow** (resolve-env plus version derivation), of which
derivation is one component; hence the name `snackbyte-release-flow-action`.

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
| **Distribution channel** | VS Code Marketplace | an `owner/repo@<sha>` ref (a Marketplace listing is out of scope for now) |
| **Manifest** | `package.json` + `contributes` | `action.yml` (`inputs`/`outputs`/`runs`) |
| **How consumers use it** | install; it hooks into the editor | `uses: jeff-fichtner/snackbyte-release-flow-action@<sha>` in a workflow |
| **Versioning** | its own semver, tagged | its own semver, moving `v1` tag |

The key consequence: **an Action is a different distribution axis than an npm
package.** It shares almost none of the npm publish surface (no `exports` map, no
`files` allowlist, no tarball, no `npm publish --provenance`). Its "publish contract"
is `action.yml` + its release tags (and a moving `v1` tag). So this was never a phase
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
4. **Reframe (Jeff's):** "I basically wrote a shareable GitHub Action — like a VS
   Code extension." Correct. It's already an Action, just living inline in one repo.
5. **Template question:** should there be a third template sibling
   (`snackbyte-action-base`)? **Decision: no** — a template earns itself at the *second*
   instance, and this is the only Action likely to be built. Ship the one Action
   standalone.
6. **Second reframe (Jeff's):** derive-version is too small; the real thing is the
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
`${tagPrefix}v${MAJOR}.${MINOR}.${PATCH}${tagSuffix}` — MAJOR.MINOR from `package.json`,
PATCH is the derived global build id within the tag namespace, and `tagPrefix` (the
`tag-prefix` input, default empty) is the namespace a second releasable in the same repo
uses so the two never see each other's tags.

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
  makes two trees sharing a number impossible *across serialized derivations* — the scan
  and the tag push are not atomic, so the consuming workflow must serialize every
  environment branch of a releasable in one concurrency group (see CONSUMING.md). Reuse
  heals a duplicate that slips through. Gaps are expected and correct for a build id.

CI creates a **tag only** — never a commit or branch push. Guards: fail-loud on an
existing target tag, refuse shallow clones (they hide tags), anchored regex parsing,
per-releasable run serialization (one concurrency group per tag namespace, with
queueing), and a self-healing reuse that skips a build id another tree already owns.

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
  delete everything the setup checklist owns — including CI, which is installed per repo
  from `CONSUMING.md` rather than inherited — and clear inherited tags), plus the
  **agent-safety STOP-gates** (ask before pushing to `main`;
  "committed-but-not-pushed is the correct stopping point"). But `init.mjs` is coupled to
  *that app's* mode/render axes (`server`/`static`, `prerender`/`dynamic`). The
  **choreography** is worth documenting per template; the **script** is not a shared
  artifact.

## Where this is referenced

- `project-setup/SETUP-CHECKLIST.md` — "Add the manifest-driven release flow" is a
  new-project step and points consumers at `CONSUMING.md`.
- `snackbyte-base` — its `DEPLOY.md` and `SUBDIR-LAYOUT.md` defer the whole release-flow
  half here rather than restating it, and its spin-up resolver deliberately ships no
  workflow so apps wire one from `CONSUMING.md` instead of inheriting a stale copy.

