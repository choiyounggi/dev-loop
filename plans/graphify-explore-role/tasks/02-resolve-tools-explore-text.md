# Task 02: resolve-tools explore default text names the graphify option
## Objective
`scripts/resolve-tools.sh`'s built-in `explore` default keeps `kind: default` but its `when` text points at the graphify cli option, and `tests/resolve-tools.bats` proves both the unchanged default and a `{"kind":"cli","ref":"graphify"}` config resolving.
## Wiki pages (read these first, only these)
- wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md — use for: directive 5 (CLI delivery) wording of the `when` text
- wiki/testing/quality/tests-that-cannot-fail.md — use for: the new case asserts the configured `ref`, not merely a non-empty object
## Inputs
- Decisions that bind you: D10 (default kind stays `default`; only the `when` text changes)
- Constraint from analysis.md: tests/resolve-tools.bats:20 pins `.explore.kind == "default"` with no config
## Steps
1. In `scripts/resolve-tools.sh`, inside the `DEFAULTS='{ ... }'` literal, replace the `explore` line's `when` value `locating code, symbols, call sites (step 1)` with `locating code, symbols, call sites (step 1); with a fresh graphify graph, configure {"kind":"cli","ref":"graphify"} — see references/tool-profile.md` (single-quoted heredoc-free JSON: the value must stay a valid JSON string; use no single quotes inside it).
2. Run `bash scripts/resolve-tools.sh --json | jq -e '.explore.kind == "default"'` to confirm the default is intact.
3. In `tests/resolve-tools.bats`, after the `design role is configurable` case, add:
   ```
   @test "explore role is configurable as the graphify cli (lead-not-evidence orientation layer)" {
     printf '{"explore":{"kind":"cli","ref":"graphify","how":"graphify explain \\"<Symbol>\\" --graph <root>/graphify-out/graph.json | head -40"}}' > "$PROJ_CFG"
     run bash "$RT" --role explore
     [ "$status" -eq 0 ]
     [ "$(printf '%s' "$output" | jq -r '.kind')" = "cli" ]
     [ "$(printf '%s' "$output" | jq -r '.ref')" = "graphify" ]
     [[ "$(printf '%s' "$output" | jq -r '.how')" == *'graphify explain'* ]]
   }
   @test "no config: explore default text points at the graphify option without changing kind" {
     run bash "$RT" --role explore
     [ "$status" -eq 0 ]
     [ "$(printf '%s' "$output" | jq -r '.kind')" = "default" ]
     [[ "$(printf '%s' "$output" | jq -r '.when')" == *'graphify'* ]]
   }
   ```
## Deliverables
- scripts/resolve-tools.sh (modified: one `when` string)
- tests/resolve-tools.bats (modified: two cases appended)
## Verify
- `PATH=/opt/homebrew/bin:$PATH bats tests/resolve-tools.bats` → all `ok` (existing cases plus 2)
- covers: R9 (resolve-tools half; the docs half is task 05)
## Out of scope
- references/tool-profile.md and examples/tools.example.json (task 05); any SKILL.md text.
