# snackbyte-release-flow-action

A GitHub Action that versions your releases from git tags. You list your release branches in an
`environments.json` file. On each push, the Action answers whether the pushed branch is one of
them and, if it is, creates and pushes a version tag on that commit. It never makes a commit.

- **One file decides what is releasable.** Adding an environment is a one-row edit to
  `environments.json`; nothing else in the release tooling changes.
- **Tags only.** No `chore: release` commits, so your release branches never diverge and a
  promotion from `dev` to `main` can always fast-forward.
- **Promotion keeps the number.** When `main` receives exactly the code `dev` already tagged, it
  gets the same version without the suffix: production ships the build staging tested.
- **Apps or libraries.** Automatic build numbers for deployable apps, or your `package.json`
  version for published packages.

## Quick start

**1. Add `environments.json`** at the repository root, one row per release branch:

```json
{
  "environments": [
    { "name": "production", "branch": "main", "tagSuffix": "" },
    { "name": "staging", "branch": "dev", "tagSuffix": "-dev" }
  ]
}
```

The Action reads `branch` and `tagSuffix`. Any other fields are yours: an app can keep its own
per-environment settings in the same rows.

**2. Add `.github/workflows/release.yml`:**

```yaml
name: release
on:
  push:
    branches: [main, dev]
permissions:
  contents: read
concurrency:
  group: release
  cancel-in-progress: false
  queue: max
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    outputs:
      is-env: ${{ steps.release.outputs.is-env }}
      tag: ${{ steps.release.outputs.tag }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: "24"
      - run: npm ci
      - run: npm run check
      - id: release
        uses: jeff-fichtner/snackbyte-release-flow-action@1b084a1fe780d9208c3eee923ef1a9494b0938bd # v1.2.4
  deploy:
    needs: release
    if: needs.release.outputs.is-env == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy $TAG"
        env:
          TAG: ${{ needs.release.outputs.tag }}
```

Each line is there for a reason:

- `branches: [main, dev]` lists only your release branches, so a push to any other branch runs
  nothing. GitHub bills every job as at least a minute; checks for work branches run once, on
  their pull request.
- `fetch-depth: 0` gives the Action every tag. It refuses a shallow clone, which would hide tags
  and produce a number that already exists.
- Your checks run before the Action, in the same job, so a failed check leaves no tag.
- `contents: write` lets the release job push the tag. The repository's default token, and every
  other job, stays read-only.
- One `concurrency` group for **all** release branches, with `queue: max`, makes releases run one
  at a time. Two releases deriving at once could otherwise pick the same number.
- The deploy is its own job, gated on `is-env`, because it holds your cloud credentials: those and
  the token that can push to your repository never share a job.

**3. Push.** With `"version": "1.4.0"` in `package.json`, the first push to `dev` is tagged
`v1.4.0-dev`. Fast-forwarding `main` to it tags the same commit `v1.4.0`. The next change on
`dev` becomes `v1.4.1-dev`.

**Requirements.** Node.js, git and bash on the runner: GitHub-hosted runners have all three. A
`package.json` supplies the version line, at the root or at the path you give.

## How the version is chosen

The `version-strategy` input picks how the number is chosen. Everything else works the same
either way.

| | `build-id` (default) | `package-json` |
|---|---|---|
| **For** | deployable apps | published libraries |
| **Version comes from** | the tags: `MAJOR.MINOR` from `package.json`, the last number counted automatically | `package.json`'s `version`, exactly as written |
| **`v1.4.7` means** | build 7 on the 1.4 line | you chose to release 1.4.7 |
| **Releasing the same version twice** | cannot happen: a new build gets a new number | fails until you bump `package.json` |

Under `build-id`, the last number is a build id shared by every environment:

- **Reuse.** If the exact same files were already tagged on any branch, the push gets that
  number. The match is on the content (git's tree hash), not the commit, so promoting by
  fast-forward, merge, squash or a clean rebase all keep the number.
- **Otherwise advance.** The push gets the highest number used so far on that `MAJOR.MINOR` line,
  plus one. Numbers can skip (a hotfix on `main` uses one), which is normal for a build id.

The tag is `v<MAJOR>.<MINOR>.<PATCH><tagSuffix>`, with an optional prefix for a second releasable
in the same repository (`tag-prefix`).

## Inputs and outputs

| Input | Default | What it does |
|---|---|---|
| `branch` | `github.ref_name` | The branch to look up in the manifest. |
| `manifest` | `./environments.json` | Path to the manifest, from the checkout root. |
| `package-json` | `./package.json` | Path to the `package.json` that holds the version, from the checkout root. |
| `major-minor` | read from `package-json` | Sets `MAJOR.MINOR` directly (`build-id` only). |
| `version-strategy` | `build-id` | `build-id` or `package-json`. |
| `tag-prefix` | empty | A tag namespace such as `client-node-`, for a second releasable in the same repository. |

| Output | What it holds |
|---|---|
| `is-env` | `"true"` if the branch is in the manifest, else `"false"`. |
| `version` | The version, e.g. `1.4.7` (environment pushes only; never carries the prefix). |
| `tag` | The tag that was pushed, e.g. `v1.4.7-dev` (environment pushes only). |

The full contract is in
[`specs/001-extract-release-flow/contracts/action-io.md`](specs/001-extract-release-flow/contracts/action-io.md).

## What fails, and why

The Action stops rather than guess. Each of these fails the step and creates no tag:

- a shallow clone;
- the target tag already exists (a re-run, or a library version that was not bumped);
- a manifest that is missing, is not valid JSON, or has no `environments` array;
- a version that is not SemVer (`package-json`), or a `MAJOR.MINOR` that is not two numbers;
- an invalid `version-strategy` or `tag-prefix`.

A push to a branch that is not in the manifest is not a failure: `is-env` is `"false"` and
nothing happens.

## More

- [`CONSUMING.md`](CONSUMING.md): complete recipes for an app, a library (with npm trusted
  publishing), a repository whose app lives in a subdirectory, and two releasables in one
  repository; the repository settings the flow relies on (branch protection, SHA pinning,
  Dependabot); and how to promote between branches.
- [`docs/background.md`](docs/background.md): why this exists and how it was designed.
- [`specs/`](specs/): the specification and contract for each feature.

## Pinning

Pin the Action to a full commit SHA with the release in a comment, as above, and let Dependabot
move the pin when a release lands. `@v1` also works and follows every non-breaking release, but
it is a tag that can be moved, which a repository requiring SHA pinning refuses. `v2` is reserved
for a breaking change to the inputs or outputs.

## Development

`npm test` runs the whole suite: bash scripts against throwaway git repositories, so it needs
bash, git and Node.js and nothing to install. CI runs the same suite plus a real `uses: ./` run of
the Action on every push. This repository versions itself with its own Action.

## License

MIT — see [`LICENSE`](LICENSE).
