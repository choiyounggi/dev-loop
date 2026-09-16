#!/bin/sh
# graph-hooks.sh — install / uninstall / status of dev-loop's marker-delimited
# post-merge hook (templates/graph-post-merge.sh) in ONE git repo.
#
# usage: graph-hooks.sh install   <repo>
#        graph-hooks.sh uninstall <repo>
#        graph-hooks.sh status    <repo>
#
# The hook file is `$(git -C <repo> rev-parse --git-path hooks)/post-merge` —
# the directory git will actually run. When that directory lies outside the
# repo's own `--git-common-dir` (a core.hooksPath override) every verb refuses:
#   stdout `cannot-evaluate hooks-path-override`  exit 4  (nothing written)
# The block is delimited by the exact lines
#   # dev-loop-graph-merge-start
#   # dev-loop-graph-merge-end
#
# install   absent file  -> create `#!/bin/sh` + block, chmod 755   stdout `installed <path>`         exit 0
#           foreign file -> append a blank line + block (never overwrite) stdout `installed <path>`   exit 0
#           block present -> no change                              stdout `already-installed <path>` exit 0
#           also appends the line `graphify-out/` to `$(git rev-parse --git-path info/exclude)`
#           once (creating the file if needed); never touches .gitignore
# uninstall block present -> remove start..end inclusive, keep foreign content,
#           delete the file when only `#!/bin/sh` (or nothing) remains        stdout `uninstalled <path>` exit 0
#           block absent  -> no change                              stdout `not-installed`           exit 0
# status    stdout `ok`      exit 0  graphify post-commit (`# graphify-hook-start`) AND
#                                    graphify post-checkout (`# graphify-checkout-hook-start`) AND
#                                    dev-loop post-merge block all present
#           stdout `partial` exit 2  any proper subset, or a broken dev-loop block
#           stdout `none`    exit 3  none of the three
# Every verb:
#   <repo> is not a git work tree           stdout `cannot-evaluate not-git`        exit 4
#   start marker without its end marker     stdout `cannot-evaluate broken-marker`  exit 4 (install/uninstall write nothing)
#   bad verb / missing operand              stdout `cannot-evaluate usage`          exit 4
# Never runs graphify. Never installs graphify's own hooks (the onboarding skill
# runs `graphify hook install` itself). Never called from a SessionStart hook.
# contract: t6-graph-scripts owns the implementation
echo "graph-hooks: contract stub, not implemented" >&2; exit 4
