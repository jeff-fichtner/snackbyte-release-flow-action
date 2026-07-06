#!/usr/bin/env bash
# Proof of scripts/resolve-env.sh — the CI short-circuit ("is this branch an environment?").
#
# Rows P1-P2 (extraction-delta): resolve-env as an independently invokable capability, returning
# is-env=true for a declared environment branch and is-env=false otherwise. Plus a non-default
# MANIFEST path check for parity with derive-version. See
# specs/001-extract-release-flow/contracts/versioning.md.
#
# Run: bash scripts/resolve-env.test.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/resolve-env.sh"
PASS=0; FAIL=0

MANIFEST_JSON='{ "environments": [
  { "name":"P","branch":"main","isPublicFace":true,"noindex":false,"tagSuffix":"" },
  { "name":"A","branch":"dev","isPublicFace":false,"noindex":true,"tagSuffix":"-dev" }
] }'

work="$(mktemp -d)"
printf '%s\n' "$MANIFEST_JSON" > "$work/environments.json"
mkdir -p "$work/config"; printf '%s\n' "$MANIFEST_JSON" > "$work/config/envs.json"

# resolve <branch> [MANIFEST=path] -> prints the is-env value the script reports on stdout
resolve() {
  local branch="$1"; shift
  ( cd "$work"; env "$@" "$SCRIPT" "$branch" 2>/dev/null | sed -nE 's/^is-env=(.*)$/\1/p' )
}

assert() {
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf '  ok   %-4s expected %-6s\n' "$1" "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL %-4s expected %-6s got %s\n' "$1" "$2" "$3"; fi
}

echo "resolve-env against a 2-env manifest (P/main/'' A/dev/-dev)"

# P1 — a declared environment branch -> is-env=true
assert P1  "true"  "$(resolve main)"
assert P1b "true"  "$(resolve dev)"

# P2 — a non-environment branch -> is-env=false
assert P2  "false" "$(resolve feature-x)"
assert P2b "false" "$(resolve chore/tidy)"

# P1/P2 via a NON-default manifest path (MANIFEST env var) — same answers
assert P1c "true"  "$(resolve main  MANIFEST=config/envs.json)"
assert P2c "false" "$(resolve nope  MANIFEST=config/envs.json)"

rm -rf "$work"
echo ""
echo "resolve-env: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
