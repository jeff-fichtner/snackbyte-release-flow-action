# Consuming this Action

How to add the manifest-driven release flow to any repo. Two recipes — an **app** and a
**library** — each copy-paste complete. If you are an agent wiring this into a new repo, pick the
recipe that matches the repo type and follow it end to end.

## Decide: app or library?

| Your repo is… | Use `version-strategy` | Why |
|---|---|---|
| A **deployable app / service** (deploys per branch; the version is an artifact identity) | `build-id` (the default — omit the input) | The PATCH is a global build counter; dev→main promotion reuses it. |
| A **published library / package** (people `npm install` it; the version is a compatibility promise) | `package-json` | The version must be intentional SemVer you set in `package.json`. A build counter can't be a SemVer promise. |

If unsure: does anything *depend on this repo's published version* to decide compatibility? Yes →
library (`package-json`). No → app (`build-id`).

---

## What every consumer needs (both recipes)

1. **`environments.json` at the repo root** — one row per release branch/channel. Minimum shape:

   ```jsonc
   {
     "environments": [
       { "name": "production", "branch": "main", "isPublicFace": true,  "noindex": false, "tagSuffix": ""     },
       { "name": "staging",    "branch": "dev",  "isPublicFace": false, "noindex": true,  "tagSuffix": "-dev" }
     ]
   }
   ```
   The flow reads only `branch` (is this a release branch? which one?) and `tagSuffix` (stamped on
   the tag). The other facets are for your app/library code. Adding a channel is a one-row edit.

2. **A workflow that checks out full history and calls the Action.** `fetch-depth: 0` is required —
   the derivation refuses a shallow clone (it would hide tags).

3. **`permissions: contents: write`** on the job — needed to push the tag.

---

## Recipe A — deployable app (`build-id`, the default)

`.github/workflows/release.yml`:

```yaml
name: release
on:
  push:
    branches: [main, dev]   # your environment branches
permissions:
  contents: write
concurrency:
  group: release-${{ github.ref_name }}   # serialize per branch — no two pushes race to a number
  cancel-in-progress: false
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with: { fetch-depth: 0 }
      - id: release
        uses: jeff-fichtner/snackbyte-release-flow-action@v1
        # all inputs default: branch=github.ref_name, manifest=./environments.json,
        # major-minor read from package.json, version-strategy=build-id
      - if: steps.release.outputs.is-env == 'true'
        run: |
          echo "Deploy ${{ steps.release.outputs.tag }}"
          # ... your deploy step, keyed off steps.release.outputs.tag ...
```

`package.json` supplies only MAJOR.MINOR (e.g. `"version": "1.4.0"` → the `1.4` line); the Action
derives the PATCH. Push to `main` → `v1.4.0`, next distinct build → `v1.4.1`, etc.

---

## Recipe B — published library (`version-strategy: package-json`)

`.github/workflows/release.yml`:

```yaml
name: release
on:
  push:
    branches: [main]        # your release channel(s)
permissions:
  contents: write           # push the tag
  id-token: write           # if you publish to npm with provenance
concurrency:
  group: release-${{ github.ref_name }}
  cancel-in-progress: false
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v5
        with: { node-version: "24", registry-url: "https://registry.npmjs.org" }
      - id: release
        uses: jeff-fichtner/snackbyte-release-flow-action@v1
        with:
          version-strategy: package-json   # <-- the one line that makes it a library release
      - if: steps.release.outputs.is-env == 'true'
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**The release ritual for a library:**
1. Edit `package.json` `version` to the SemVer you intend (e.g. `1.5.0` for a new feature).
2. Merge/push to `main`.
3. The Action tags `v1.5.0` and (via the `if`) `npm publish` releases `1.5.0`.
4. If you forget to bump, the tag `v1.5.0` already exists → the Action **fails loudly**. That is the
   guard, not a bug: bump `package.json` and push again.

Channels map to npm dist-tags via `tagSuffix`: a `next` channel with `tagSuffix: "-next"` tags
`v1.5.0-next` (and you'd `npm publish --tag next` accordingly).

---

## Inputs / outputs reference

**Inputs** (all optional): `branch` (default `github.ref_name`), `manifest` (default
`./environments.json`), `major-minor` (default: read `package.json`; ignored under `package-json`),
`version-strategy` (`build-id` default | `package-json`).

**Outputs**: `is-env` (`"true"`/`"false"` — gate your deploy/publish on this), `version` and `tag`
(set only for a release-branch push).

## Gotchas

- **Shallow clone → hard fail.** Always `fetch-depth: 0`. This is deliberate (a shallow clone hides
  tags and would mint a wrong number).
- **Non-release branch → clean short-circuit.** A push to a branch not in `environments.json` sets
  `is-env=false` and does nothing. Gate downstream steps on `is-env == 'true'`.
- **The Action tags; it does not deploy or publish.** The tag is the trigger; the deploy/`npm publish`
  is your step, keyed off the outputs.
- **Pin to `@v1`** for auto-updates within the major, or to a specific `@vX.Y.Z` / `@<sha>` to lock.
  (Note: a moving `v1` alias is feature 003 — until it's cut, pin to a SHA or branch.)
