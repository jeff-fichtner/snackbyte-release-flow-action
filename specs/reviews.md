# Reviews

## Revisits at a feature's close

Decisions taken without Jeff's ruling, to look at again once they have been used for a while. At
each feature's close: did we want it; did it end up as imagined, or was the option passed over
better? An entry stays until Jeff retires it.

| Decision | Chosen | Passed over | Date |
|---|---|---|---|
| Keeping look-up and tag in agreement (006) | An opt-in `expect-tag` input; the build-once recipe always passes the look-up's tag, and the tag step refuses any other | Relying on the per-releasable concurrency group alone; making the pairing mandatory | 2026-11-11 |
| A blank `mode` (006) | Refused, like any unknown value; unset still means `tag` | Reading a blank as `tag` | 2026-11-11 |
| Which tag `released-as` names when several environments carry the number (006) | The first by name | A list of every such tag; a bare reused true/false | 2026-11-11 |
| How `released-as` is found (006) | A second, small scan after step 1, leaving the step-1 loop untouched | Folding it into the step-1 scan's output (one pass, but edits the most fragile loop in the script) | 2026-11-11 |
