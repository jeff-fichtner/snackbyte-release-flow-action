# Contract: nothing to release (`package-json`)

Amends [006's contract](../../006-build-once-lookup/contracts/interface.md) for one state. Every
other part of it stands.

## The state

`version-strategy: package-json`, and the target tag (`<prefix>v<version><suffix>`, this channel's
suffix) exists, resolves to a commit, and that commit is an ancestor of HEAD other than HEAD.

| Mode | Result |
|---|---|
| `lookup` | Succeeds. `version`, `tag` as usual; `released-as` = the tag. Stdout carries `::notice title=Nothing to release::<tag> is already released on an earlier commit of <branch>; this push carries no new version.` Nothing is created. |
| `tag` | Fails: `Tag <tag> is already released on an earlier commit of <branch> — this push carries no new version. Bump the version in <package-json> to release, or look up first (mode: lookup) and skip the tag step when released-as is set.` Nothing is created. |

## `released-as` under `package-json`

- a look-up in the state above → the target tag;
- otherwise → empty.

A consumer reads it the same way under both strategies: empty means new work, so check (and
build); set means already released, so skip. Under `package-json` there is also nothing to tag or
publish; under `build-id` the tag step still tags the promotion.

## Agreement (006) exception

006 promises that `lookup` then `tag` give the same outputs. In this state they do not: the look-up
reports and the tag step refuses. The recipe never runs the tag step when `released-as` is set.

## Still refused, both modes

- target tag on HEAD itself (a re-run of the release push);
- target tag on a commit outside HEAD's history (a real collision);
- any existing target under `build-id`.

## Test rows

| Row | State | Expect |
|---|---|---|
| NR1 | `v1.4.0` released, then a commit without a bump; lookup | `1.4.0\|v1.4.0\|v1.4.0`, tag set unchanged |
| NR2 | NR1 state; tag mode | FAIL, message names the earlier commit and `mode: lookup`, tag set unchanged |
| NR3 | tag on HEAD (re-run); lookup | FAIL |
| NR4 | tag on a side branch, not in main's history; lookup | FAIL |
| NR5 | NR1 state then bump to 1.5.0; lookup | `1.5.0\|v1.5.0\|` |
| NR6 | NR1 state; lookup | the "Nothing to release" notice |
| NR7 | channel A: `v1.4.0` only, then `v1.4.0-a` on an earlier commit | first a fresh `v1.4.0-a`, then released-as `v1.4.0-a` |
| NR8 | prefix `lib-`: bare `v1.4.0` only, then `lib-v1.4.0` | first a fresh `lib-v1.4.0`, then released-as `lib-v1.4.0` |
| NR9 | lightweight `v1.4.0` on an earlier commit; lookup | released-as `v1.4.0` |
| NR10 | `build-id`, target on an earlier commit with the same tree; lookup | FAIL (unchanged) |
| I5 | action.yml replay of NR1 and NR2 | lookup `true\|0.1.0\|v0.1.0\|v0.1.0`, nothing tagged; tag `true\|\|\|` |
| CI | PR gate: real `uses: ./` lookup, scratch `package.json` 7.7.7, local `v7.7.7` on `HEAD~1` | released-as `v7.7.7`, tag set unchanged |
