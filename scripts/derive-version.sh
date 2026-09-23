#!/usr/bin/env bash
# Derive this push's version tag from git tags — the release flow never commits anything.
#
# The version PATCH is not stored in package.json (which holds only MAJOR.MINOR); it is a
# global, monotonic build id derived from the tags that already exist. The pushed branch
# selects the environment; the manifest maps the branch to the tag suffix:
#   - a branch whose environment has suffix ""      -> tag vMAJOR.MINOR.PATCH
#   - a branch whose environment has suffix "-dev"  -> tag vMAJOR.MINOR.PATCH-dev
#   - any other environment's suffix                -> tag vMAJOR.MINOR.PATCH<suffix>
#
# One rule, every environment (no per-branch special case):
#   1. If ANY version number is already tagged on a commit carrying THIS exact SOURCE TREE —
#      regardless of which environment's suffix it bears — reuse that number. The reuse key is
#      the tree (file content), not the commit SHA, so promoting dev -> main reuses the dev
#      number whether the promotion fast-forwards, makes a merge commit, squashes, or rebases
#      cleanly (all four leave main's tree identical to dev's). A rebase that also absorbs
#      divergent main changes produces a DIFFERENT tree, so it correctly mints a new number.
#   2. Otherwise advance to (highest patch among ALL vMM.* tags) + 1. Taking the max over every
#      tag (every suffix, every environment) makes two distinct trees sharing a number impossible
#      ONLY ACROSS SERIALIZED DERIVATIONS. This scan and the `git push` below are not atomic: two
#      runs that both read the tag set before either pushes both mint the same number. The build id
#      is global to the RELEASABLE, so the consuming workflow MUST put every environment branch of
#      a releasable in ONE concurrency group (with queueing) — a per-branch group does not
#      serialize main against dev. See CONSUMING.md; step 1 heals the residue when it happens
#      anyway. The cost is gaps (a hotfix consumes a number, so another environment's next number
#      skips ahead); that is correct for a build id.
# The branch is used only as DATA (its suffix, looked up in the manifest). There is no
# per-environment code path: the same reuse-or-mint runs for every environment.
#
# Output: prints nothing to stdout except, when GITHUB_OUTPUT is set, writes `version=` and
# `tag=` for the workflow. The tag is created and pushed here; no commit, no branch push.
#
# Parameterization (extracted from snackbyte-base; algorithm unchanged):
#   $1 / $GITHUB_REF_NAME   the pushed branch
#   $MANIFEST               path to the environment manifest   (default ./environments.json)
#   $MAJOR_MINOR            override for MAJOR.MINOR            (default: read $PACKAGE_JSON)
#   $PACKAGE_JSON           path to the package.json to read the version from (default ./package.json)
#   $TAG_PREFIX             tag-namespace prefix, e.g. client-node-   (default "" — bare v tags)
#
# Tag prefix (feature 004): when a repository holds more than one releasable, each needs its own
# tag namespace or their numbers corrupt each other (the app's "last vMM.* tag" scan would count
# the library's tags; both starting at v0.1.0 would collide on the exists-guard). TAG_PREFIX puts
# this releasable's tags in the namespace `<prefix>v...`; every scan below is anchored on the
# prefix, so tags with a different prefix — and un-prefixed tags — are invisible to it, and the
# un-prefixed derivation (prefix "") is in turn blind to prefixed tags. The default "" is today's
# behavior byte for byte.
#
# Usage: scripts/derive-version.sh <branch>   (branch defaults to $GITHUB_REF_NAME)
set -euo pipefail

BRANCH="${1:-${GITHUB_REF_NAME:-}}"
MANIFEST="${MANIFEST:-./environments.json}"
VERSION_STRATEGY="${VERSION_STRATEGY:-build-id}"
PACKAGE_JSON="${PACKAGE_JSON:-./package.json}"
TAG_PREFIX="${TAG_PREFIX:-}"

# Validate the strategy FIRST — before any resolve/guard work — so a bad input (a typo) is rejected
# immediately rather than after side-effect-free-but-wasteful checks (and so a shallow clone can't
# mask the real error). The strategy only affects how the version NUMBER is chosen further down.
case "$VERSION_STRATEGY" in
  build-id|package-json) ;;
  *)
    echo "Unknown version-strategy '${VERSION_STRATEGY}' — expected 'build-id' or 'package-json'." >&2
    exit 1
    ;;
esac

# Validate the tag prefix just as early. The rule: empty, or [A-Za-z0-9._-] starting alphanumeric
# and ending in '-' (so the prefix reads as a namespace: `client-node-v0.1.0`). The class contains
# no glob or regex metacharacters except '.', which is escaped where the prefix is matched below;
# a leading '-' is refused because git's CLI would parse the resulting tag as an option. The
# git-level rules ('..', '.lock', control characters) are checked by git itself.
if ! [[ "$TAG_PREFIX" =~ ^([A-Za-z0-9][A-Za-z0-9._-]*-)?$ ]]; then
  echo "Invalid tag-prefix '${TAG_PREFIX}' — expected [A-Za-z0-9._-] starting alphanumeric and ending in '-' (e.g. 'client-node-'), or empty." >&2
  exit 1
fi
if [ -n "$TAG_PREFIX" ] && ! git check-ref-format "refs/tags/${TAG_PREFIX}v0" >/dev/null 2>&1; then
  echo "Invalid tag-prefix '${TAG_PREFIX}' — not a valid git tag-name fragment (git check-ref-format)." >&2
  exit 1
fi

# Resolve the pushing branch's environment from the manifest. An unknown branch cannot be
# tagged (we wouldn't know which suffix to stamp) — fail loudly. node -p prints the suffix, or
# the sentinel __UNKNOWN__ when the branch is not an environment, mirroring the package.json read.
suffix="$(MANIFEST="$MANIFEST" node -p "
  const m = require(require('path').resolve(process.env.MANIFEST)).environments;
  const e = m.find(x => x.branch === process.argv[1]);
  e ? e.tagSuffix : '__UNKNOWN__';
" "$BRANCH")"
if [ "$suffix" = "__UNKNOWN__" ]; then
  echo "Branch '${BRANCH}' is not an environment in ${MANIFEST} — nothing to derive." >&2
  exit 1
fi

# Non-blocking warning: two environments sharing a tag suffix is allowed (it cannot corrupt the
# version line — distinct numbers keep tags distinct) but makes their tags indistinguishable.
dupe="$(MANIFEST="$MANIFEST" node -p "
  const s = require(require('path').resolve(process.env.MANIFEST)).environments.map(e => e.tagSuffix);
  const seen = new Set(), dups = new Set();
  for (const x of s) { if (seen.has(x)) dups.add(x); seen.add(x); }
  [...dups].map(d => JSON.stringify(d)).join(', ');
")"
if [ -n "$dupe" ]; then
  echo "Warning: ${MANIFEST} has duplicate tagSuffix(es): ${dupe} — those environments' tags will be indistinguishable." >&2
fi

# A shallow checkout would hide existing tags and mis-derive a number that already exists.
# Test the clone directly rather than guessing from history length: zero tags on a COMPLETE
# clone is a legitimate first push (which mints vMM.0), but zero tags on a shallow clone is a
# truncation we must refuse.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  echo "Shallow checkout — tags may be hidden; refusing to derive. Use a full clone (fetch-depth: 0)." >&2
  exit 1
fi

# The package.json read, shared by both strategies. Like the manifest, the path is an input
# resolved from the checkout root (a `uses:` step's cwd), because a releasable in a subdirectory
# cannot reach it any other way — the caller's working-directory does not apply to a `uses:` step.
# A missing file fails loudly, naming the input, instead of surfacing as a node stack trace.
# pkg_read [js]: prints `require(<package.json>).version<js>` — the same expressions as before,
# parameterized on the path.
pkg_read() {
  if [ ! -f "$PACKAGE_JSON" ]; then
    echo "package.json not found at '${PACKAGE_JSON}' — set the package-json input to the releasable's package.json." >&2
    exit 1
  fi
  PACKAGE_JSON="$PACKAGE_JSON" node -p "require(require('path').resolve(process.env.PACKAGE_JSON)).version${1:-}"
}

# --- Version strategy ---------------------------------------------------------------------------
# How the version NUMBER is chosen. Everything else (resolve-env, the guards above, tag-only, the
# collision guard and push below) is shared and strategy-independent.
#   build-id     (default) — the global monotonic, tree-reused PATCH. For deployable APPS: the
#                            number is a build-artifact identity, and dev->main promotion reuses it.
#   package-json           — tag the package.json `version` VERBATIM. For published LIBRARIES: the
#                            number is intentional SemVer (a human promise to consumers), so the
#                            tooling must not invent it. No reuse, no max+1.
# (VERSION_STRATEGY was read and validated at the top of the script.)
case "$VERSION_STRATEGY" in
  package-json)
    # The version IS whatever package.json declares — verbatim, prerelease and all. major-minor is a
    # build-id concept and is intentionally ignored here (documented in the I/O contract).
    version="$(pkg_read)"
    ;;

  build-id)
    # MAJOR.MINOR from the MAJOR_MINOR override, else from package.json; the patch field is ignored.
    MM="${MAJOR_MINOR:-$(pkg_read ".split('.').slice(0,2).join('.')")}"
    MME="${MM//./\\.}" # regex-escape the dots for anchored matching
    PFXE="${TAG_PREFIX//./\\.}" # likewise for the tag prefix ('.' is its only regex metacharacter)

    # The read-back parser is generated from the tag-format parts (the tag prefix, then 'v', then
    # MM., then the integer patch, then ANY suffix or none). One regex serves both reuse and mint —
    # it is suffix-agnostic by construction, so it never needs to know which environments exist,
    # and it is anchored on the prefix, so another releasable's namespace never leaks in.
    patch_re="^${PFXE}v${MME}\.([0-9]+)(-[A-Za-z0-9._-]+)?\$"

    # Step 1 — reuse: if any number is already tagged on a commit carrying THIS exact source tree
    # (any suffix), take it. The reuse key is the tree hash, not the commit SHA, so a promotion that
    # rewrites the commit but not the content — a merge commit, a squash, or a rebase that stays
    # clean — still reuses the dev number. (A fast-forward is the special case where the SHA is also
    # unchanged.) A rebase that absorbs divergent main changes yields a DIFFERENT tree and correctly
    # mints a new number. We scan every <prefix>vMM.* tag, resolve each to its tree, and keep the
    # numbers whose tree matches HEAD's; the highest such number wins (matching the old --points-at
    # tie-break). (`git tag -l` matches the whole name, so the glob is prefix-anchored too.)
    # The scan below reports duplicate build ids as a GitHub Actions ANNOTATION. Two constraints
    # decide where it is written. Workflow commands are read from stdout, never stderr, so it
    # cannot use the script's usual `>&2` diagnostic channel. But the loop's own stdout IS the
    # candidate-number stream feeding `sort`, so writing there would corrupt the derivation. Bind
    # fd 3 to the real stdout HERE — before the command substitution redirects stdout to its
    # capture — and the annotation reaches the runner's log without entering the stream.
    exec 3>&1

    # NOTE for editors: NO APOSTROPHES in any comment inside the command substitution below, up to
    # its closing `)`. bash 3.2 — the system bash on macOS, where this suite is run locally —
    # treats one as an opening quote even inside a comment, and the whole script then fails to
    # parse. Linux CI runs a newer bash and will NOT catch it for you.
    HEAD_TREE="$(git rev-parse "HEAD^{tree}")"
    patch="$(
      git tag -l "${TAG_PREFIX}v${MM}.*" | while IFS= read -r t; do
        n="$(printf '%s\n' "$t" | sed -nE "s/${patch_re}/\1/p")"
        [ -n "$n" ] || continue
        # A tag may point at a tag object (annotated) or a commit; ^{tree} resolves both to the tree.
        [ "$(git rev-parse "${t}^{tree}" 2>/dev/null)" = "$HEAD_TREE" ] || continue

        # The number sits on OUR tree, but is it still free to use? The tag THIS environment would
        # create for it may already belong to a DIFFERENT tree: the residue of two derivations that
        # raced (see the header). Reusing such a number derives a tag that exists elsewhere, so the
        # guard below refuses and every re-run repeats the same refusal — the promotion stays wedged
        # until a human deletes a tag. Skip the candidate and keep scanning instead, so the highest
        # STILL-USABLE number wins rather than burning a fresh one.
        #
        # The test is the TARGET tag specifically, not "any tag carrying this number". An absent
        # target is ordinary reuse. A target already on our OWN tree is a genuine re-run: it must
        # still be reused here so that it reaches the exists-guard below and fails loudly ("already
        # released"). Rejecting on any tag bearing the number would also fire when the target is
        # free, which in a repository with three environments would give one tree two different
        # build ids — the very inconsistency this heal exists to prevent.
        # `-q --verify` is load-bearing: a bare `git rev-parse <missing-ref>^{tree}` ECHOES its
        # argument back on stdout and exits 0, so an absent target would read as "owned by some
        # other tree" and every ordinary reuse would be healed away into a fresh number.
        target="${TAG_PREFIX}v${MM}.${n}${suffix}"
        target_tree="$(git rev-parse -q --verify "${target}^{tree}" 2>/dev/null || true)"
        if [ -n "$target_tree" ] && [ "$target_tree" != "$HEAD_TREE" ]; then
          printf '::warning title=Duplicate build id::Build id %s.%s is tagged on this tree, but %s already belongs to a different tree — concurrent releases minted the number twice. Not reusing it. Serialize releases per releasable: one concurrency group per tag namespace, with queueing (see CONSUMING.md).\n' \
            "$MM" "$n" "$target" >&3
          continue
        fi

        printf '%s\n' "$n"
      done | sort -n | tail -1
    )"

    exec 3>&- # the annotation channel is only needed for the scan above

    # Step 2 — otherwise advance to the global max patch + 1 (empty set => -1 => 0 => first tag).
    if [ -z "$patch" ]; then
      max="$(git tag -l "${TAG_PREFIX}v${MM}.*" | sed -nE "s/${patch_re}/\1/p" | sort -n | tail -1)"
      patch="$(( ${max:--1} + 1 ))"
    fi

    version="${MM}.${patch}"
    ;;
esac

# The prefix goes on the TAG only; `version` stays the bare number (it is the artifact identity the
# consumer bakes/publishes — the prefix is a tag-namespace concern, not part of the version).
tag="${TAG_PREFIX}v${version}${suffix}"

# Never overwrite or silently reuse a tag. If the target already exists this is a re-run or a
# race (or an attempt to re-tag an already-released number) — fail loudly so no tag is produced
# and the deploy that depends on the tag is skipped rather than silently re-run.
if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Tag ${tag} already exists — refusing to overwrite (re-run, race, or already released)." >&2
  exit 1
fi

# An annotated tag records a tagger identity. A fresh CI runner has no git identity configured,
# which would make `git tag -a` fail with "Committer identity unknown". As a reusable Action we
# must not require the consumer to set this up, so fall back to the GitHub Actions bot identity
# for THIS invocation (env-scoped, never written to global config) when none is present.
if ! git config user.email >/dev/null 2>&1; then
  export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-github-actions[bot]}"
  export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
  export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
  export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"
fi

git tag -a "$tag" -m "Release ${tag}"
git push origin "$tag" # push the TAG only — never a commit, never a branch

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=${version}"
    echo "tag=${tag}"
  } >> "$GITHUB_OUTPUT"
fi
echo "Derived ${tag} on ${BRANCH} (no commit pushed)." >&2
