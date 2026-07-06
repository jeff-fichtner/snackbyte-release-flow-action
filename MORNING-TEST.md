# Morning test checklist — snackbyte-release-flow-action (feature 001)

Left for you 2026-07-06 (overnight). **Feature 001 is fully implemented, tested, pushed, and
green in CI.** This doc says what I verified automatically and the small slice that genuinely
needs your eyes/hands.

## TL;DR

- **PR #1 open**: https://github.com/jeff-fichtner/snackbyte-release-flow-action/pull/1
- **CI: green** — both jobs passed on a real ubuntu runner (push run + PR run).
- **41 test assertions, 0 failures** locally and in CI.
- Nothing is broken or half-done. The manual items below are *confirmations and decisions*, not fixes.

---

## What I verified automatically (you don't need to re-check these)

| Verified | How | Result |
|---|---|---|
| Derivation matrix B1–B15 | `scripts/derive-version.test.sh` against real throwaway git repos | PASS=20 (incl. delta P3–P5) |
| resolve-env P1–P2 | `scripts/resolve-env.test.sh` | PASS=6 |
| One-row-edit proof | `scripts/add-env.test.sh` (adds a `qa` row, asserts only manifest changed) | FAIL=0 |
| `action.yml` interface I1–I2 + INV-1 | `scripts/action.test.sh` (parses real action.yml, replays steps) | PASS=15 |
| Tag-only (INV-1/SC-004) | independent spot check: derive → commits 1→1, tags 0→1, new `v0.1.0` | confirmed |
| Shallow-clone guard (B12) | forced a real `file://` shallow clone; guard fired | confirmed (see note ↓) |
| **Real Action on a real runner** | CI `action.yml smoke (uses ./)` job — `uses: ./` invoked the composite Action | `is-env=false` for non-env, `is-env=true` for main; assertions passed |
| Bash syntax + action.yml structure | `bash -n` all scripts; key check on action.yml | clean |

**Bottom line**: the algorithm, the parameterization (MANIFEST / MAJOR_MINOR inputs), the
resolve-env gate, and the composite-Action wiring all work — proven locally AND on GitHub's
infrastructure.

---

## What YOU need to test/decide in the morning (the irreducible slice)

### 1. [DECISION] Merge PR #1 — review it first
The one thing I can't do is your review. Skim the diff, confirm you're happy with:
- `action.yml` shape (inputs/outputs names — these become your public contract).
- The extracted scripts (I kept the algorithm byte-identical; the only changes are the two
  `require('./environments.json')`/`package.json` reads → env-var-driven paths).
Then merge if it looks right. **Branch protection is not set up**, so merge is a plain button.

### 2. [MANUAL — needs a real tag push] The full derive-and-PUSH path in CI
CI proved `is-env` resolution on a real runner, but the smoke test deliberately **does NOT push a
real tag** to this repo (I set `continue-on-error` on the derive step and used a scratch
`major-minor: "9.9"` so nothing could pollute your tag namespace). Reason: pushing a tag needs
`permissions: contents: write` and I didn't want an overnight job minting tags on your repo
without you seeing it first.

**To confirm the real tag-push end-to-end** (the last unproven inch), after merging:
- Option A (safe, recommended): in a **throwaway test repo**, add `environments.json` + a workflow
  that does `uses: jeff-fichtner/snackbyte-release-flow-action@<sha-or-branch>` with
  `permissions: contents: write` and `fetch-depth: 0`, push to `main`, and confirm a `v0.1.0`
  tag appears. This is the true "consumer" E2E.
- Option B: temporarily add a `contents: write` job here that runs the Action on a scratch branch
  and pushes a tag, then delete the tag. More invasive; A is cleaner.

I did everything short of this because it writes a real tag to a real repo under your account —
your call on where.

### 3. [DECISION] `major-minor` default source
Confirm the assumption: MAJOR.MINOR defaults to reading **`package.json`'s** `version` (first two
components). The repo's own `package.json` is `0.1.0`, so a self-run would derive `v0.1.*`. If your
real consumers keep their version elsewhere, they'll pass `major-minor` explicitly — that path is
tested (P4).

### 4. [DECISION — deferred, not a bug] 002 scope
Out of scope for 001 (by design, in the spec): a **Marketplace listing** and the Action's **own
moving-`v1` release workflow**. The README's usage example references `@v1`, but **no `v1` tag
exists yet** — so that exact line won't resolve until you cut a `v1`. Decide whether to:
- cut a `v1` tag now (makes `@v1` work), or
- leave it for a 002 feature that does releases properly (semver + moving `v1` + Marketplace).

---

## Notes / small things I want you to know

- **B12 shallow test shows "skip" locally** — this is a local-git quirk (`git clone --depth 1` of a
  local path doesn't always produce a shallow repo). I separately verified the guard fires on a
  genuinely-shallow `file://` clone, and CI uses `fetch-depth: 0`, so it's covered — just not via
  that one row on your Mac.
- **The derive step in the smoke job is `continue-on-error: true`** on purpose (see #2). If you
  later want CI to prove the push too, that's the flag to flip once write perms are granted.
- **No secrets, nothing destructive** ran overnight. The only writes were to this repo's branch
  `001-extract-release-flow` and PR #1. No tags were pushed to your repo.

## Commands to re-run everything yourself

```bash
cd ~/snackbyte/code/snackbyte-release-flow-action
npm run test:release          # full local suite (should end PASS=... FAIL=0 everywhere)
gh pr view 1 --web            # open the PR
gh run list --branch 001-extract-release-flow   # see the green CI runs
```
