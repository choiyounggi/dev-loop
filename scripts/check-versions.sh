#!/usr/bin/env bash
# dev-loop — CI-enforced version consistency between plugin.json and this
# repo's own entry in marketplace.json.
#
# A Claude Code marketplace serves updates keyed on the marketplace version
# string (wiki/platforms/tools/version-keyed-artifact-cache.md): a stale
# duplicate means code ships with no version bump, so installed users never
# receive it. This is exactly where a real release incident occurred here —
# marketplace.json drifted from plugin.json, unenforced.
#
# Pairing rule: match marketplace.json .plugins[] entries against plugin.json
# by NAME, not by the marketplace entry's source path. This marketplace is
# self-referential — its one entry describes the plugin living in this same
# repo, and that entry's source is a git URL
# ({"source":"url","url":"https://github.com/..."}), not a local path — so a
# source-path-keyed comparison would find nothing to resolve and the gate
# would never fire on its only entry. Zero name-matching entries is itself a
# failure: a gate that finds nothing to check must go red, never pass silently.
#
# Usage: check-versions.sh [repo-root]   (repo-root defaults to ".")
#
# Exit codes:
#   0  marketplace has an entry named like plugin.json's plugin, and its
#      version matches
#   1  version mismatch, or marketplace has no entry for the plugin name
#   2  usage error, or missing/unparseable plugin.json / marketplace.json
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: check-versions.sh [repo-root]" >&2
  exit 2
fi

REPO_ROOT="${1:-.}"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

for f in "$PLUGIN_JSON" "$MARKETPLACE"; do
  if [ ! -f "$f" ]; then
    echo "check-versions: file not found: $f" >&2
    exit 2
  fi
  if ! jq empty "$f" >/dev/null 2>&1; then
    echo "check-versions: unparseable JSON: $f" >&2
    exit 2
  fi
done

plugin_name=$(jq -r '.name' "$PLUGIN_JSON")
plugin_version=$(jq -r '.version' "$PLUGIN_JSON")

if [ "$plugin_name" = "null" ] || [ -z "$plugin_name" ]; then
  echo "check-versions: $PLUGIN_JSON has no .name" >&2
  exit 2
fi
if [ "$plugin_version" = "null" ] || [ -z "$plugin_version" ]; then
  echo "check-versions: $PLUGIN_JSON has no .version" >&2
  exit 2
fi

count=$(jq '.plugins | length' "$MARKETPLACE")
matched=0
status=0
i=0
while [ "$i" -lt "$count" ]; do
  entry_name=$(jq -r ".plugins[$i].name" "$MARKETPLACE")

  if [ "$entry_name" != "$plugin_name" ]; then
    echo "skip: $entry_name (not $plugin_name)"
    i=$((i + 1))
    continue
  fi

  matched=$((matched + 1))
  entry_version=$(jq -r ".plugins[$i].version" "$MARKETPLACE")

  if [ "$entry_version" = "null" ] || [ -z "$entry_version" ]; then
    echo "check-versions: marketplace entry for $plugin_name has no version" >&2
    status=1
  elif [ "$entry_version" = "$plugin_version" ]; then
    echo "ok: $plugin_name $plugin_version"
  else
    echo "check-versions: version mismatch for $plugin_name: marketplace=$entry_version plugin.json=$plugin_version — sync the two" >&2
    status=1
  fi

  i=$((i + 1))
done

if [ "$matched" -eq 0 ]; then
  echo "check-versions: marketplace has no entry for $plugin_name" >&2
  exit 1
fi

exit "$status"
