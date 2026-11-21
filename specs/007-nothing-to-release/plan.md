# Implementation Plan: Nothing to release

**Branch**: `007-nothing-to-release` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

Under `package-json`, a look-up whose target tag already sits on an earlier commit of the branch
reports it (`released-as` = the tag, a "Nothing to release" notice) and succeeds, instead of
failing at the exists-guard. Tag mode, re-runs, real collisions and `build-id` are unchanged. The
registry check ("is it on npm?") stays in the consumer's recipe.

## Technical Context

Bash 3.2+ (macOS local) and 5.x (runner), git, node for JSON reads. One change site in
`scripts/derive-version.sh`: the exists-guard, just before the lookup exit. No new input or output.

## Constitution Check

- **I. Tag-only**: a look-up creates nothing; tag mode is unchanged. ✅
- **II. Tree-hash reuse key**: `build-id` untouched. The new check is commit ancestry, used only
  under `package-json`, where there is no reuse. ✅
- **III. Fixed tag format**: unchanged. ✅
- **IV. One-row edit**: no manifest change. ✅
- **V. Fail loud**: tag mode still refuses an existing target. The look-up's success is for one
  unambiguous state (the tag on an earlier commit of this line) and says so visibly (a notice);
  re-runs and collisions still fail. ✅
- **VI. Action, not package**: no new artifact. ✅
- **VII. Extract by parameterization**: the build-id derivation is unedited. ✅

## Design

1. After `tag` is derived and the `expect-tag` check has run, compute `already_released`: strategy
   is `package-json`, `refs/tags/<tag>^{commit}` resolves, differs from HEAD, and
   `git merge-base --is-ancestor` says it is in HEAD's history.
2. Look-up and `already_released`: set `released_as="$tag"`, print the notice to stdout, and fall
   through to the existing look-up exit, which writes the outputs.
3. Otherwise the existing guard: an existing target fails. When `already_released` (tag mode), the
   message names the earlier commit and the two ways out.

Placing it after `expect-tag` keeps that check first. The look-up never sets `expect-tag`, so the
order matters only for a tag step, which refuses either way.

## Rejected alternatives

- **A new opt-in input that makes tag mode succeed too.** A new name a consuming developer types,
  and it would let a recipe skip the look-up while still running its checks before the tag, which
  pays for checks on every non-release push. Can be added later if a consumer needs one step.
- **The Action checks npm.** Registry-specific (npm, GitHub Packages, private registries) and needs
  network access; the Action is about tags.
- **Count the tag on HEAD as released too.** A "re-run all jobs" of a release whose publish failed
  would go green without publishing.
