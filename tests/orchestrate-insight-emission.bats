#!/usr/bin/env bats
# Tests for skills/orchestrate/SKILL.md Phase 4's insight-emission rule
# (i83-insight-emission, issue #83): after a rework round's fix is confirmed,
# emit one ★ Insight candidate per fixed `## Findings` item; `## Non-blocking`
# items never emit.
#
# A checker's own report is not evidence it works until it has been shown to
# fail on something (wiki/testing/quality/checks-that-cannot-pass.md) — each
# structural assertion below has a paired negative control that strips the
# asserted span from a copy and shows the same check fail
# (wiki/testing/quality/spec-artifact-checks.md).
#
# The harvest tests exercise hooks/harvest.js for real (per-test $HOME, same
# invocation pattern as tests/harvest.bats) rather than asserting keyword
# presence — this proves the emission rule's format is actually compatible
# with the frozen harvester, and that the worked example's own placeholder
# text is not itself harvested if a session ever quotes it verbatim.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/orchestrate/SKILL.md"
  HARVEST="${REPO_ROOT}/hooks/harvest.js"

  command -v node >/dev/null || {
    echo "node is required to run the harvest end-to-end tests"
    return 1
  }

  HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME/.dev-loop/queue"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
}

# Extracts the "## Phase 4" section: from its heading up to (not including)
# the next "## " heading. Same technique as tests/orchestrate-review-pass.bats.
phase4_section() {
  awk '/^## Phase 4/{p=1} p && /^## / && !/^## Phase 4/{exit} p' "$1"
}

# JSON-encodes stdin (may contain real newlines) for embedding as a message
# content field.
_json_string() {
  node -e '
    let s=""; process.stdin.on("data", d => s += d);
    process.stdin.on("end", () => process.stdout.write(JSON.stringify(s)));
  '
}

# Writes a one-line assistant-turn transcript at $1 whose content is $2.
_write_transcript() { # <path> <content>
  local content_json
  content_json="$(printf '%s' "$2" | _json_string)"
  printf '{"message":{"role":"assistant","content":%s}}\n' "$content_json" > "$1"
}

_run_harvest() { # <session_id> <transcript>
  printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$WORK" "$1" "$2" | \
    HOME="$HOME" node "$HARVEST"
}

_queue_lines() { # <session_id>
  local f="$HOME/.dev-loop/queue/$1.jsonl"
  [ -f "$f" ] || { echo 0; return; }
  awk 'NF { c++ } END { print c + 0 }' "$f"
}

# --- normal: the emission rule states both firing conditions ---------------

@test "Phase 4 states both emission firing conditions: fixed Findings item + confirmed re-review" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"Insight emission"* ]]
  [[ "$section" == *"## Findings"* ]]
  [[ "$section" == *"confirmed"* ]]
  [[ "$section" == *"re-review"* ]]
}

# --- boundary: the Non-blocking negative is explicitly stated --------------

@test "Phase 4 explicitly states Non-blocking items never emit" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"## Non-blocking"* ]]
  [[ "$section" == *"never emit"* ]]
}

# --- normal: frozen format + cap are both referenced -----------------------

@test "the emission rule references the frozen block format and the 0-3 cap" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"hooks/insight-instruction.sh"* ]]
  [[ "$section" == *"cap"* ]]
  [[ "$section" == *"highest-signal"* ]]
}

# --- normal: worked example is fenced and maps all three fields ------------

@test "a fenced worked example maps trigger, directive, and evidence" {
  section="$(phase4_section "$SKILL")"
  fence_count="$(printf '%s\n' "$section" | grep -c '^```' || true)"
  [ "$fence_count" -eq 2 ]
  [[ "$section" == *'trigger:'* ]]
  [[ "$section" == *'directive:'* ]]
  [[ "$section" == *'evidence:'* ]]
  [[ "$section" == *'reviews/<task>-rN.md'* ]]
}

# --- negative control: stripping the emission rule fails the presence check -

@test "negative control: a SKILL.md copy with the emission rule removed fails the presence check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-emission.md"
  awk '
    /^\*\*Insight emission\.\*\*/ { skip=1 }
    /^## Splitting a task mid-run/ { skip=0 }
    !skip { print }
  ' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped")"
  [[ "$section" != *"Insight emission"* ]]
}

# --- negative control: stripping just the Non-blocking negative ------------

@test "negative control: a copy with the Non-blocking sentence removed fails the boundary check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-nonblocking-negative.md"
  grep -v 'never emit' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped")"
  [[ "$section" != *"never emit"* ]]
}

# --- negative control: stripping one fence breaks the fenced-example check -

@test "negative control: a copy with the closing fence removed fails the fenced-example check" {
  stripped="${BATS_TEST_TMPDIR}/skill-broken-fence.md"
  # drop the ``` fence immediately following the box-drawing closing
  # delimiter line (`─────...`) — that is this block's own closing fence,
  # not the unrelated ```json fences elsewhere in the file.
  awk '
  {
    if (skip_next && $0 ~ /^```$/) { skip_next=0; next }
    print
    if ($0 ~ /^─+$/) skip_next=1
  }
  ' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped")"
  fence_count="$(printf '%s\n' "$section" | grep -c '^```' || true)"
  [ "$fence_count" -ne 2 ]
}

# --- harvest end-to-end: a coordinator-emitted block citing a review round --
# --- is queued by hooks/harvest.js (per-test $HOME, like tests/harvest.bats) --

@test "harvest end-to-end: a coordinator-emitted block citing a review round is queued" {
  body="★ Insight ─────
trigger: a diff added a new CLI flag with no toolchain version check
directive: confirm the flag exists in the deployed toolchain version before approving
why: lens 3 exists to catch exactly this and the first pass missed it
evidence: reviews/i83-insight-emission-r1.md + fixing commit a1b2c3d
─────"
  transcript="${BATS_TEST_TMPDIR}/transcript-real.jsonl"
  _write_transcript "$transcript" "$body"

  run _run_harvest "s1" "$transcript"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines "s1")" -eq 1 ]

  qfile="$HOME/.dev-loop/queue/s1.jsonl"
  [[ "$(cat "$qfile")" == *"toolchain version check"* ]]
}

# --- normal: the worked example's own placeholders are not self-harvested --
# --- if a session ever quotes the fenced section verbatim -------------------

@test "the fenced worked example, if quoted verbatim, is not itself harvested" {
  section="$(phase4_section "$SKILL")"
  example="$(printf '%s\n' "$section" | awk '
    /^```$/ { c++; if (c == 1) { f=1; next } else { exit } }
    f { print }
  ')"
  [ -n "$example" ]
  [[ "$example" == *'trigger:'* ]]

  transcript="${BATS_TEST_TMPDIR}/transcript-selfquote.jsonl"
  _write_transcript "$transcript" "$example"

  run _run_harvest "s2" "$transcript"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines "s2")" -eq 0 ]
}
