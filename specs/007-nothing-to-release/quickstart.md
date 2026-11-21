# Quickstart: Recipe B with the look-up

The draft of CONSUMING.md's Recipe B once a release carries 007 (task T010). The recipe pins
that release's commit SHA, which exists only after this feature merges, so the pin below is left
for T010 to fill in (`RELEASE_SHA # vX.Y.Z`).

```yaml
name: release
on:
  push:
    branches: [main]        # your release channel(s)
permissions:
  contents: read
concurrency:
  group: release            # per releasable (see Recipe A) — one group, every release channel
  cancel-in-progress: false
  queue: max
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write       # push the tag
    outputs:
      tag: ${{ steps.release.outputs.tag }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with: { fetch-depth: 0 }
      - id: lookup
        uses: jeff-fichtner/snackbyte-release-flow-action@RELEASE_SHA # vX.Y.Z
        with:
          version-strategy: package-json
          mode: lookup      # a push without a version bump reports released-as instead of failing
      # Nothing to release: make sure the version actually reached npm. A publish that failed
      # stays red until it is re-run or the version is bumped. Drop this step for a private package.
      - if: steps.lookup.outputs.released-as != ''
        env:
          VERSION: ${{ steps.lookup.outputs.version }}
        run: |
          name="$(node -p "require('./package.json').name")"
          if [ "$(npm view "${name}@${VERSION}" version 2>/dev/null)" != "$VERSION" ]; then
            echo "::error::${name}@${VERSION} is tagged but not on npm. Re-run its release's publish job, or bump the version."
            exit 1
          fi
      - if: steps.lookup.outputs.released-as == ''
        uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with: { node-version: "24", cache: npm }
      - if: steps.lookup.outputs.released-as == ''
        run: npm ci
      - if: steps.lookup.outputs.released-as == ''
        run: npm run check  # the push-side gate: a failed check leaves no tag
      - id: release
        if: steps.lookup.outputs.released-as == ''
        uses: jeff-fichtner/snackbyte-release-flow-action@RELEASE_SHA # vX.Y.Z
        with:
          version-strategy: package-json
          expect-tag: ${{ steps.lookup.outputs.tag }}
  publish:
    needs: release
    if: needs.release.outputs.tag != ''
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write       # npm trusted publishing: the job's OIDC token is the npm credential
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with: { node-version: "24", registry-url: "https://registry.npmjs.org" }
      - run: npm publish
```

Ritual step 4 then reads: if you don't bump, the look-up finds `v1.5.0` on an earlier commit,
says "Nothing to release", and the run is green with nothing tagged or published. A real
collision (the tag on another line of history, or a re-run of the release push) still fails.

The publish job runs only when the tag step ran: its `tag` output is empty when that step was
skipped. On a channel whose branch is not in the manifest the look-up reports `is-env` false and an
empty `released-as`, so the checks run but the tag step makes nothing; the trigger's branch list
keeps such pushes out in the first place.

**Check that it works**: the first merge without a bump shows a "Nothing to release" notice, the
setup, install, check and tag steps as skipped, no publish job, and a green run.
