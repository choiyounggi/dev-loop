#!/usr/bin/env bats
# Spec for skills/wiki-plan/scripts/emit-gaps.sh (issue #193).
# Judge/side-effect split: plan-gate.sh judges, emit-gaps.sh records.

bats_require_minimum_version 1.5.0

setup() {
  EG="${BATS_TEST_DIRNAME}/../skills/wiki-plan/scripts/emit-gaps.sh"
  FIX="${BATS_TEST_DIRNAME}/fixtures/plan-gate"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK/queue"
  printf '# Change Log\n\n' > "$WORK/log.md"
  export DEV_LOOP_LOG_MD="$WORK/log.md" DEV_LOOP_QUEUE_DIR="$WORK/queue"
  cd "$WORK"
}

@test "normal: two [no-wiki] rows produce two log lines and two queue rows" {
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
  [ "$(grep -c '^## \[' "$WORK/log.md")" -eq 2 ]
  [[ "$(cat "$WORK/log.md")" == *"gap | nowiki/D2: Queue write path — direct JSONL append"* ]]
  [[ "$(cat "$WORK/log.md")" == *"gap | nowiki/D4: Gap line key — date-free prefix"* ]]
  [ "$(wc -l < "$WORK/queue/plan-gaps.jsonl")" -eq 2 ]
}

@test "queue row schema: harvest.js key set, status/tags/directive, evidence content" {
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  row=$(head -1 "$WORK/queue/plan-gaps.jsonl")
  keys=$(printf '%s' "$row" | node -e '
    const r = JSON.parse(require("fs").readFileSync(0, "utf8"));
    console.log(Object.keys(r).sort().join(","));
    console.log(r.status, r.tags.join(","), r.directive);
  ')
  [[ "$keys" == *"content,cwd,directive,domain,evidence,extra,harvestedAt,hash,repo,sessionId,status,tags,trigger,why"* ]]
  [[ "$keys" == *"pending plan-gap,nowiki direct JSONL append"* ]]
  evidence=$(printf '%s' "$row" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).evidence)')
  [[ "$evidence" == *"design.md D2"* ]]
  [[ "$evidence" == *"jsonl dedupe (https://example.invalid/dedupe)"* ]]
}

@test "hash parity: queue row hash equals harvest.js contentHash of its own content" {
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  row=$(head -1 "$WORK/queue/plan-gaps.jsonl")
  ref=$(printf '%s' "$row" | node -e '
    const c = require("crypto");
    const r = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const n = r.content.replace(/\s+/g, " ").trim().toLowerCase();
    console.log(c.createHash("sha256").update(n).digest("hex").slice(0, 16));
  ')
  got=$(printf '%s' "$row" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).hash)')
  [[ "$got" == "$ref" ]]
}

@test "idempotent: running twice does not duplicate log lines or queue rows" {
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
  [ "$(grep -c '^## \[' "$WORK/log.md")" -eq 2 ]
  [ "$(wc -l < "$WORK/queue/plan-gaps.jsonl")" -eq 2 ]
}

@test "dedupe against processed store: a row already in .processed.jsonl is not re-queued" {
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  head -1 "$WORK/queue/plan-gaps.jsonl" > "$WORK/queue/.processed.jsonl"
  rm "$WORK/queue/plan-gaps.jsonl"
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$WORK/queue/plan-gaps.jsonl")" -eq 1 ]
  [[ "$(cat "$WORK/queue/plan-gaps.jsonl")" == *"\"hash\""* ]]
  remaining=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).directive)' "$WORK/queue/plan-gaps.jsonl")
  [[ "$remaining" == "date-free prefix" ]]
}

@test "boundary zero rows: a design.md with no [no-wiki] rows writes nothing" {
  run --separate-stderr sh "$EG" "$FIX/passing"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
  [ "$(grep -c '^## \[' "$WORK/log.md")" -eq 0 ]
  [ ! -e "$WORK/queue/plan-gaps.jsonl" ]
  [[ "$stderr" == *"0 [no-wiki]"* ]]
}

@test "error unwritable log.md: warns on stderr, still ok, queue still written" {
  chmod 0444 "$WORK/log.md"
  if [ -w "$WORK/log.md" ]; then
    skip "running as root: chmod 0444 has no effect"
  fi
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
  [[ "$stderr" == *"emit-gaps: warning:"* ]]
  [[ "$stderr" == *"log.md"* ]]
  [ "$(wc -l < "$WORK/queue/plan-gaps.jsonl")" -eq 2 ]
}

@test "error absent log.md: warns on stderr, never creates the file, queue still written" {
  rm "$WORK/log.md"
  run --separate-stderr sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
  [ ! -e "$WORK/log.md" ]
  [[ "$stderr" == *"$WORK/log.md"* ]]
  [ "$(wc -l < "$WORK/queue/plan-gaps.jsonl")" -eq 2 ]
}

@test "error node missing: warns on stderr, log still written, queue skipped" {
  mkdir -p "$WORK/bin"
  for cmd in sh awk grep sed date mkdir basename dirname cat head wc; do
    ln -s "$(command -v "$cmd")" "$WORK/bin/$cmd"
  done
  run --separate-stderr env PATH="$WORK/bin" sh "$EG" "$FIX/nowiki"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
  [[ "$stderr" == *"node"* ]]
  [ "$(grep -c '^## \[' "$WORK/log.md")" -eq 2 ]
  [ ! -e "$WORK/queue/plan-gaps.jsonl" ]
}

@test "missing design.md: fails with exit 4 and prints fail" {
  run --separate-stderr sh "$EG" "$FIX/missing/empty-dir"
  [ "$status" -eq 4 ]
  [[ "$output" == "fail" ]]
}

@test "usage: no plan-dir argument exits 2" {
  run --separate-stderr sh "$EG"
  [ "$status" -eq 2 ]
}

@test "prose wiring: SKILL.md gate-ids line and plan-gates.md both name gaps-emitted" {
  [[ "$(grep -n 'Gate ids:' "${BATS_TEST_DIRNAME}/../skills/wiki-plan/SKILL.md" | grep groundings-exist)" == *"gaps-emitted"* ]]
  [[ "$(cat "${BATS_TEST_DIRNAME}/../templates/plan-gates.md")" == *"- [ ] gaps-emitted:"* ]]
}
