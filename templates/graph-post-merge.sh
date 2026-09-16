# dev-loop-graph-merge-start
# dev-loop: rebuild the graphify code graph after a merge/pull (AST-only, no LLM).
# Installed by: scripts/graph-hooks.sh install — remove with: scripts/graph-hooks.sh uninstall
command -v graphify >/dev/null 2>&1 || exit 0
_dl_top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$_dl_top/graphify-out/graph.json" ] || exit 0
_dl_changed=$(git diff --name-only ORIG_HEAD HEAD 2>/dev/null)
[ -n "$_dl_changed" ] || exit 0
graphify update "$_dl_top" >/dev/null 2>&1 || exit 0
exit 0
# dev-loop-graph-merge-end
