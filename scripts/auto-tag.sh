#!/usr/bin/env bash
# dev-loop — detect whether plugin.json's version needs a release tag.
#
# Releases today: bump plugin.json + marketplace.json via PR, merge, then
# hand-create tag v<version>. This script is the detection half of
# automating that last step (see .github/workflows/auto-tag.yml, which acts
# on its output) — it never creates or pushes a tag itself, so it is safe to
# run locally or in CI read-only.
#
# Usage: auto-tag.sh [repo-root]   (repo-root defaults to ".")
#
# Output (stdout):
#   need: vX.Y.Z <name>       — tag vX.Y.Z does not exist yet; create it
#   skip: vX.Y.Z already released   — tag exists and matches plugin.json
#
# Exit codes:
#   0  detection completed (need or skip — see stdout for which)
#   1  tag exists but its plugin.json version collides with the current one
#      (COLLISION printed to stderr with both versions)
#   2  usage error, or missing/unparseable/incomplete plugin.json
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: auto-tag.sh [repo-root]" >&2
  exit 2
fi

REPO_ROOT="${1:-.}"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"

if [ ! -f "$PLUGIN_JSON" ]; then
  echo "auto-tag: file not found: $PLUGIN_JSON" >&2
  exit 2
fi
if ! jq empty "$PLUGIN_JSON" >/dev/null 2>&1; then
  echo "auto-tag: unparseable JSON: $PLUGIN_JSON" >&2
  exit 2
fi

name=$(jq -r '.name' "$PLUGIN_JSON")
version=$(jq -r '.version' "$PLUGIN_JSON")

if [ "$name" = "null" ] || [ -z "$name" ]; then
  echo "auto-tag: $PLUGIN_JSON has no .name" >&2
  exit 2
fi
if [ "$version" = "null" ] || [ -z "$version" ]; then
  echo "auto-tag: $PLUGIN_JSON has no .version" >&2
  exit 2
fi

tag="v$version"

if ! git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "need: $tag $name"
  exit 0
fi

tagged_version=$(git -C "$REPO_ROOT" show "$tag:.claude-plugin/plugin.json" 2>/dev/null | jq -r '.version' 2>/dev/null || true)

if [ "$tagged_version" = "$version" ]; then
  echo "skip: $tag already released"
  exit 0
fi

echo "auto-tag: COLLISION — tag $tag exists but its plugin.json version ($tagged_version) does not match the current plugin.json version ($version)" >&2
exit 1
