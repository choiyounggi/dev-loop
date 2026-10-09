---
id: platforms-tools-hook-input-fields-from-the-reference
domain: platforms
category: tools
applies_to: [claude-code]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
last_verified: 2026-09-27
verified_model: claude-fable-5-1
related: [platforms-tools-harness-mediated-tool-results, platforms-processes-tool-diagnostics-without-a-failing-exit-code, platforms-shells-redirection-order-for-a-silenced-write]
---

# Hook Input Field Names Taken From the Reference, Not a Sample

## When this applies

Writing or testing a Claude Code hook that parses its stdin JSON — a
`UserPromptSubmit` hook reading the user's text, a `PreToolUse` hook reading
the tool input — and building the fixtures its tests feed it; copying a field
name from a sample or test-helper script; a hook whose tests are green never
fires in a real session.

## Do this

1. **Read each field by the name the hooks reference gives it.** For
   `UserPromptSubmit` the text is `prompt` (`jq -r '.prompt'`), alongside the
   common fields `session_id`, `cwd`, and `hook_event_name`. Open the
   reference's example payload for the event and copy the keys from there.
2. **Build test fixtures from the reference's example payload**, not from a
   sample script, and keep the reference URL in a comment beside the fixture
   so the next editor re-checks the same source.
3. **Run one positive control against a real event.** A fail-open hook that
   reads the wrong key sees an empty value, does nothing, and exits 0 — the
   same outcome as "no match". Trigger the hook once in a live session (or
   capture a real payload with `tee` to a file) and confirm the effect
   appears; the tests alone cannot show it.

| Event | Field for the payload | Fixture shape |
|-------|-----------------------|---------------|
| `UserPromptSubmit` | `prompt` | `{"session_id": "...", "cwd": "...", "hook_event_name": "UserPromptSubmit", "prompt": "..."}` |
| `PreToolUse` / `PostToolUse` | `tool_name`, `tool_input` (and `tool_response` after) | Copy the reference example for the event |

## Edge cases

| Case | Then |
|------|------|
| The fixture and the hook were both copied from the same sample script | They agree with each other and disagree with the runtime; the suite proves only that the hook reads what the fixture writes. Rebuild the fixture from the reference and re-run |
| The plugin-dev `test-hook.sh` sample is the template at hand | Its `UserPromptSubmit` case emits `"user_prompt"` (line 79 in the shipped copy); the runtime sends `prompt`. Replace the key before reusing the sample |
| The hook parses the prompt text and the session marks pasted text | The expanded paste arrives between `<pasted_content id="…">` and `</pasted_content id="…">` lines inside `prompt`; account for those lines in the parser |
| The reference and the sample disagree on any key | The reference wins; open an issue on the sample rather than adapting the hook to it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Take `.user_prompt` from a helper script | Take `.prompt` from the hooks reference | The sample's key is not what the runtime sends, and a fail-open hook hides the mismatch |
| Trust a green hook test suite as proof the hook fires | Run one positive control in a live session | The suite feeds the hook the fixture's keys, not the runtime's |

## Sources

- https://code.claude.com/docs/en/hooks — "In addition to the common input fields, UserPromptSubmit hooks receive the `prompt` field containing the text the user submitted"; the example input shows `"prompt": "Write a function to calculate the factorial of a number"` (fetched as `hooks.md`, lines 1353 and 1362, 2026-09-27)
- Local check 2026-09-27: `grep -n user_prompt …/plugins/plugin-dev/skills/hook-development/scripts/test-hook.sh` → line 79 `"user_prompt": "Test user prompt"` inside the script's `UserPromptSubmit)` case
- Field evidence 2026-09 (memory-loop correction-signal hook, orchestration task orch-t1): hook and bats fixtures both used `user_prompt`; the suite was green while the hook never fired in a session, and switching both to `prompt` fixed it
