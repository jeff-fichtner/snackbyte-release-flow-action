# Quickstart: validating build once

1. `npm run test:release` from the repo root: every existing row plus L1–L12 and I4 pass.
2. On the PR, the `validate (merge gate)` job runs the same suite and a real `uses: ./` look-up
   (read-only token) on a runner.
3. A consumer adopts it with the build-once recipe in `CONSUMING.md` (after PR #10): a look-up step
   first, checks and build gated on `released-as == ''`, the tag step, then a deploy that uses
   staging's build when `released-as` is set. A promotion's release job then runs only checkout,
   look-up and tag.
