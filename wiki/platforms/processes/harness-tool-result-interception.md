---
id: platforms-processes-harness-tool-result-interception
domain: platforms
category: processes
applies_to: [general]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
last_verified: 2026-08-05
related: [platforms-shells-command-text-inspected-before-execution, platforms-processes-non-interactive-cli-invocation, debugging-methodology-hypothesis-testing]
---

# A Harness Hook Replaced a Tool's Result with a Substitute

## When this applies

You are running inside an agent harness where a plugin or hook wraps a built-in
tool (file read, search, shell) and hands back substitute content — a truncated
result, a redaction, or a note suggesting you call something else instead. Also
when briefing worker sessions you spawn against the same repo.

## Do this

1. **Recognise the shape.** A `PostToolUse` hook's `updatedToolOutput` "replaces
   the tool's result", and the docs name transformation of "inbound tool results"
   as an intended use. So a tool returning one line, an empty body, or prose about
   how to call it differently is a plausible harness substitution, not necessarily
   the file's real content.

2. **Separate substitution from a genuinely empty target first**, with a tool the
   hook does not wrap: `wc -l <path>` and `ls -l <path>`. A one-line result from a
   400-line file is interception; from a one-line file it is the truth.

3. **Test the hook's suggested remediation exactly once**, with the narrowest
   concrete call it describes (the explicit `offset`/`limit`, the alternative
   fetch). The remediation text is written by the hook author, not derived from
   the failure, so it can be wrong.

4. **On the second degraded result, switch tool families for that repo** instead
   of trying more variants: locate with `grep -n '<symbol>' <path>`, then read the
   range with `awk 'NR>=A && NR<=B' <path>`. Two calls settle it; enumerating
   parameter combinations does not.

5. **Record the fallback once and put it in the brief of every session you spawn**
   against that repo. Otherwise each worker rediscovers it independently and pays
   the same three-to-four wasted calls.

## Edge cases

| Case | Then |
|------|------|
| The substitution is silent — no note, just short content | Compare the tool's byte/line count against `wc -c`/`wc -l` before treating the content as complete; a truncation with no message reads exactly like a small file |
| The wrapping hook also intercepts your shell fallback | Read through a different mechanism (an editor/Write-tool round trip, `base64` of a byte range) and escalate the harness configuration to the human — a harness that blocks every read path is a configuration fault, not a puzzle to route around |
| Only some paths are affected | The hook matcher is path- or tool-scoped; establish the boundary with one probe inside and one outside it, then scope the brief's instruction to the affected paths |
| The hook is doing intended redaction (secrets, PII) | Do not route around it — take the redacted result as the answer and request the value through the sanctioned channel |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Retry the tool with the parameters its own error text suggests, repeatedly | Try the suggestion once, then switch to `grep -n` + `awk` range reads | The remediation is authored by the hook, not diagnosed from your failure; repeated variants of a wrong suggestion cost calls without new information |
| Conclude the file is empty or the symbol is absent | Confirm the size with `wc -l` before concluding anything about content | An intercepted read and an empty file are indistinguishable from the result alone |
| Let every spawned worker discover the workaround itself | State the fallback in the spawn brief | The cost is paid once per session instead of once per agent |

## Sources

- https://code.claude.com/docs/en/hooks — `PostToolUse` decision control: `updatedToolOutput` "replaces the tool's result"; "For redaction or transformation use cases, intercept at `PreToolUse` for outbound tool inputs and `PostToolUse` for inbound tool results"
- Field context (2026-08-05): in a repo with a session-memory plugin installed, `Read(path, offset=151, limit=120)` returned only line 1, as did plain reads of three sibling files; the plugin's own note suggested the `offset`/`limit` retry that had just failed. Two independently orchestrated worker sessions each logged the same discovery and each fell back to shell reads before the fallback was added to the spawn brief
