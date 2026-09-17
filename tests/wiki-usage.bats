# Spec for scripts/wiki-usage.sh and scripts/wiki-lint-usage.js (issue #196 (b)).
# bash 3.2 rule: the deciding assertion must be last, or a single &&-chained
# compound at the end of the test body; plain `[ ]` tests are fine mid-test.
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  USAGE="$REPO_ROOT/scripts/wiki-usage.sh"
  LINT="$REPO_ROOT/scripts/wiki-lint-usage.js"
  LOOP="$REPO_ROOT/skills/loop-implement/SKILL.md"
  WLINT="$REPO_ROOT/skills/wiki-lint/SKILL.md"
  WORK="$BATS_TEST_TMPDIR/work"; PROJ="$WORK/proj"; WIKI="$PROJ/wiki"
  mkdir -p "$WIKI/alpha/cat" "$WIKI/beta/cat"
  mkpage "$WIKI/alpha/cat/a.md" alpha-cat-a
  mkpage "$WIKI/alpha/cat/b.md" alpha-cat-b
  mkpage "$WIKI/beta/cat/c.md"  beta-cat-c
  mkpage "$WIKI/beta/cat/old.md" beta-cat-old retired
  printf '# idx\n' > "$WIKI/alpha/index.md"
  printf '# idx\n' > "$WIKI/beta/index.md"
  JSONL="$PROJ/.dev-loop/wiki-usage.jsonl"
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
}
mkpage() { # <path> <id> [status]
  { printf -- '---\nid: %s\ndomain: alpha\ncategory: cat\n' "$2"
    if [ -n "${3:-}" ]; then printf 'status: %s\n' "$3"; fi
    printf -- '---\n## When this applies\nx\n'; } > "$1"
}
rec() { # <ts> <page_id>
  printf '{"ts":"%s","page_id":"%s","row":"r","task":"t","source":"report"}\n' "$1" "$2"
}

@test "(a) normal append: WIKI: line becomes one valid JSON record" {
  run sh "$USAGE" --task 03-x --repo "$PROJ" --line 'WIKI: alpha-cat-a → Do this #1 "quoted" back\slash'
  [ "$status" -eq 0 ]
  [ "$output" = appended ]
  [ "$(wc -l < "$JSONL")" -eq 1 ]
  run node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim()); if(r.page_id!=="alpha-cat-a"||r.row!=="Do this #1 \"quoted\" back\\slash"||r.task!=="03-x"||r.source!=="report"||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(r.ts)) process.exit(1); console.log("FIELDS-OK")' "$JSONL"
  [ "$status" -eq 0 ] && [[ "$output" == *"FIELDS-OK"* ]]
}

@test "(a2) negative control: a different --task value shows up instead of the original" {
  run sh "$USAGE" --task 99-y --repo "$PROJ" --line 'WIKI: alpha-cat-a → Do this #1 "quoted" back\slash'
  [ "$status" -eq 0 ]
  [[ "$(cat "$JSONL")" == *'"task":"99-y"'* ]] && [[ "$(cat "$JSONL")" != *'"task":"03-x"'* ]]
}

@test "(c) error malformed: no separator refuses the whole call, file byte-identical" {
  mkdir -p "$PROJ/.dev-loop"; rec "$NOW" alpha-cat-a > "$JSONL"; cp "$JSONL" "$WORK/before"
  run --separate-stderr sh "$USAGE" --task t --repo "$PROJ" --line 'WIKI: no-arrow-here'
  [ "$status" -eq 3 ]
  [ "$output" = refused ]
  run cmp "$JSONL" "$WORK/before"
  [ "$status" -eq 0 ]
}

@test "(c2) error malformed with no pre-existing file: refuses and creates nothing" {
  run sh "$USAGE" --task t --repo "$PROJ" --line 'WIKI: no-arrow-here'
  [ "$status" -eq 3 ]
  [ ! -e "$JSONL" ]
}

@test "(c3) batch atomicity: one bad line among good ones refuses the whole batch" {
  run sh "$USAGE" --task t --repo "$PROJ" --line 'alpha-cat-a → r1' --line 'bad line'
  [ "$status" -eq 3 ]
  [ ! -e "$JSONL" ]
}

@test "(c4) usage errors: missing --task, no args, and an unknown --source all exit 2" {
  run sh "$USAGE" --repo "$PROJ" --line 'alpha-cat-a → r1'
  [ "$status" -eq 2 ]
  run sh "$USAGE"
  [ "$status" -eq 2 ]
  run sh "$USAGE" --task t --repo "$PROJ" --source other --line 'alpha-cat-a → r1'
  [ "$status" -eq 2 ]
}

@test "(e) ASCII arrow separator is accepted like the U+2192 form" {
  run sh "$USAGE" --task t --repo "$PROJ" --line 'alpha-cat-b -> Edge cases row 2'
  [ "$status" -eq 0 ]
  [[ "$(cat "$JSONL")" == *'"page_id":"alpha-cat-b"'* ]] && [[ "$(cat "$JSONL")" == *'"row":"Edge cases row 2"'* ]]
}

@test "(f) plan source accepts a bare wiki path; report source rejects it" {
  run sh "$USAGE" --task t --repo "$PROJ" --source plan --line 'wiki/alpha/cat/a.md'
  [ "$status" -eq 0 ]
  [[ "$(cat "$JSONL")" == *'"page_id":"alpha-cat-a"'* ]] && [[ "$(cat "$JSONL")" == *'"row":"Wiki basis"'* ]] && [[ "$(cat "$JSONL")" == *'"source":"plan"'* ]]
}

@test "(f2) negative control: the same bare path with --source report is refused" {
  run sh "$USAGE" --task t --repo "$PROJ" --source report --line 'wiki/alpha/cat/a.md'
  [ "$status" -eq 3 ]
  [ ! -e "$JSONL" ]
}

@test "(g) creates .dev-loop/ when absent" {
  [ ! -d "$PROJ/.dev-loop" ]
  run sh "$USAGE" --task t --repo "$PROJ" --line 'alpha-cat-a → r'
  [ "$status" -eq 0 ]
  [ -d "$PROJ/.dev-loop" ]
}

@test "(h) boundary: --repo pointing at a non-directory refuses with exit 4" {
  run --separate-stderr sh "$USAGE" --task t --repo "$WORK/nope" --line 'alpha-cat-a → r'
  [ "$status" -eq 4 ]
  [ "$output" = refused ]
  [[ "$stderr" == *"not a directory"* ]]
  [ ! -e "$WORK/nope" ]
}

@test "(i) append-only: a second call adds a line without touching the first" {
  run sh "$USAGE" --task t --repo "$PROJ" --line 'alpha-cat-a → r1'
  [ "$status" -eq 0 ]
  head -n 1 "$JSONL" > "$WORK/first-before"
  run sh "$USAGE" --task t --repo "$PROJ" --line 'alpha-cat-b → r2'
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$JSONL")" -eq 2 ]
  head -n 1 "$JSONL" > "$WORK/first-after"
  run cmp "$WORK/first-before" "$WORK/first-after"
  [ "$status" -eq 0 ]
}

@test "(j) lint normal: one cited page, two uncited, none for the retired page" {
  mkdir -p "$PROJ/.dev-loop"; rec "$NOW" alpha-cat-a > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 3, cited: 1, uncited: 2, skipped: 0, unknown: 0" ]
  [ "$(printf '%s\n' "$stderr" | grep -c '^uncited:')" -eq 2 ]
  [[ "$stderr" == *"/b.md:"* ]] && [[ "$stderr" == *"/c.md:"* ]] && [[ "$stderr" != *"/a.md:"* ]] && [[ "$stderr" != *"old.md"* ]]
}

@test "(j2) negative control: citing a different page flips which pages are uncited" {
  mkdir -p "$PROJ/.dev-loop"; rec "$NOW" beta-cat-c > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"/a.md:"* ]] && [[ "$stderr" == *"/b.md:"* ]] && [[ "$stderr" != *"/c.md:"* ]]
}

@test "(k) boundary: absent usage file is clean, no findings" {
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage data: none"* ]] && [[ "$output" == *"pages: 3, cited: 0, uncited: 0, skipped: 0, unknown: 0"* ]] && [ -z "$stderr" ]
}

@test "(l) boundary: empty and whitespace-only usage files behave like absent" {
  mkdir -p "$PROJ/.dev-loop"
  printf '' > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage data: none"* ]] && [[ "$output" == *"pages: 3, cited: 0, uncited: 0, skipped: 0, unknown: 0"* ]] && [ -z "$stderr" ]
  printf '\n  \n' > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage data: none"* ]] && [[ "$output" == *"pages: 3, cited: 0, uncited: 0, skipped: 0, unknown: 0"* ]] && [ -z "$stderr" ]
}

@test "(l2) negative control: one valid record removes the 'usage data: none' marker" {
  mkdir -p "$PROJ/.dev-loop"; rec "$NOW" alpha-cat-a > "$JSONL"
  run node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [[ "$output" != *"usage data: none"* ]]
}

@test "(m) skipped and unknown records are counted separately from cited/uncited" {
  mkdir -p "$PROJ/.dev-loop"
  { printf 'not json\n'; printf '{"ts":"x","page_id":"alpha-cat-a"}\n'; rec "$NOW" nope-id; } > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 3, cited: 0, uncited: 3, skipped: 2, unknown: 1" ]
}

@test "(m2) negative control: adding a valid citation for the same page changes cited/uncited" {
  mkdir -p "$PROJ/.dev-loop"
  { printf 'not json\n'; printf '{"ts":"x","page_id":"alpha-cat-a"}\n'; rec "$NOW" nope-id; rec "$NOW" alpha-cat-a; } > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 3, cited: 1, uncited: 2, skipped: 2, unknown: 1" ]
}

@test "(n) usage errors: missing root, unknown flag, non-integer months, unparseable --now, non-directory root" {
  run --separate-stderr node "$LINT"
  [ "$status" -eq 4 ] && [ -z "$output" ]
  run --separate-stderr node "$LINT" "$WIKI" --bogus
  [ "$status" -eq 4 ] && [ -z "$output" ]
  run --separate-stderr node "$LINT" "$WIKI" --months x
  [ "$status" -eq 4 ] && [ -z "$output" ]
  run --separate-stderr node "$LINT" "$WIKI" --now bogus
  [ "$status" -eq 4 ] && [ -z "$output" ]
  run --separate-stderr node "$LINT" "$WIKI/does-not-exist"
  [ "$status" -eq 4 ] && [ -z "$output" ]
}

@test "(n2) negative control: valid --months and --now succeed" {
  run node "$LINT" "$WIKI" --months 6 --now "$NOW"
  [ "$status" -eq 0 ]
}

@test "(o) window + retired: an old citation still leaves the page uncited; retired page never appears" {
  mkdir -p "$PROJ/.dev-loop"; rec 2020-01-01T00:00:00Z alpha-cat-a > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pages: 3"* ]] && [[ "$output" == *"uncited: 3"* ]]
  [[ "$stderr" == *"/a.md:"* ]]
  [[ "$output" != *"old.md"* ]] && [[ "$stderr" != *"old.md"* ]]
}

@test "(q) day-31 clamp: a 6-month cutoff from 2026-08-31 lands on 2026-02-28, not overflowed" {
  mkdir -p "$PROJ/.dev-loop"
  { rec 2026-03-01T00:00:00Z alpha-cat-a; rec 2026-02-27T00:00:00Z alpha-cat-b; } > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL" --now 2026-08-31T12:00:00Z --months 6
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 3, cited: 1, uncited: 2, skipped: 0, unknown: 0" ]
  [[ "$stderr" == *"/b.md: no citation since 2026-02-28"* ]] && [[ "$stderr" != *"/a.md:"* ]]
}

@test "(q2) negative control: a 5-month cutoff from the same --now excludes both prior records" {
  mkdir -p "$PROJ/.dev-loop"
  { rec 2026-03-01T00:00:00Z alpha-cat-a; rec 2026-02-27T00:00:00Z alpha-cat-b; } > "$JSONL"
  run --separate-stderr node "$LINT" "$WIKI" --usage "$JSONL" --now 2026-08-31T12:00:00Z --months 5
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 3, cited: 0, uncited: 3, skipped: 0, unknown: 0" ]
}

@test "(b) step 7 names wiki-usage.sh after the report and leaves the t6 hunks intact" {
  run grep -F 'scripts/wiki-usage.sh --task <NN-slug> --repo <project root>' "$LOOP"
  [ "$status" -eq 0 ]
  run grep -F 'its exit code never changes the PASS or FAIL verdict' "$LOOP"
  [ "$status" -eq 0 ]
  [ "$(grep -n -F 'scripts/wiki-usage.sh --task' "$LOOP" | head -1 | cut -d: -f1)" -gt "$(grep -n -F 'WIKI: references you applied).' "$LOOP" | cut -d: -f1)" ]
  [ "$(grep -F -c 'Bounded: ≤3 attempts per task; 3rd failure STOPs + escalates.' "$LOOP")" -eq 1 ]
  [ "$(grep -F -c '4. **Apply wiki directives as written.**' "$LOOP")" -eq 1 ]
  [ "$(grep -F -c '5. **Cite what you applied.**' "$LOOP")" -eq 1 ]
  [ "$(grep -F -c 'scripts/wiki-contradiction.sh --page <id>' "$LOOP")" -eq 1 ]
}

@test "(b2) negative control: stripping the wiki-usage.sh sentence removes the wiring match" {
  grep -v -F 'scripts/wiki-usage.sh' "$LOOP" > "$BATS_TEST_TMPDIR/loop.md"
  run grep -F 'scripts/wiki-usage.sh --task <NN-slug>' "$BATS_TEST_TMPDIR/loop.md"
  [ "$status" -eq 1 ]
}

@test "(d) wiki-lint carries check 18, the info row, total_weight 39 and the Fix protocol sentence" {
  run grep -F '| 18 | Active page with zero citations' "$WLINT"
  [ "$status" -eq 0 ]
  run grep -F '| info | 1 | 10–12, 18 |' "$WLINT"
  [ "$status" -eq 0 ]
  run grep -F 'total_weight = 39' "$WLINT"
  [ "$status" -eq 0 ]
  run grep -F '(7×3 + 7×2 + 4×1)' "$WLINT"
  [ "$status" -eq 0 ]
  run grep -F -e '- For 18: report-only' "$WLINT"
  [ "$status" -eq 0 ]
  run grep -F 'a review queue, never a retire verdict' "$WLINT"
  [ "$status" -eq 0 ]
  run grep -F 'node scripts/wiki-lint-usage.js wiki --usage <repo>/.dev-loop/wiki-usage.jsonl' "$WLINT"
  [ "$status" -eq 0 ]
}

@test "(d2) negative control: stripping the check-18 row removes the wiring match" {
  grep -v -F '| 18 |' "$WLINT" > "$BATS_TEST_TMPDIR/wlint.md"
  run grep -F '| 18 |' "$BATS_TEST_TMPDIR/wlint.md"
  [ "$status" -eq 1 ]
}

@test "(p) README and log.md each carry exactly one wiki-usage entry" {
  [ "$(grep -c 'scripts/wiki-usage.sh + wiki-lint-usage.js' "$REPO_ROOT/README.md")" -eq 1 ]
  [ "$(grep -F -c 'revise | loop-implement step 7 and wiki-lint check 18' "$REPO_ROOT/log.md")" -eq 1 ]
}

@test "(p2) negative control: a README copy without that line reports zero" {
  grep -v -F 'scripts/wiki-usage.sh + wiki-lint-usage.js' "$REPO_ROOT/README.md" > "$BATS_TEST_TMPDIR/readme.md"
  [ "$(grep -c 'scripts/wiki-usage.sh + wiki-lint-usage.js' "$BATS_TEST_TMPDIR/readme.md")" -eq 0 ]
}
