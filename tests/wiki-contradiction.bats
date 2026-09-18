#!/usr/bin/env bats
# Spec for scripts/wiki-contradiction.sh (issue #196 (a)).
# Evidence-gated: appends ONE contradiction line to log.md only when all six
# fields are present and --count >= 2; refuses (exit 3) otherwise, never
# touching log.md. Missing log -> exit 4. Usage -> exit 2.

bats_require_minimum_version 1.5.0

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/wiki-contradiction.sh"
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  LOOP="${BATS_TEST_DIRNAME}/../skills/loop-implement/SKILL.md"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  printf '%s\n' '# Change Log' '## [2026-01-01] ingest | fixture' > "$WORK/log.md"
  cp "$WORK/log.md" "$WORK/before.md"
  TODAY=$(date -u +%Y-%m-%d)
}

# --- (a) normal ---

@test "normal: six fields with count 2 appends one contradiction line" {
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 0 ]
  [ "$output" = "written" ]
  [ "$(wc -l < "$WORK/log.md")" -eq 3 ]
  last=$(tail -n 1 "$WORK/log.md")
  [[ "$last" == "## [$TODAY] contradiction | pg-composite-index row 2 — task 03-index: verify \`bats tests/x.bats\` failed 2x -> not ok 4 order" ]]
  head -n 2 "$WORK/log.md" > "$WORK/head2.md"
  run cmp "$WORK/head2.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

# --- (b) normal negative control: the assertion actually reads the field ---

@test "normal negative control: a different --task value changes the appended line" {
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 0 ]
  last=$(tail -n 1 "$WORK/log.md")
  [[ "$last" != *"task 99-other"* ]]
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 99-other --count 2 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 0 ]
  [[ "$(tail -n 1 "$WORK/log.md")" == *"task 99-other"* ]]
}

# --- (c) error: missing evidence ---

@test "error: missing --output refuses and leaves log untouched" {
  run --separate-stderr sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --log "$WORK/log.md"
  [ "$status" -eq 3 ]
  [ "$output" = "refused" ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

@test "error: missing --verify refuses and leaves log untouched" {
  run --separate-stderr sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 3 ]
  [ "$output" = "refused" ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

@test "error: empty --page refuses and leaves log untouched" {
  run --separate-stderr sh "$SCRIPT" --page '' --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 3 ]
  [ "$output" = "refused" ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

# --- (d) error negative control: the inverse (all fields present) succeeds ---

@test "error negative control: adding back --output succeeds where (c) refused" {
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --output 'x' --log "$WORK/log.md"
  [ "$status" -eq 0 ]
  [ "$output" = "written" ]
}

# --- (e) boundary: one failure is not a falsification candidate ---

@test "boundary: count 1 refuses and leaves log untouched" {
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 1 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 3 ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

@test "boundary: count 0 refuses and leaves log untouched" {
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 0 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 3 ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

@test "boundary: non-numeric count refuses with 'integer' on stderr" {
  run --separate-stderr sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count two \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"integer"* ]]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

# --- (f) boundary negative control: count 2 is the inverse of (e) ---

@test "boundary negative control: count 2 (the pass threshold) writes" {
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/log.md"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$WORK/log.md")" -eq 3 ]
}

# --- (g) missing log ---

@test "missing log: exit 4, refused, never creates the file" {
  run --separate-stderr sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --output 'not ok 4 order' --log "$WORK/absent/log.md"
  [ "$status" -eq 4 ]
  [ "$output" = "refused" ]
  [ ! -e "$WORK/absent/log.md" ]
}

# --- (h) usage ---

@test "usage: no arguments exits 2 and leaves the fixture identical" {
  run sh "$SCRIPT"
  [ "$status" -eq 2 ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

@test "usage: an unknown flag exits 2 and leaves the fixture identical" {
  run sh "$SCRIPT" --bogus 1 --log "$WORK/log.md"
  [ "$status" -eq 2 ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

@test "usage: --page with no value exits 2 and leaves the fixture identical" {
  run sh "$SCRIPT" --page --log "$WORK/log.md"
  [ "$status" -eq 2 ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

# --- (i) env fallback ---

@test "env fallback: DEV_LOOP_LOG_MD is used when --log is omitted" {
  DEV_LOOP_LOG_MD="$WORK/log.md" run sh "$SCRIPT" --page pg-composite-index --row 2 \
    --task 03-index --count 2 --verify 'bats tests/x.bats' --output 'not ok 4 order'
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$WORK/log.md")" -eq 3 ]
}

@test "env fallback negative control: a missing DEV_LOOP_LOG_MD path exits 4" {
  DEV_LOOP_LOG_MD="$WORK/absent.md" run sh "$SCRIPT" --page pg-composite-index --row 2 \
    --task 03-index --count 2 --verify 'bats tests/x.bats' --output 'not ok 4 order'
  [ "$status" -eq 4 ]
}

# --- (j) default root: HERE/ROOT derivation is independent of cwd ---

@test "default root: log resolves next to the script's own root, not cwd" {
  mkdir -p "$WORK/fake-root/scripts"
  cp "$SCRIPT" "$WORK/fake-root/scripts/"
  printf '# Change Log\n' > "$WORK/fake-root/log.md"
  unset DEV_LOOP_LOG_MD
  cd "$WORK"
  run sh "$WORK/fake-root/scripts/wiki-contradiction.sh" --page pg-composite-index --row 2 \
    --task 03-index --count 2 --verify 'bats tests/x.bats' --output 'not ok 4 order'
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$WORK/fake-root/log.md")" -eq 2 ]
  run cmp "$WORK/log.md" "$WORK/before.md"
  [ "$status" -eq 0 ]
}

@test "default root negative control: no log.md next to root exits 4" {
  mkdir -p "$WORK/fake-root2/scripts"
  cp "$SCRIPT" "$WORK/fake-root2/scripts/"
  unset DEV_LOOP_LOG_MD
  cd "$WORK"
  run sh "$WORK/fake-root2/scripts/wiki-contradiction.sh" --page pg-composite-index --row 2 \
    --task 03-index --count 2 --verify 'bats tests/x.bats' --output 'not ok 4 order'
  [ "$status" -eq 4 ]
}

# --- (k) truncation and flattening ---

@test "truncation: newlines/tabs flatten to spaces and output caps at 300 bytes" {
  long=$(printf 'x%.0s' $(seq 1 400))
  run sh "$SCRIPT" --page p --row 1 --task t --count 2 \
    --verify v --output "$(printf 'line1\nline2\t%s' "$long")" --log "$WORK/log.md"
  [ "$status" -eq 0 ]
  last=$(tail -n 1 "$WORK/log.md")
  [[ "$last" != *$'\n'* ]]
  [[ "$last" == *"line1 line2 "* ]]
  [ "${#last}" -le 400 ]
}

@test "truncation negative control: a short output keeps its full text" {
  run sh "$SCRIPT" --page pg-composite-index --row 2 --task 03-index --count 2 \
    --verify 'bats tests/x.bats' --output 'a short fifty character excerpt of failing tests' --log "$WORK/log.md"
  [ "$status" -eq 0 ]
  [[ "$(tail -n 1 "$WORK/log.md")" == *"a short fifty character excerpt of failing tests"* ]]
}

# --- (l) no CLAUDE_* dependence ---

@test "no CLAUDE_* dependence: the script never reads a CLAUDE_ variable" {
  [ "$(grep -c '\$CLAUDE_' "$SCRIPT")" -eq 0 ]
  [ "$(grep -v '^#' "$SCRIPT" | grep -c 'pwd -P')" -eq 2 ]
}

@test "no CLAUDE_* dependence negative control: the detector fires on a file that does read one" {
  printf 'x=$CLAUDE_PLUGIN_ROOT\n' > "$WORK/bad.sh"
  [ "$(grep -c '\$CLAUDE_' "$WORK/bad.sh")" -eq 1 ]
}

# --- prose wiring (skills/loop-implement/SKILL.md) ---

@test "prose: loop-implement names the script, the evidence predicate, and the byte-exact retry sentence" {
  loop=$(cat "$LOOP")
  [[ "$loop" == *"scripts/wiki-contradiction.sh --page <id>"* ]]
  [[ "$loop" == *"failed at least twice on that"* ]]
  [[ "$loop" == *"page falsification candidate"* ]]
  [[ "$loop" == *"Bounded: ≤3 attempts per task; 3rd failure STOPs + escalates."* ]]
}

@test "prose: the falsification branch sits inside rule 4 and the 7b block" {
  rule4=$(awk '/^4\. \*\*Apply wiki directives/{p=1} /^5\. \*\*Cite/{p=0} p' "$LOOP")
  [[ "$rule4" == *"wiki-contradiction.sh"* ]]
  step7b=$(awk '/^7b\. Reflect/{p=1} /^```/{p=0} p' "$LOOP")
  [[ "$step7b" == *"records the"* ]]
  [[ "$step7b" == *"budget below is unchanged"* ]]
}

@test "prose negative control: stripping the falsification wording removes it from the rule-4 extraction" {
  grep -v -e 'falsification candidate' -e 'wiki-contradiction.sh' "$LOOP" > "$WORK/stripped.md"
  stripped=$(cat "$WORK/stripped.md")
  [[ "$stripped" != *"page falsification candidate"* ]]
  rule4_stripped=$(awk '/^4\. \*\*Apply wiki directives/{p=1} /^5\. \*\*Cite/{p=0} p' "$WORK/stripped.md")
  [[ "$rule4_stripped" != *"wiki-contradiction.sh"* ]]
}

@test "prose: the NOTES field points at the contradiction line it wrote" {
  loop=$(cat "$LOOP")
  [[ "$loop" == *"the log.md contradiction line it wrote>"* ]]
}
