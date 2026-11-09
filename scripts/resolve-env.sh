#!/usr/bin/env bash
# resolve-env — the CI short-circuit: is the pushed branch a deployable environment?
#
# GitHub evaluates a workflow's `on:` trigger before checkout, so it cannot read the manifest to
# decide whether a branch is an environment. This lightweight check reads the manifest after
# checkout and answers that one question, so a push to a non-environment branch short-circuits
# before any expensive build/tag/deploy work runs.
#
# Extracted verbatim (same predicate) from the inline `resolve-env` job in
# snackbyte-base/.github/workflows/ci-cd.yml:
#   node -e "process.exit(require('./environments.json').environments
#             .some(e => e.branch === process.env.GITHUB_REF_NAME) ? 0 : 1)"
#
# Parameterization (algorithm unchanged):
#   $1 / $GITHUB_REF_NAME   the pushed branch
#   $MANIFEST               path to the environment manifest   (default ./environments.json)
#
# Output: prints `is-env=true|false` to stdout, and appends the same to $GITHUB_OUTPUT when set.
# Exit status is 0 for either answer (the answer is data, not an error). A manifest that is
# missing, is not valid JSON, or has no `environments` array exits 1: reading it as "not an
# environment" would skip the release with a green run.
#
# Usage: scripts/resolve-env.sh <branch>   (branch defaults to $GITHUB_REF_NAME)
set -euo pipefail

BRANCH="${1:-${GITHUB_REF_NAME:-}}"
MANIFEST="${MANIFEST:-./environments.json}"

if ! is_env="$(MANIFEST="$MANIFEST" node -e '
  const name = process.env.MANIFEST;
  let m;
  try {
    m = JSON.parse(require("fs").readFileSync(require("path").resolve(name), "utf8"));
  } catch (e) {
    console.error(`Cannot read the manifest ${name}: ${e.message}`);
    process.exit(1);
  }
  if (!m || !Array.isArray(m.environments)) {
    console.error(`The manifest ${name} has no "environments" array.`);
    process.exit(1);
  }
  process.stdout.write(m.environments.some(e => e.branch === process.argv[1]) ? "true" : "false");
' "$BRANCH")"; then
  exit 1
fi

if [ "$is_env" = "true" ]; then
  echo "Branch '${BRANCH}' is an environment — proceeding." >&2
else
  echo "Branch '${BRANCH}' is not an environment in ${MANIFEST} — nothing to do." >&2
fi

echo "is-env=${is_env}"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "is-env=${is_env}" >> "$GITHUB_OUTPUT"
fi
