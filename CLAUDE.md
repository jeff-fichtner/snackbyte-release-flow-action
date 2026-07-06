# snackbyte-release-flow-action

A shareable **GitHub Action** that turns a repo's `environments.json` manifest into its
release flow: *"is this pushed branch a deployable environment?"* (resolve-env) and, if
so, *"what version tag does this push get?"* (derive-version) — creating a **tag only,
never a commit**. It is the extraction of the manifest-driven release machinery from
`snackbyte-base`.

## Status

**Design captured; build deliberately deferred.** The full rationale, schema, algorithm,
and intended `action.yml` shape live in `README.md` — read it first. As of the Spec Kit
scaffold, this repo has `.specify/`, `.claude/skills/`, and these docs; no `action.yml`,
scripts, or tests exist yet.

## Extraction source (when built)

The algorithm, manifest, and test matrices already exist in `snackbyte-base` — the work
is parameterization (hard-coded `./environments.json` / `./package.json` → Action inputs),
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
