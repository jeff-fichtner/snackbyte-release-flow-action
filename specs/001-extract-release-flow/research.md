# Phase 0 Research: Parameterization decisions

The algorithm and behavior are settled (proven in `snackbyte-base`). "Research" here is the
small set of decisions the *extraction into a parameterized Action* forces. There are no open
NEEDS CLARIFICATION from the spec; each decision below has a clear default from the source.

## D1 — How the manifest is supplied

**Decision**: Accept `inputs.manifest` as a **path** (default `./environments.json`). Support
inline JSON as a follow-on only if a consumer needs it; do not block 001 on it.

**Rationale**: The source hard-codes `require('./environments.json')`. Every real consumer
commits an `environments.json` at repo root, so a path input with that default is a drop-in
match and keeps the `node -p`/`node -e` reads a one-line change (resolve the path from the
input instead of the literal). Inline JSON adds a "is this a path or a blob?" branch for no
current consumer.

**Alternatives considered**: (a) Inline-JSON-only — rejected: forces consumers to marshal
JSON into a workflow input. (b) Path-or-inline from day one (README's stretch idea) —
deferred: real but not needed for the extraction; can be added without breaking the path form.

## D2 — Where MAJOR.MINOR comes from

**Decision**: `inputs.major-minor` overrides; default is to read the repo's `package.json`
version and take the first two dotted components (patch field ignored), exactly as the source
does.

**Rationale**: Preserves source behavior as the default while decoupling the algorithm from
the `package.json` filename for consumers whose version lives elsewhere. The override is a
pure input; the default read is the ported `node -p "require('./package.json')..."`.

**Alternatives considered**: Require the input always — rejected: breaks the zero-config
default that makes the Action a drop-in for a standard repo.

## D3 — resolve-env: inline job vs. bundled script

**Decision**: Extract the inline `resolve-env` logic from `snackbyte-base/.github/workflows/ci-cd.yml`
into `scripts/resolve-env.sh`, invoked by the composite Action, exposing `is-env` as an
output. Keep the exact predicate (`environments.some(e => e.branch === <branch>)`).

**Rationale**: The predicate is currently duplicated in three places (the CI job, the
`is_env` helper in `add-env.test.sh`, `resolve-env.mjs`). Bundling one script the Action and
the tests both call removes the duplication and makes `is-env` a first-class output
consumers gate on. Behavior is identical to the source predicate.

**Alternatives considered**: Leave resolve-env as workflow YAML the consumer copies —
rejected: defeats the "reference a shared unit" goal (Story 4) and re-introduces per-repo
copy-paste.

## D4 — Composite Action vs. Docker/JS Action

**Decision**: Composite Action (`runs.using: "composite"`) that runs the bundled bash
scripts via `run:` steps.

**Rationale**: The logic is already bash+git+node and node/git are present on every hosted
runner. A composite Action needs no build step, no container image, no `dist/` bundling —
the scripts *are* the implementation. This is the lowest-surface distribution that satisfies
Principle VI (no npm publish surface) and Principle VII (no rewrite — the bash is the source).

**Alternatives considered**: (a) JS Action — rejected: would require rewriting the bash into
JS (violates VII) and a bundled `dist/index.js` build/publish step. (b) Docker Action —
rejected: container pull latency for a task that is a few git commands; no dependency that
needs isolation.

## D5 — `node -p` JSON reads vs. pure bash/jq

**Decision**: Keep the `node -p`/`node -e` manifest reads from the source unchanged.

**Rationale**: Principle VII — do not rewrite proven code. `jq` is not guaranteed to be the
same version across runners; `node` is already the assumed runtime and is what the source and
its tests use. Rewriting the reads to `jq` would be an unforced behavioral-risk change.

**Alternatives considered**: `jq` — rejected: introduces a tool the source never used, for no
benefit, against the no-rewrite principle.

## D6 — Test harness portability

**Decision**: Port `derive-version.test.sh` (B1–B15) and `add-env.test.sh` essentially
verbatim, adjusting only the paths they copy the script from (they already honor `PKG_MM` and
write their own fixture manifests). Chain them under one `test:release` entrypoint as the
source does.

**Rationale**: The tests are self-contained (throwaway repo + local bare origin) and already
parameterized via `PKG_MM` and per-fixture `write_manifest`, so they port with path edits
only. This is the acceptance gate for SC-001/003/005 and directly proves Principle VII
(behavior preserved).

**Alternatives considered**: Rewrite tests in a JS test runner — rejected: the tests must
drive real git plumbing (trees, merges, squashes, shallow clones); bash is the natural driver
and matches the source, avoiding a translation that could silently drop a matrix row.

## Open follow-ons (explicitly out of 001 scope)

- Inline-JSON manifest form (D1 stretch).
- The Action's **own** release workflow + moving `v1` tag + Marketplace listing (Principle VI
  delivery mechanics) — candidate 002.
- Consumer-side workflow concurrency (same-branch serialization) is documented guidance for
  consumers, not enforced inside the Action.
