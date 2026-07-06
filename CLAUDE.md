# snackbyte-release-flow-action

A shareable **GitHub Action** that turns a repo's `environments.json` manifest into its
release flow: *"is this pushed branch a deployable environment?"* (resolve-env) and, if
so, *"what version tag does this push get?"* (derive-version) — creating a **tag only,
never a commit**. It is the extraction of the manifest-driven release machinery from
`snackbyte-base`.

## Status

**Built (feature 001).** `action.yml` + `scripts/derive-version.sh` + `scripts/resolve-env.sh`
exist; the behavior-complete bash suite (`npm run test:release`) passes locally and in CI. The
scripts are parameterized extractions of the `snackbyte-base` originals (manifest path and
MAJOR.MINOR are inputs; algorithm unchanged — Constitution VII). Spec/plan/tasks live in
`specs/001-extract-release-flow/`. Out of scope for 001 (candidate 002): Marketplace listing
and the Action's own moving-`v1` release workflow.

- Logic: `scripts/derive-version.sh` (derive-version), `scripts/resolve-env.sh` (resolve-env)
- Interface: `action.yml` (composite; inputs `branch`/`manifest`/`major-minor`/`version-strategy`, outputs `is-env`/`version`/`tag`)
- Tests: `scripts/*.test.sh`, run via `npm run test:release`; CI in `.github/workflows/test.yml`
- Consumer wiring: `CONSUMING.md` (app + library recipes, copy-paste)

**Version strategy (feature 002).** `version-strategy` input selects how the version NUMBER is
chosen; resolve-env/manifest/tag-only/guards are shared and strategy-independent:
- `build-id` (default) — global monotonic, tree-reused PATCH. For deployable **apps** (this repo
  self-versions with it).
- `package-json` — tag `package.json`'s version verbatim. For published **libraries** (intentional
  SemVer; a build counter can't be a compatibility promise). The existing-tag guard doubles as the
  "bump package.json before re-releasing" rule.

## Extraction source

The algorithm, manifest, and test matrices originated in `snackbyte-base` — the work was
parameterization (hard-coded `./environments.json` / `./package.json` → Action inputs),
not new logic. Source of truth:

- Derivation: `snackbyte-base/scripts/derive-version.sh` (~120 lines bash)
- resolve-env: the `resolve-env` job in `snackbyte-base/.github/workflows/ci-cd.yml`
- Tests: `snackbyte-base/scripts/derive-version.test.sh` (rows B1–B15) + `add-env.test.sh`
- Contract: `snackbyte-base/specs/00{2,3}-*/contracts/versioning.md`

## Non-negotiables (the contract)

- Tag format is fixed: `v${MAJOR}.${MINOR}.${PATCH}${tagSuffix}` (MAJOR.MINOR from
  `package.json`; PATCH is a global monotonic build id derived from tags).
- Reuse key is the **tree hash**, not the commit SHA (dev→main promotion reuses the
  number across ff/merge/squash/clean-rebase; a divergent rebase mints a new number).
- CI creates a tag only — never a commit or branch push.
- Design goal: adding an environment is a **one-row edit** to `environments.json`.

## Spec Kit

This project was scaffolded with Spec Kit. Slash commands live in `.claude/skills/`
(`/speckit-constitution`, `/speckit-specify`, `/speckit-plan`, `/speckit-tasks`,
`/speckit-implement`). Setup guide: `~/Snackbyte/tools/project-setup/SETUP-CHECKLIST.md`.
