# Contract: Action I/O (`action.yml`)

The public interface consumers reference as `uses: <owner>/snackbyte-release-flow-action@v1`.
This is the contract; the exact YAML is produced in implementation.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `branch` | no | `${{ github.ref_name }}` | The pushed branch to resolve against the manifest. |
| `manifest` | no | `./environments.json` | Path to the environment manifest (relative to the consumer's checkout). |
| `major-minor` | no | *(read `package.json`)* | Override for the `MAJOR.MINOR` version line. When unset, the Action reads the consumer's `package.json` `version` and uses its first two components. |

Notes:
- The consumer MUST check out with full history and tags (`fetch-depth: 0`) for the
  derive path; the Action refuses a shallow checkout (fail-loud). The resolve-env-only path
  needs only the manifest (`fetch-depth: 1` is sufficient if a consumer calls it in isolation).
- The consumer MUST grant `contents: write` for the tag push on environment pushes;
  `contents: read` suffices for resolve-env alone.

## Outputs

| Name | When set | Value | Consumer use |
|---|---|---|---|
| `is-env` | always | `"true"` / `"false"` | Gate downstream build/deploy steps. |
| `version` | env push only | `MM.P` (e.g. `0.1.4`) | Bake build identity / label artifacts. |
| `tag` | env push only | `vMM.P<suffix>` (e.g. `v0.1.4-dev`) | Reference the created tag for deploy. |

## Behavior contract

1. Resolve `branch` against `manifest`. If not an environment: set `is-env=false` and STOP
   (no derivation, no tag, non-error exit — this is the normal short-circuit).
2. If an environment: set `is-env=true`, then derive:
   - Warn (non-blocking) on duplicate `tagSuffix` across environments.
   - Refuse (fail, exit non-zero, create nothing) if: history is shallow; the target tag
     already exists.
   - Compute PATCH by reuse-on-tree else global-max+1; form `tag = vMM.P<suffix>`.
   - Create the annotated tag and push **only** that tag — never a commit or branch.
   - Set `version` and `tag` outputs.
3. An unknown branch reaching the derive path (bypassing step 1) fails loudly.

## Invocation example (consumer workflow, illustrative)

```yaml
- uses: actions/checkout@v6
  with: { fetch-depth: 0 }        # full history + tags
- id: release
  uses: <owner>/snackbyte-release-flow-action@v1
  # inputs all default: branch=github.ref_name, manifest=./environments.json,
  # major-minor read from package.json
- if: steps.release.outputs.is-env == 'true'
  run: echo "Deploying ${{ steps.release.outputs.tag }}"
```

## Compatibility

- Distributed as a composite Action referenced at a moving `v1` tag (Principle VI). No npm
  package, no `dist/` bundle.
- Behavior MUST equal the `snackbyte-base` source except deliberate, documented changes
  (Principle VII). The version behavior is pinned by [versioning.md](./versioning.md).
