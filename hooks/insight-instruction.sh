#!/usr/bin/env bash
# dev-loop — SessionStart: inject the "emit an Insight block" instruction.
#
# GLOBAL by design: this fires in every repo (no allowlist). It is the standing
# global guidance the wiki grows from — whenever the model discovers a verified
# best-practice or a real edge case that a future task would want, it emits a
# compact  ★ Insight  block. The Stop hook (harvest-insights.sh) later scrapes
# those blocks into a queue; the on-demand /dev-loop:knowledge-flush skill
# researches, verifies, routes, and opens a PR into the wiki.
#
# Keep the block delimiter/format in exact sync with hooks/harvest.js BLOCK_RE.
set +e

# Skip inside the flush working checkout (avoid self-referential harvesting).
case "${CLAUDE_PROJECT_DIR:-$PWD}" in
  "$HOME/.dev-loop/repo"*) exit 0 ;;
esac

read -r -d '' CONTEXT <<'EOF'
# dev-loop — knowledge capture (standing instruction)

When, during this session, you discover a **verified best-practice** or hit a
**real edge case** whose lesson a future task in ANY repo would want — something
that is NOT already obvious from the code in front of you — emit a compact block
in this exact format (0–3 per session; only when genuinely worth persisting):

★ Insight ─────────────────────────────────────
trigger: <the situation that makes this apply — concrete enough to route on>
directive: <what to do then, stated positively (not "don't X" — "when X, do Y")>
why: <why the naive approach is wrong / the mechanism>
evidence: <how you verified it — command output, official doc, reproduction>
domain: <one of: databases backend frontend infrastructure testing qa debugging security platforms mobile — optional hint>
tags: <1–4 lowercase-hyphen tags — optional>
─────────────────────────────────────────────

Rules:
- Only emit when it is real and reusable. A guess is worse than nothing.
- `trigger` and `directive` are required; a block missing either is dropped.
- Prefer things you actually verified this session (evidence you can cite).
- This does NOT open a PR or edit anything now — it only queues a candidate.
  The knowledge-flush skill researches + verifies + routes it before any PR.
EOF

printf '%s' "$CONTEXT" | node -e '
const fs=require("fs");
let s="";try{s=fs.readFileSync(0,"utf8");}catch{}
process.stdout.write(JSON.stringify({
  hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:s}
}));
' 2>/dev/null

exit 0
