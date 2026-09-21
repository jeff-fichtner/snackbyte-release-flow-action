# Implementation Plan: Tag prefix — two releasables in one repository

**Branch**: `004-tag-prefix` | **Date**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

## Summary

Add an optional `tag-prefix` input (default `""`). When set, the derived tag is
`<prefix>v<version><suffix>`, and every place `derive-version.sh` reads existing tags to reuse or
mint a number — the `git tag -l` glob and the anchored `patch_re` that feed both the tree-keyed
reuse scan and the max-patch scan — is anchored on the prefix, so a derivation sees only its own
namespace. The exists-guard checks the full prefixed tag. The prefix is validated first, beside
`version-strategy`. The un-prefixed path is untouched in effect: with the default, the prefix
string is empty and every glob/regex is byte-identical to today's.

## Technical Context

**Language/Version**: Bash + Node (unchanged). No new runtime.

**Primary Dependencies**: `git`, `node`, POSIX tools; GitHub Actions runner. Unchanged.
`git check-ref-format` (part of git) is used as the git-level validity gate for the prefix.

**Testing**: Extend the existing bash suites — `derive-version.test.sh` gains the T-series
(prefixed mint/blindness/guard/reuse/package-json/outputs), TP-default (explicit empty == absent),
and X2 (invalid prefix, no tag created); `action.test.sh` gains two wiring facts and an I3 replay
row. The existing matrix runs unchanged. Run via `npm run test:release` and the CI gate.

**Target Platform**: GitHub Actions runners + local. Unchanged.

**Project Type**: Composite GitHub Action (unchanged layout).

**Constraints**: Default empty and byte-identical. The manifest format, `resolve-env.sh`, `is-env`,
and the suffix logic do not change. Nothing is renamed.

**Scale/Scope**: 1 new input in `action.yml`; ~15 changed/added lines in `derive-version.sh`
(validation block, escaped prefix, two globs, one regex, the tag line); ~18 new test rows.

## Constitution Check

*GATE: Must pass before implementation.*

| Principle | Gate | Status |
|---|---|---|
| I. Tag-Only, Never a Commit | Still exactly one tag. | PASS — the `git tag`/push tail is shared and unchanged; only the tag's name gains a prefix. |
| II. Tree-Hash Is the Reuse Key | Reuse still keyed on `HEAD^{tree}` vs each tag's `^{tree}`. | PASS — the key is unchanged; the prefix only narrows *which tags* are candidates (this namespace's). The key remains the repository tree — a library-only change alters it for the app too; documented as a trade-off (spec Edge Cases), not changed. |
| III. Fixed, Derived Tag Format | Format was "exactly `v${MAJOR}.${MINOR}.${PATCH}${tagSuffix}`". | **AMENDED (1.0.0 → 1.1.0)** — the format becomes `${tagPrefix}v${MAJOR}.${MINOR}.${PATCH}${tagSuffix}` with `tagPrefix` defaulting to `""`, and "max over ALL vMM.* tags" becomes "over all tags in this namespace". Within a namespace the format and the one-rule derivation are unchanged, so the one-row-edit property (IV) is preserved. This is a deliberate, documented amendment (VII), made in the constitution rather than carried as a standing deviation. |
| IV. Manifest Is the Product (one-row edit) | No manifest schema change. | PASS — the prefix is an Action input, not a facet. `add-env.test.sh` runs unchanged. |
| V. Fail Loud, Never Silent | New guard: invalid prefix. Existing guards unchanged. | PASS — the prefix is validated before any resolve/guard/tag work (FR-007); the exists-guard checks the full prefixed tag; regexes remain anchored (now on the prefix too). |
| VI. Distributed as an Action, Not a Package | Still tags; does not publish. | PASS — no publish surface. |
| VII. Extract by Parameterization, Not Rewrite | build-id engine unchanged in structure. | PASS — the prefix is threaded through the existing glob/regex/tag-line as a parameter; no logic is restructured. The un-prefixed matrix proves it byte-for-byte. |

**Result**: Six PASS, one amendment (III). No Complexity Tracking entries beyond the amendment.

## Open point recorded (not resolved by this feature)

The Action reads `package.json` from the checkout root (`node -p "require('./package.json')"`,
cwd-relative; a `uses:` step's cwd is `$GITHUB_WORKSPACE` regardless of the caller's
`defaults.run.working-directory`). For the concrete two-releasable layout (`packages/service/`,
`packages/client-node/`) that means: the app supplies `major-minor:` explicitly, and a library in a
subdirectory cannot use `version-strategy: package-json` at all — there is no input for the path.
`tag-prefix` is necessary but not sufficient for that layout. Resolution (a `package-json` path
input, a `working-directory` input, or a documented limitation) is a separate decision; this plan
does not pre-empt it. CONSUMING.md's prior claim that the Action reads `<app>/package.json` is
corrected in this feature's docs.

## Project Structure

### Documentation (this feature)

```text
specs/004-tag-prefix/
├── plan.md              # this file
├── spec.md              # WHAT/WHY
├── contracts/
│   ├── action-io.md     # the tag-prefix input + output semantics
│   └── versioning.md    # T-series / TP-default / X2 rows + namespace invariants
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks output
```

### Source Code (changed files only)

```text
action.yml                      # + input: tag-prefix (default ""); passed to derive as TAG_PREFIX
scripts/derive-version.sh       # + TAG_PREFIX read + validation; prefix threaded through glob/regex/tag
scripts/derive-version.test.sh  # + T1–T8, TP-default, X2 rows; derive_out helper
scripts/action.test.sh          # + wiring facts (mapped, default "") + I3 prefixed replay row
.specify/memory/constitution.md # Principle III amended (1.1.0)
CONSUMING.md / README.md        # input in the reference tables; "Two releasables in one repository"
```

**Structure Decision**: No new files for logic. The prefix is a parameter of the existing
derivation, read and validated at the top of `derive-version.sh` beside `version-strategy`, and
used in exactly the places that name or read tags. `resolve-env.sh` is untouched.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
|---|---|---|
| Constitution III amendment | The shipped format would otherwise contradict the governing text ("exactly `v…`"). | Carrying it as a standing written deviation leaves the constitution stale on the one principle it marks NON-NEGOTIABLE. |
