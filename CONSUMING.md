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

3. **`permissions: contents: write`** on the job (or the workflow) — this is what grants the tag
   push. The repository's own default stays read-only.

4. **Repo settings.** The default branch, branch protection and the SHA-pinning policy are not
   expressible in YAML — they are repo config, and the flow is unenforced or drifts without them.
   See **Repo settings** below.

---

## Repo settings the flow needs

The commands below run from a clone of the repository: `gh` fills `{owner}` and `{repo}` from
its remote (or from `GH_REPO=owner/repo`), and fails loudly outside one. Each needs admin on the
repo, which the creating account has.

### Workflow permissions — leave the repository default at read

The Action pushes the version tag with the job's `GITHUB_TOKEN`, and the job's
`permissions: contents: write` is what lets it. The repository's **Workflow permissions** setting
(`default_workflow_permissions`) is only the *default*: what a job gets when its workflow declares
no `permissions:` block. It does not cap an explicit grant. Keep it at `read`: a job then holds
write access only where its workflow asks for it.

Check it:

```bash
gh api 'repos/{owner}/{repo}/actions/permissions/workflow'
```

`"default_workflow_permissions":"read"` is the state you want. If it says `write`, set it back
(or web UI: **Settings → Actions → General → Workflow permissions → "Read repository contents and
packages permissions" → Save**):

```bash
gh api -X PUT 'repos/{owner}/{repo}/actions/permissions/workflow' -f default_workflow_permissions=read
```

A tag push that **403s** means the job's token lacks `contents: write`: the workflow declares no
`permissions:` block, or declares one without `contents: write` (declaring any permission sets
every unlisted one to `none`). Fix the workflow and re-run the failed job — nothing needs to be
reverted. Raising the repository default to `write` would also make the push work, and would hand
every job in the repository write access it never asked for.

### Default branch = `dev` — for a repo that promotes `dev` → `main`

Once `dev` exists, make it the default branch:

```bash
gh api -X PATCH 'repos/{owner}/{repo}' -f default_branch=dev
```

`main` stays the default only in a single-branch repo.

The default branch is the **integration branch** — where the latest work lands — not the branch
that is live. Which branch deploys production is set by CI, by branch name (`environments.json`),
never by the default branch. GitHub, though, aims everything automatic at the default branch: new
pull requests take it as their base, clones check it out, closing keywords close an issue only
when the PR merges into it, and **Dependabot security-update PRs always target it** — they ignore
`target-branch` in `dependabot.yml` ("security updates always use the default branch for the
repository", GitHub's Dependabot options reference). With `main` as the default, those PRs skip
staging, and merging one puts a commit on `main` that `dev` lacks: `main` diverges from `dev`, and
the next promotion can no longer fast-forward.

Known cost: Dependabot alerts and code search describe `dev`, not production. With fast-forward
promotion the gap is only the work not yet promoted, so promote security fixes promptly. A
`schedule:`-triggered workflow also runs from the default branch, so after the switch it runs
`dev`'s copy.

### Branch protection — the merge gate is repo config, not YAML

A workflow can *run* a quality gate on a PR; it cannot *require* it for merge. That is branch
protection. List your environment branches in the loop:

```bash
for BRANCH in main dev; do
  gh api -X PUT "repos/{owner}/{repo}/branches/${BRANCH}/protection" \
    --input - <<'JSON'
{
  "required_status_checks": { "strict": false, "contexts": ["validate (merge gate)"] },
  "required_pull_request_reviews": null,
  "enforce_admins": false,
  "restrictions": null,
  "allow_force_pushes": true
}
JSON
done
```

Each knob is deliberate:

- **`contexts: ["validate (merge gate)"]`** — the required check is the **job name**, not the
  workflow's UI label. Get it wrong and the check is never matched, so the gate silently
  enforces nothing.
- **`required_pull_request_reviews: null`** — do **not** require PRs. Requiring them breaks
  fast-forward promotion (a fast-forward is not a PR).
- **`enforce_admins: false`** — admin override stays available as an explicit at-own-risk
  escape hatch. It is also what lets an admin push a fast-forward to a commit that never ran the
  PR-only gate (a merge commit made on `dev`, say).
- **`allow_force_pushes: true`** — leaves room for a promotion that has to rewrite the branch. A
  plain fast-forward is not a force push and does not need it.

Branch protection is the *merge* gate. The authoritative backstop is your workflow's own
push-side gate: re-run the checks on the push and let the Action tag only on pass, so a tag —
and therefore a deploy — exists only if the gate passed. That holds for a PR merge, an admin
override, and a direct push alike.

#### Hardened variant — no admin override, no rewritten history

For a repo whose promotion never needs an admin override or a force push:

```bash
for BRANCH in main dev; do
  gh api -X PUT "repos/{owner}/{repo}/branches/${BRANCH}/protection" \
    --input - <<'JSON'
{
  "required_status_checks": { "strict": false, "contexts": ["validate (merge gate)"] },
  "required_pull_request_reviews": null,
  "enforce_admins": true,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
done
```

Three knobs change:

- **`enforce_admins: true`** — the gate binds admins too. Nothing lands on the branch unless that
  exact commit already carries a passing `validate (merge gate)`.
- **`allow_force_pushes: false`** — the branch's history cannot be rewritten.
- **`allow_deletions: false`** — the branch cannot be deleted.

What it costs: **promote through a pull request**. A command-line fast-forward
(`git push origin dev:main`) is not a force push, so `allow_force_pushes: false` does not stop it.
The required check does: it is evaluated on the exact commit pushed, `enforce_admins: true` now
applies it to admins as well, and a commit made on `dev` by merging a PR has never been checked,
because the gate runs on `pull_request`. Open a `dev` → `main` PR instead: the gate runs on
`dev`'s head, and when `main` has nothing `dev` lacks, merging it leaves the tree identical, so
`main` reuses `dev`'s number (see **How the version is derived**). To make that PR refuse a `dev`
that has not absorbed a `main` hotfix, set `"strict": true` — the "require branches to be up to
date before merging" setting the promotion rule below relies on.

### Pin every action to a commit SHA — and make the repo require it

Every `uses:` in the recipes below names a full commit SHA, with the release it is in a comment:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

A tag is a pointer its owner can move, and whatever it points at runs with your job's token —
here, one that can push to your repo. A commit SHA cannot be moved. Two pieces of setup make that
hold for every workflow, not only the ones you remember to pin.

**1. Require it.** The repository's Actions policy can refuse any `uses:` that is not a full SHA.
Turn it on only after **every workflow file that runs on any branch** is pinned — an unpinned one
then fails at job setup. To list what is still unpinned on the checked-out branch (repeat on each
branch that carries workflows):

```bash
grep -rnE 'uses:[[:space:]]' .github/workflows | grep -vE 'uses:[[:space:]]+\./' | grep -vE '@[0-9a-f]{40}([[:space:]]|$)'
```

No output means every remote `uses:` is pinned (a local `./` action needs no pin). Then:

```bash
ALLOWED="$(gh api 'repos/{owner}/{repo}/actions/permissions' --jq '.allowed_actions')"
gh api -X PUT 'repos/{owner}/{repo}/actions/permissions' -F enabled=true -f allowed_actions="${ALLOWED:?could not read allowed_actions}" -F sha_pinning_required=true
```

The block reads the repo's current `allowed_actions` and sends it back unchanged, so the call
changes only the pinning rule. Sending `all` instead would silently widen a `selected` or
`local_only` policy. Read it back with `gh api 'repos/{owner}/{repo}/actions/permissions'`:
expect `"sha_pinning_required":true` beside your original `allowed_actions`.

**2. Let Dependabot move the pins.** A pinned SHA never updates itself; Dependabot rewrites the
SHA and its comment when a new release lands. `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /                 # Dependabot finds .github/workflows from here
    target-branch: dev           # the integration branch; omit in a single-branch repo
    schedule:
      interval: weekly
    groups:
      actions-minor-and-patch:   # minor and patch bumps arrive together, in one PR
        patterns: ['*']
        update-types: ['minor', 'patch']
```

A major bump matches no group, so it arrives in a PR of its own: a major can change what an
action does with the job's token, so it gets a deliberate review instead of riding along with
routine bumps.

Two things about Dependabot that this file cannot change: it reads `dependabot.yml` from the
**default branch** only, so the file takes effect once it is there (one more reason the default
branch should be `dev`); and **security-update PRs ignore `target-branch`** — they always target
the default branch, and the options in this entry do not apply to them.

---

## How the version is derived

The pushed branch is used only as **data** — its `tagSuffix`, looked up in `environments.json`.
One rule covers every environment:

1. **Reuse** if *any* version number is already tagged on a commit carrying *this exact source
   tree*, whatever suffix it bears. The key is the **repository tree hash**, not the commit SHA, so
   a promotion reuses the number whether it fast-forwards, merges, squashes, or rebases cleanly;
   the number is stamped with this environment's suffix, so the same content ends up carrying both
   tags. A rebase that absorbs divergent changes yields a different tree and mints a new number.
2. **Otherwise advance** to `max(all vMM.* tags) + 1`. The max is over **every** tag — every
   suffix, every environment — so two distinct trees cannot share a number **provided the
   derivations are serialized**. The tag scan and the tag push are not atomic: two runs that both
   read the tag set before either pushes will both mint the same number. That is what the
   concurrency group in every recipe below is for, and why it is keyed on the *releasable* rather
   than the branch. Should a duplicate reach the tag set anyway, step 1 heals it — a number whose
   tag for this environment already belongs to a different tree is skipped, with a warning
   annotation, instead of being reused into a permanently wedged promotion.

A fresh repo with no tags mints `vMM.0` on its first push, however many commits precede it.

**Two accepted trade-offs**, both intentional:

- The PATCH is **not in the repo** — it lives in the tags, the built artifact, and whatever your
  app reports at runtime. `package.json` holds only `MAJOR.MINOR`.
- Patch numbers **have gaps**. A number consumed on one branch raises the next mint on the other,
  so a channel can skip ahead. The patch is a build id, not a release counter; gaps are normal and
  informative.

**CI commits nothing.** The Action creates a tag on the pushed commit and pushes only the tag —
no `chore: release` commit, no `[skip ci]`, no `npm version`. Because nothing is committed back,
release branches never diverge: fast-forward, merge, and PR promotion all work with no resync.

### Promotion between channels (e.g. `dev` → `main`)

Promote by bringing the downstream branch up to the upstream commit so it is a **fast-forward**.
That guarantees the existing suffixed tag is on the new HEAD, so the promoted branch **reuses that
number** (dropping the suffix) rather than minting a fresh one — production ships the exact number
staging validated.

The fast-forward requirement also makes divergent code **unpromotable**: if `dev` has not absorbed
a `main` hotfix, it cannot fast-forward, so it cannot carry stale code to production under a wrong
number. Enforce it with branch protection's "require branches up to date before merging", and
follow it as a reflex regardless.

### Why no personal access token is needed

The tag is pushed with the default `GITHUB_TOKEN`. A `GITHUB_TOKEN`-pushed tag does **not**
trigger another workflow run (GitHub's recursion guard). That is fine, and deliberate: gate your
deploy as a chained `needs:` job in the *same* run, so no second event is required.

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
  # Per RELEASABLE, not per branch. Under build-id the number is global across every environment
  # branch, so `release-${{ github.ref_name }}` would let a main push and a dev push race to the
  # same number for different trees — and the duplicate wedges the next promotion.
  group: release
  cancel-in-progress: false
  queue: max                # let runs wait their turn. Without this GitHub keeps only ONE run
                            # waiting, and the next push throws it out — losing that release.
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      # Every `uses:` is pinned to a commit SHA, its release in the comment; Dependabot moves the
      # pins (see "Pin every action to a commit SHA").
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with: { fetch-depth: 0 }
      - id: release
        uses: jeff-fichtner/snackbyte-release-flow-action@c954bf30e67c3419d8694904cf9c4dbc61addf77 # v1.2.0
        # all inputs default: branch=github.ref_name, manifest=./environments.json,
        # package-json=./package.json (supplies major-minor), version-strategy=build-id
      - if: steps.release.outputs.is-env == 'true'
        run: |
          echo "Deploy ${{ steps.release.outputs.tag }}"
          # ... your deploy step, keyed off steps.release.outputs.tag ...
```

`package.json` supplies only MAJOR.MINOR (e.g. `"version": "1.4.0"` → the `1.4` line); the Action
derives the PATCH. Push to `main` → `v1.4.0`, next distinct build → `v1.4.1`, etc.

> **On the group name.** Concurrency groups are scoped to the *repository*, so `release` is shared
> with any other workflow that happens to use it. If that happens, err toward leaving it shared:
> two unrelated things serializing costs only wall-clock. The failure that matters is the opposite
> one — **one releasable split across two groups**, which is exactly the bug this recipe fixes. So
> if you split this workflow in two (say `release.yml` and `release-dev.yml`), keep both on the
> *same* group name.
>
> (`queue: max` can hold 100 waiting runs. You will not hit that.)

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
  group: release            # per releasable (see Recipe A) — one group, every release channel
  cancel-in-progress: false
  queue: max
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with: { node-version: "24", registry-url: "https://registry.npmjs.org" }
      - id: release
        uses: jeff-fichtner/snackbyte-release-flow-action@c954bf30e67c3419d8694904cf9c4dbc61addf77 # v1.2.0
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

## Consuming from a subdirectory (the app is not at the repo root)

GitHub only discovers workflows in the **repo root** `.github/workflows/`, so a monorepo runs
one workflow at the root and points it into the subdirectory. Three edits, all mechanical:

1. **Run npm from the subdirectory.** Add a `defaults` block, at the job level on the jobs that
   run npm or once at the top level:

   ```yaml
   defaults:
     run:
       working-directory: <app>
   ```

2. **Tell the Action where the manifest and the `package.json` are.** `working-directory` affects
   only `run:` steps, so it does **not** reach a `uses:` step — the Action runs at the checkout
   root and resolves both files from there. Pass both paths explicitly:

   ```yaml
   - uses: jeff-fichtner/snackbyte-release-flow-action@c954bf30e67c3419d8694904cf9c4dbc61addf77 # v1.2.0
     with:
       manifest: <app>/environments.json
       package-json: <app>/package.json
   ```

   The Action reads the manifest for `branch` → `tagSuffix`, and the `package.json` for the
   version (`MAJOR.MINOR` under `build-id`; the whole version under `package-json`). Its git calls
   are cwd-independent — git walks up to `.git` itself. Omit `package-json:` and the Action reads
   the **root** `package.json` — a hard failure if there is none, the wrong version line if there
   is one.

3. **Fix the npm cache key.** `cache: 'npm'` with no path assumes a root lockfile:

   ```yaml
   - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
     with:
       node-version: '24'
       cache: 'npm'
       cache-dependency-path: <app>/package-lock.json
   ```

**Optional — scope the triggers** with `paths:` (`<app>/**` plus the workflow file itself) so
unrelated changes elsewhere in the repo don't trigger a run. Know the trade-off: a push touching
only files outside `<app>/` then produces no run, hence no tag and no deploy. That is usually
what you want — nothing about the app changed — but it couples the release cadence to changes
under `<app>/` rather than to every push.

### Two releasables in one repository

Git tags are repo-global, so a repository that holds **two releasables** — say a deployed app under
`packages/service/` and a published library under `packages/client-node/` — would, out of the box,
have them share one tag namespace: both start at `v0.1.0`, the second to land fails the
exists-guard, and the app's "highest `vMM.*`" scan would count the library's tags. The
**`tag-prefix`** input gives each releasable its own namespace. The recipe:

**One workflow per releasable, both at the repo root.** Each has its own
`defaults.run.working-directory`, its own `manifest:` and `package-json:`, its own `tag-prefix`
(the library's; the app keeps the bare `v`), and a `paths:` filter so a change under one
directory does not cut a release of the other. The app:

```yaml
# .github/workflows/release-service.yml
name: release-service
on:
  push:
    branches: [main, dev]
    paths: ['packages/service/**', '.github/workflows/release-service.yml']
permissions:
  contents: write
concurrency:
  # One group per RELEASABLE, never per branch. The app and the library get SEPARATE groups:
  # their tag namespaces cannot collide, so neither should ever wait on the other.
  group: release-service    # the app owns the bare `v…` namespace
  cancel-in-progress: false
  queue: max
defaults:
  run:
    working-directory: packages/service
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with: { fetch-depth: 0 }
      - id: release
        uses: jeff-fichtner/snackbyte-release-flow-action@c954bf30e67c3419d8694904cf9c4dbc61addf77 # v1.2.0
        with:
          manifest: packages/service/environments.json
          package-json: packages/service/package.json   # MAJOR.MINOR from the service's own file
          # tag-prefix omitted: the app owns the bare v0.1.N namespace
      - if: steps.release.outputs.is-env == 'true'
        run: echo "Deploy ${{ steps.release.outputs.tag }}"   # v0.1.N / v0.1.N-dev
```

The library:

```yaml
# .github/workflows/release-client-node.yml
name: release-client-node
on:
  push:
    branches: [main]
    paths: ['packages/client-node/**', '.github/workflows/release-client-node.yml']
permissions:
  contents: write
  id-token: write
concurrency:
  # The library's own group — separate from the app's, per the note in release-service.yml.
  group: release-client-node   # keyed to this releasable, whose namespace is `client-node-v…`
  cancel-in-progress: false
  queue: max
defaults:
  run:
    working-directory: packages/client-node
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: "24"
          registry-url: "https://registry.npmjs.org"
          cache: npm
          cache-dependency-path: packages/client-node/package-lock.json
      - id: release
        uses: jeff-fichtner/snackbyte-release-flow-action@c954bf30e67c3419d8694904cf9c4dbc61addf77 # v1.2.0
        with:
          manifest: packages/client-node/environments.json
          package-json: packages/client-node/package.json   # the version that gets tagged + published
          version-strategy: package-json
          tag-prefix: client-node-    # tags client-node-v<version>; invisible to the app's scans
      - if: steps.release.outputs.is-env == 'true'
        run: npm publish --access public   # publishes packages/client-node's version
```

What the prefix does and does not do:

- **Namespaces are mutually blind.** The library's derivation reads only `client-node-v…` tags for
  its exists-guard; the app's reads only bare `v…` tags for its reuse and max. `v0.1.0` and
  `client-node-v0.1.0` on the same commit is the normal first-push state, not a collision. The
  `tag` output carries the prefix; the `version` output never does.
- **Two build-id releasables** work the same way — give each its own prefix (`service-`,
  `worker-`); their PATCH counters advance independently.
- **The `paths:` trade-off.** A push touching only files outside both directories triggers
  *neither* workflow — a change to a shared root file (a lockfile, a shared config) cuts no release
  unless that path is listed. List shared paths under the workflow that should react to them, or
  accept that such changes ship with the next in-directory change.
- **The promotion-reuse key is the *repository* tree hash**, not the subdirectory's. A
  library-only change alters the tree for the app too. Under `build-id` that is harmless — the
  app's workflow does not run without a `paths:` match, and if it did run it would mint a fresh,
  still-unique number rather than a wrong one — but it is why the `paths:` filter is part of the
  recipe, not an optional nicety.
- **Each releasable names its own `package.json`.** Both `manifest:` and `package-json:` are
  resolved from the checkout root (step 2 above); with `package-json:` omitted the Action would
  read the root file for both, and the library would tag and publish the wrong version.

---

## Inputs / outputs reference

**Inputs** (all optional): `branch` (default `github.ref_name`), `manifest` (default
`./environments.json`), `package-json` (default `./package.json`; the file whose `version` is
read, resolved from the checkout root like `manifest` — set it for a subdirectory releasable),
`major-minor` (default: read the `package-json` file; ignored under `package-json` strategy),
`version-strategy` (`build-id` default | `package-json`), `tag-prefix` (default `""`; e.g.
`client-node-` — the tag becomes `<prefix>v<version><suffix>` and the derivation sees only tags
with that prefix; allowed `[A-Za-z0-9._-]`, starting alphanumeric, ending in `-`).

**Outputs**: `is-env` (`"true"`/`"false"` — gate your deploy/publish on this), `version` and `tag`
(set only for a release-branch push; `tag` carries any `tag-prefix`, `version` never does).

## Gotchas

- **Shallow clone → hard fail.** Always `fetch-depth: 0`. This is deliberate (a shallow clone hides
  tags and would mint a wrong number).
- **Non-release branch → clean short-circuit.** A push to a branch not in `environments.json` sets
  `is-env=false` and does nothing. Gate downstream steps on `is-env == 'true'`.
- **The Action tags; it does not deploy or publish.** The tag is the trigger; the deploy/`npm publish`
  is your step, keyed off the outputs.
- **Pin to a commit SHA, with the release in a comment** —
  `@c954bf30e67c3419d8694904cf9c4dbc61addf77 # v1.2.0`, as every recipe here does, and let
  Dependabot move the pin when a release lands (see **Pin every action to a commit SHA**). The
  `v1` alias still exists and is fix-forwarded onto each non-breaking release, so `@v1` follows
  the major on its own — but it is a moving tag, exactly what `sha_pinning_required` refuses.
  `v2` is reserved for an intentional breaking change to the inputs/outputs.
