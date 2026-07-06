#!/usr/bin/env bash
# End-to-end interface test for action.yml (rows I1-I2 + INV-1/SC-004).
#
# A composite Action's steps are GitHub-Actions YAML, not directly runnable locally without a
# full runner. Rather than test the scripts in isolation (which the other suites already do), this
# harness READS action.yml and faithfully replays its step semantics against a real throwaway git
# repo, so it verifies the ACTION'S OWN WIRING:
#   - inputs (branch, manifest, major-minor) flow to the scripts as the YAML declares (env mapping);
#   - the derive step is gated on `steps.resolve.outputs.is-env == 'true'` exactly as the YAML says;
#   - outputs (is-env, version, tag) map to the right step outputs.
# The real GitHub CI run (.github/workflows/test.yml invoking ./ ) is the true end-to-end proof;
# this makes a broken action.yml fail locally instead of only in CI.
#
# Asserts (see specs/001-extract-release-flow/contracts/versioning.md):
#   I1  env push     -> is-env=true, version=MM.0, tag=vMM.0<suffix> matching derivation
#   I2  non-env push -> is-env=false, version/tag unset, NO tag created
#   INV-1/SC-004: after an env push, exactly one new tag, zero new commits, unchanged branch head.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION_YML="$ROOT/action.yml"
PASS=0; FAIL=0
assert() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf '  ok   %-26s expected %s\n' "$1" "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL %-26s expected %-14s got %s\n' "$1" "$2" "$3"; fi; }

# --- Read the action.yml wiring with node (the SAME file consumers use). We extract, per step,
#     the id, the `if` gate, the env map, and the run command, then replay them here. This is what
#     makes the test exercise action.yml rather than the scripts directly. ---
read_action() {
  node -e '
    const fs = require("fs");
    const y = fs.readFileSync(process.argv[1], "utf8");
    // Minimal, dependency-free extraction of the two composite steps we rely on. We assert on the
    // structural facts the contract cares about; a full YAML lib is intentionally avoided.
    const has = (re) => re.test(y);
    const facts = {
      resolveRunsResolveEnv: has(/id:\s*resolve[\s\S]*?resolve-env\.sh/),
      deriveGatedOnIsEnv:   has(/id:\s*derive[\s\S]*?if:\s*steps\.resolve\.outputs\.is-env\s*==\s*.true./),
      deriveRunsDerive:     has(/id:\s*derive[\s\S]*?derive-version\.sh/),
      manifestMappedResolve: has(/id:\s*resolve[\s\S]*?MANIFEST:\s*\$\{\{\s*inputs\.manifest/),
      manifestMappedDerive:  has(/id:\s*derive[\s\S]*?MANIFEST:\s*\$\{\{\s*inputs\.manifest/),
      mmMappedDerive:        has(/MAJOR_MINOR:\s*\$\{\{\s*inputs\.major-minor/),
      outIsEnv:  has(/is-env:[\s\S]*?steps\.resolve\.outputs\.is-env/),
      outVersion:has(/version:[\s\S]*?steps\.derive\.outputs\.version/),
      outTag:    has(/tag:[\s\S]*?steps\.derive\.outputs\.tag/),
    };
    console.log(JSON.stringify(facts));
  ' "$ACTION_YML"
}

echo "action.yml interface test (replaying composite steps against real git)"

# --- Structural wiring assertions (parsed from the real action.yml) ---
FACTS="$(read_action)"
jq_get() { node -e "process.stdout.write(String(JSON.parse(process.argv[1])[process.argv[2]]))" "$FACTS" "$1"; }
assert "wire: resolve runs script"     "true" "$(jq_get resolveRunsResolveEnv)"
assert "wire: derive gated on is-env"  "true" "$(jq_get deriveGatedOnIsEnv)"
assert "wire: derive runs script"      "true" "$(jq_get deriveRunsDerive)"
assert "wire: manifest->resolve env"   "true" "$(jq_get manifestMappedResolve)"
assert "wire: manifest->derive env"    "true" "$(jq_get manifestMappedDerive)"
assert "wire: major-minor->derive env" "true" "$(jq_get mmMappedDerive)"
assert "wire: output is-env"           "true" "$(jq_get outIsEnv)"
assert "wire: output version"          "true" "$(jq_get outVersion)"
assert "wire: output tag"              "true" "$(jq_get outTag)"

# --- Behavioral replay: execute the step semantics exactly as action.yml declares them. ---
# invoke_action <workdir> <branch>  -> echoes "is-env|version|tag" after replaying both steps with
# the real env mapping and the real gate. Uses the shipped scripts via their real paths.
invoke_action() {
  local wd="$1" branch="$2" manifest="${3:-./environments.json}" mm="${4:-}"
  ( cd "$wd"
    local gho; gho="$(mktemp)"
    # Step 1 (resolve): env MANIFEST=<inputs.manifest>  (as action.yml maps it)
    GITHUB_OUTPUT="$gho" MANIFEST="$manifest" bash "$ROOT/scripts/resolve-env.sh" "$branch" >/dev/null 2>&1
    local is_env; is_env="$(sed -nE 's/^is-env=(.*)$/\1/p' "$gho")"
    local version="" tag=""
    # Step 2 (derive): the real gate — only if is-env == 'true'
    if [ "$is_env" = "true" ]; then
      local gho2; gho2="$(mktemp)"
      if GITHUB_OUTPUT="$gho2" MANIFEST="$manifest" MAJOR_MINOR="$mm" bash "$ROOT/scripts/derive-version.sh" "$branch" >/dev/null 2>&1; then
        version="$(sed -nE 's/^version=(.*)$/\1/p' "$gho2")"
        tag="$(sed -nE 's/^tag=(.*)$/\1/p' "$gho2")"
      fi
    fi
    echo "${is_env}|${version}|${tag}"
  )
}

# Build a throwaway repo with a local bare origin and a 2-env manifest.
mk_repo() {
  local root work; root="$(mktemp -d)"; work="$root/work"
  git init -q -b main --bare "$root/origin.git"
  git init -q -b main "$work"
  ( cd "$work"; git config user.email t@t.t; git config user.name t; git config commit.gpgsign false
    git remote add origin "$root/origin.git"
    printf '{"name":"t","version":"0.1.0","private":true}\n' > package.json
    printf '%s\n' '{ "environments": [
      { "name":"production","branch":"main","isPublicFace":true,"noindex":false,"tagSuffix":"" },
      { "name":"staging","branch":"dev","isPublicFace":false,"noindex":true,"tagSuffix":"-dev" }
    ] }' > environments.json
    git add -A; git commit -q -m init; git push -q origin HEAD:main )
  echo "$work"
}

# I1 — env push (main): is-env=true, version=0.1.0, tag=v0.1.0, and INV-1 (one tag, no new commit).
W="$(mk_repo)"
commits_before="$(git -C "$W" rev-list --count HEAD)"
head_before="$(git -C "$W" rev-parse HEAD)"
tags_before="$(git -C "$W" tag | wc -l | tr -d ' ')"
OUT="$(invoke_action "$W" main)"
assert "I1 env push output" "true|0.1.0|v0.1.0" "$OUT"
commits_after="$(git -C "$W" rev-list --count HEAD)"
head_after="$(git -C "$W" rev-parse HEAD)"
tags_after="$(git -C "$W" tag | wc -l | tr -d ' ')"
assert "I1/INV-1 exactly one new tag"  "1" "$(( tags_after - tags_before ))"
assert "I1/INV-1 zero new commits"     "$commits_before" "$commits_after"
assert "I1/INV-1 branch head unchanged" "$head_before" "$head_after"

# I1b — REGRESSION (identity-less runner): a fresh CI runner has no git user.name/email. The
#   Action must still create the annotated tag (it falls back to the github-actions[bot] identity)
#   rather than dying with "Committer identity unknown". We suppress global+system git config to
#   mimic the runner, seed with an env-scoped identity, then invoke with NOTHING configured.
Wi="$(
  root="$(mktemp -d)"; work="$root/work"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git init -q -b main --bare "$root/origin.git"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git init -q -b main "$work"
  ( cd "$work"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    git remote add origin "$root/origin.git"
    printf '{"name":"t","version":"0.1.0","private":true}\n' > package.json
    printf '%s\n' '{ "environments": [ { "name":"P","branch":"main","tagSuffix":"" } ] }' > environments.json
    GIT_AUTHOR_NAME=s GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=s GIT_COMMITTER_EMAIL=s@s git add -A
    GIT_AUTHOR_NAME=s GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=s GIT_COMMITTER_EMAIL=s@s git commit -q -m init
    GIT_AUTHOR_NAME=s GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=s GIT_COMMITTER_EMAIL=s@s git push -q origin main )
  echo "$work"
)"
# derive with NO identity configured and global/system suppressed (the runner state)
tag_ident="$(
  cd "$Wi"; export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  if GITHUB_OUTPUT=/dev/null bash "$ROOT/scripts/derive-version.sh" main >/dev/null 2>&1; then
    git tag -l 'v0.1.0' | head -1
  else echo "FAIL-no-identity"; fi
)"
assert "I1b identity-less tag created" "v0.1.0" "$tag_ident"

# I2 — non-env push (feature-x): is-env=false, version/tag empty, NO tag created.
W2="$(mk_repo)"
tags_before2="$(git -C "$W2" tag | wc -l | tr -d ' ')"
OUT2="$(invoke_action "$W2" feature-x)"
assert "I2 non-env push output" "false||" "$OUT2"
tags_after2="$(git -C "$W2" tag | wc -l | tr -d ' ')"
assert "I2 no tag created" "$tags_before2" "$tags_after2"

echo ""
echo "action.yml interface: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
