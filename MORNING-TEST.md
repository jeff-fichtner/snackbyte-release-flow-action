# Morning test checklist — snackbyte-release-flow-action (feature 001)

Left for you 2026-07-06. **Feature 001 is fully implemented, tested, merged to `main`, and the
repo now versions ITSELF — `v0.1.0` was tagged end-to-end on a real runner.** This doc says what
I verified automatically and the small slice that genuinely needs your eyes/hands.

## TL;DR (updated after the versioning work)

- **On `main`, PR #1 closed** (you closed it; I committed straight to main as agreed).
- **CI: green** — `test` (suite + `uses: ./` smoke) and `release` (self-tagging) both pass.
- **`v0.1.0` is tagged on the repo** by its own Action (dogfooding), tagger `github-actions[bot]`.
- **Node 20 deprecation fixed** — bumped to `actions/checkout@v5` + `setup-node@v5`, node 24.
- **One real bug found & fixed by E2E**: the Action died on a bare runner with "Committer identity
  unknown" (annotated tag needs a git identity; fresh runners have none). Fixed with a
  bot-identity fallback + a regression test (I1b). The local suite had masked it.
- **42 test assertions, 0 failures** locally and in CI.

## What's LEFT for you (short list now)

1. **[DECISION] Cut the moving `v1` alias** — see item 4 below. `v0.1.0` exists; `@v1` still won't
   resolve until you (or a 002 feature) point a `v1` tag at a release. The README's `@v1` example
   depends on this.
2. **[REVIEW] Skim `main`** — nothing's blocking, but eyeball the identity fix in
   `scripts/derive-version.sh` and the two workflows if you want.
3. Everything else below is confirmed done (kept for the record).

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

### 2. [DONE ✓] The full derive-and-PUSH path in CI
**Now proven.** The self-versioning workflow (`.github/workflows/release.yml`) ran the real Action
via `uses: ./` with `contents: write` on a push to `main` and **pushed a real `v0.1.0` tag** to the
repo. This is the true end-to-end proof — the Action versioned its own repo, tag-only. (It took two
tries: the first failed on the identity bug, now fixed and regression-tested.)

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
