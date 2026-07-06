# Contract: Action I/O delta (version-strategy)

Extends 001's [action-io.md](../../001-extract-release-flow/contracts/action-io.md). Only the delta
is shown.

## New input

| Name | Required | Default | Description |
|---|---|---|---|
| `version-strategy` | no | `build-id` | How the version number is chosen. `build-id` = the global monotonic, tree-reused PATCH (for deployable apps). `package-json` = tag the `package.json` `version` verbatim (for published libraries, intentional SemVer). |

## Semantics by strategy

**`build-id`** (default): unchanged from 001. `version = MM.P` where `MM` is `major-minor` (or read
from `package.json`) and `P` is reuse-on-tree-else-max+1. Tag `vMM.P<suffix>`.

**`package-json`**: `version = <package.json version, verbatim>`. Tag `v<version><suffix>`. No
build-id derivation, no tree reuse, no max+1.
- The `major-minor` input is **ignored** under this strategy (it is a build-id concept). Documented
  so a consumer isn't surprised that setting it has no effect.
- An existing target tag still FAILS loudly — under this strategy that means "you must bump
  `package.json` before releasing again" (the SemVer-discipline guard).
- The version string is used verbatim, including any prerelease (`1.4.0-rc.1` → `v1.4.0-rc.1`); the
  Action does not parse, validate, or re-compose SemVer.

**Invalid value**: any `version-strategy` other than `build-id`/`package-json` FAILS loudly and
creates nothing.

## Unchanged

Inputs `branch`, `manifest`, `major-minor`; outputs `is-env`, `version`, `tag`. resolve-env,
tag-only, shallow refusal, unknown-branch refusal, dup-suffix warning, and the git-identity fallback
are strategy-independent.

## Consumer usage (illustrative)

```yaml
# A library: intentional SemVer from package.json, publish on the tag.
- uses: actions/checkout@v5
  with: { fetch-depth: 0 }
- id: release
  uses: jeff-fichtner/snackbyte-release-flow-action@v1
  with:
    version-strategy: package-json   # <-- the one line that makes it a library release
- if: steps.release.outputs.is-env == 'true'
  run: npm publish   # publishes package.json's version; the tag marks the release
```
