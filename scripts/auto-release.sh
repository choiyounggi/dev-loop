#!/usr/bin/env bash
# dev-loop — detect whether main has unreleased commits and compute the next
# semver from conventional-commit messages.
#
# This is the detection half of the auto-release pipeline (see
# .github/workflows/auto-release.yml, which acts on its output) — it never
# edits a file, commits, or pushes, so it is safe to run locally or in CI
# read-only. The bump rule, applied to every commit since the current
# version's tag (subjects and bodies):
#   major  — a subject like "type!: ..." / "type(scope)!: ...", or a body
#            containing "BREAKING CHANGE"
#   minor  — a "feat: ..." / "feat(scope): ..." subject
#   patch  — anything else (fix, docs, chore, refactor, merge commits, ...)
# The highest rule that matches anywhere in the range wins.
#
# Usage: auto-release.sh [repo-root]   (repo-root defaults to ".")
#
# Output (stdout):
#   need: <current> <next>            — unreleased commits exist; bump to <next>
#   skip: v<version> awaiting tag     — plugin.json is ahead of the tags: a
#                                       release is already in flight (auto-tag
#                                       will create the tag for it)
#   skip: nothing new since v<version> — tag matches and no commits follow it
#
# Exit codes:
#   0  detection completed (need or skip — see stdout for which)
#   1  the computed next version already has a tag (COLLISION on stderr) —
#      the version history regressed; fix by hand before automating further
#   2  usage error, or missing/unparseable plugin.json version
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: auto-release.sh [repo-root]" >&2
  exit 2
fi

REPO_ROOT="${1:-.}"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"

[ -f "$PLUGIN_JSON" ] || { echo "auto-release: $PLUGIN_JSON not found" >&2; exit 2; }
version=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null) || {
  echo "auto-release: $PLUGIN_JSON is not valid JSON" >&2; exit 2;
}
# Exactly three all-digit segments — a rejoining `read` split cannot check
# the segment COUNT (a 4th field folds into $patch as "3.4" and passes a
# character-class test), so validate the whole string first.
printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || {
  echo "auto-release: version '$version' is not X.Y.Z" >&2; exit 2;
}
IFS=. read -r major minor patch <<EOF
$version
EOF

# Current version not tagged yet -> a release is in flight; bumping again now
# would skip a version. auto-tag.yml owns this state.
if ! git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
  echo "skip: v$version awaiting tag"
  exit 0
fi

count=$(git -C "$REPO_ROOT" rev-list --count "v$version..HEAD")
if [ "$count" -eq 0 ]; then
  echo "skip: nothing new since v$version"
  exit 0
fi

subjects=$(git -C "$REPO_ROOT" log "v$version..HEAD" --format='%s')
bodies=$(git -C "$REPO_ROOT" log "v$version..HEAD" --format='%B')

bump=patch
if printf '%s\n' "$subjects" | grep -Eq '^[a-z]+(\([^)]*\))?!:' \
  || printf '%s\n' "$bodies" | grep -qF 'BREAKING CHANGE'; then
  bump=major
elif printf '%s\n' "$subjects" | grep -Eq '^feat(\([^)]*\))?:'; then
  bump=minor
fi

case "$bump" in
  major) next="$((major + 1)).0.0" ;;
  minor) next="$major.$((minor + 1)).0" ;;
  patch) next="$major.$minor.$((patch + 1))" ;;
esac

if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/v$next" >/dev/null; then
  echo "COLLISION: computed next version $next already has a tag (current: $version)" >&2
  exit 1
fi

echo "need: $version $next"
