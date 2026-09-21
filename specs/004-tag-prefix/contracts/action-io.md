# Contract: Action I/O delta (tag-prefix)

Extends 001's [action-io.md](../../001-extract-release-flow/contracts/action-io.md) and 002's
[action-io.md](../../002-version-strategy/contracts/action-io.md). Only the delta is shown.

## New input

| Name | Required | Default | Description |
|---|---|---|---|
| `tag-prefix` | no | `""` | Optional tag-namespace prefix, e.g. `client-node-`. The tag becomes `<prefix>v<version><suffix>`; the derivation reads only tags carrying this exact prefix. Allowed: empty, or `[A-Za-z0-9._-]` starting alphanumeric and ending in `-`. |

## Semantics

**Prefix `""`** (default): unchanged from 001/002. Tag `v<version><suffix>`; reuse and mint read
the bare `vMM.*` tags. Prefixed tags in the repository are invisible.

**Prefix set** (e.g. `client-node-`):
- Tag `client-node-v<version><suffix>`. The `tag` output carries the prefix; the `version` output
  is the bare version (`MM.P` under `build-id`, the `package.json` version under `package-json`).
- Reuse (tree-keyed) and mint (max+1) read only `client-node-vMM.*` tags, anchored. Bare tags and
  tags with any other prefix are invisible — even when they sit on the same commit or tree.
- The exists-guard checks the full prefixed tag: `client-node-v1.4.0` existing fails loudly; the
  bare `v1.4.0` existing does not block `client-node-v1.4.0`.
- Applies identically under both `version-strategy` values.

**Invalid value**: a prefix that is non-empty and does not match `^[A-Za-z0-9][A-Za-z0-9._-]*-$`,
or that git rejects as a tag-name fragment (`git check-ref-format`), FAILS loudly before any
resolve/guard/tag work and creates nothing. Examples refused: `client-node` (no trailing `-`),
`bad prefix-` (space), `-` (leading dash), `a..b-` (git rule).

## Unchanged

Inputs `branch`, `manifest`, `major-minor`, `version-strategy`; output `is-env`. resolve-env, the
manifest format, the suffix logic, tag-only, shallow refusal, unknown-branch refusal, dup-suffix
warning, and the git-identity fallback are prefix-independent.

## Consumer usage (illustrative)

```yaml
# The library's workflow in a repo that also deploys an app: its own tag namespace.
- id: release
  uses: jeff-fichtner/snackbyte-release-flow-action@v1
  with:
    manifest: packages/client-node/environments.json
    version-strategy: package-json
    tag-prefix: client-node-          # tags client-node-v<version>; the app keeps bare v tags
```
