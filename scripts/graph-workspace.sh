#!/bin/sh
# graph-workspace.sh — enumerate the git repos under one or more workspace roots
# and report each repo's graphify graph freshness + dev-loop hook status.
#
# usage: graph-workspace.sh --list   [--depth N] [--exclude GLOB]... [--] <root>...
#        graph-workspace.sh --status [--depth N] [--exclude GLOB]... [--] <root>...
#
# A repo is a directory whose `.git` is a DIRECTORY found by
#   find -P <root> -maxdepth <depth> -type d -name .git      (default depth 2)
# so git worktrees (`.git` file), bare repos, and paths reachable only through a
# symlink are never listed. `--exclude GLOB` drops a repo when any path component
# under <root> matches GLOB (shell case pattern).
#
# --list   stdout: one repo path per line (sorted)            exit 0
# --status stdout: one line per repo (sorted), tab-separated:
#            <repo-path>\t<freshness>\thooks: <hooks>
#          <freshness> is scripts/graph-freshness.sh's stdout verbatim:
#            fresh | stale <N> | absent | cannot-evaluate <reason>
#          <hooks> is scripts/graph-hooks.sh status's stdout verbatim:
#            ok | partial | none | cannot-evaluate <reason>
#          exit: the maximum over repos of the freshness exit codes
#            0 all fresh | 2 a stale repo | 3 an absent graph | 4 cannot-evaluate
#          (hook status never changes the exit code)
# Both verbs:
#   no repo under any root       stdout `no-repos`                     exit 0
#   a root is not a directory    stdout `cannot-evaluate missing-root` exit 4
#   bad flags / no verb / no root stdout `cannot-evaluate usage`       exit 4
#   an unreadable directory      one stderr line `skip: unreadable <dir>`, skipped
# Never runs graphify; never writes anything. GRAPHIFY_BIN passes through to
# graph-freshness.sh. Roots are explicit operands — this script never reads
# tools.json (the caller resolves the workspace config).
# contract: t6-graph-scripts owns the implementation
echo "graph-workspace: contract stub, not implemented" >&2; exit 4
