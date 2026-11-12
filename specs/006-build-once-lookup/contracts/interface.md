# Contract: `mode` and `released-as`

## Input `mode`

| Value | Behavior |
|---|---|
| `tag` (default) | Today's behavior: resolve, derive, create and push the tag. |
| `lookup` | Resolve and derive exactly as `tag` would, through every refusal, then stop. No tag is created or pushed; no write permission or git identity is needed. |

Anything else is refused before any other work: `Unknown mode '<v>' — expected 'tag' or 'lookup'.`

## Outputs

| Output | `tag` mode | `lookup` mode |
|---|---|---|
| `is-env` | unchanged | same as `tag` would give |
| `version` | the number tagged | the number `tag` would tag |
| `tag` | the tag created | the tag `tag` would create |
| `released-as` | see below | see below |

`released-as` (both modes, set only for an environment push):
- `build-id`, number reused from a tag on this tree → an existing `<prefix>vMM.N<suffix>` tag carrying
  that number on HEAD's tree, other than the one this run makes, the first by name.
- `build-id`, number minted (max+1) → empty.
- `package-json` → empty.

## Agreement

For one repository state, `lookup` followed by `tag` gives identical `version`, `tag` and
`released-as`, and `tag` creates exactly the tag `lookup` reported. Holds when no other derivation
for the releasable runs in between, which the recipes' per-releasable concurrency group ensures.

## Test rows

| Row | State | Expect |
|---|---|---|
| L1 | `vMM.N-a` on tree T; lookup `main` at T | `MM.N\|vMM.N\|vMM.N-a`, tag set unchanged |
| L2 | tree with no tag; lookup | `MM.(max+1)\|vMM.(max+1)\|` (empty released-as), tag set unchanged |
| L3 | L1 state; lookup then tag | identical outputs; exactly one new tag, the reported one |
| L4 | target tag on own tree (B7 state); lookup | FAIL, as tag |
| L5 | shallow clone; lookup | FAIL, as tag |
| L6 | `mode=bogus` | FAIL before work |
| L7 | number on tree under `-a` and `-c`; lookup `main` | released-as `vMM.N-a` (first by name) |
| L8 | tag mode on a promotion | released-as reported, tag created |
| L9 | `package-json` lookup | released-as empty, no tag |
| L10 | prefixed namespace promotion; lookup | released-as carries the prefix |
| L11 | lookup with no git identity, no origin | succeeds (no write attempted) |
| L12 | heal state (R1); lookup | same answer as tag (`vMM.3`), released-as empty |
| I4 | action.yml | `mode`→`MODE` on derive, default `tag`; `released-as` output from derive; replayed lookup then tag agree |
