---
id: platforms-tools-harness-mediated-tool-results
domain: platforms
category: tools
applies_to: [claude-code, agent-harness]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
  - https://code.claude.com/docs/en/tools-reference
last_verified: 2026-09-03
related: [platforms-shells-command-text-inspected-before-execution, platforms-processes-non-interactive-cli-invocation, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, platforms-tools-agent-permission-classifier-denials]
---

# A Plugin Rewrites What a Tool Returns Before the Agent Sees It

## When this applies

A file-reading or search tool returns content that does not match the file on
disk — truncated to the first line, summarized, or replaced by a note telling you
to call something else; a plugin/hook is installed in the session; or you are
about to brief worker sessions that will read files in the same repo.
Also when a fetch tool (`WebFetch`) returns a summary written by a small,
fast intermediary model rather than the page's raw text, and you are about
to record a quoted sentence or number from that summary as verified.

## Do this

1. **Read the substitution as a hook, not as the file.** A `PostToolUse` hook
   returns `hookSpecificOutput.updatedToolOutput`, which *replaces* the tool's
   result before the model sees it; `PreToolUse` returns
   `hookSpecificOutput.updatedInput`, which rewrites the arguments before the
   tool runs. The docs name this the interception point "for redaction or
   transformation use cases". The file is intact; the channel to it is mediated.

2. **Separate substitution from a genuinely empty target first**, with a tool the
   hook does not wrap: `wc -l <path>` and `ls -l <path>`. A one-line result from a
   400-line file is interception; from a one-line file it is the truth.

3. **Test the hook's suggested remediation exactly once**, with the narrowest
   concrete call it describes (the explicit `offset`/`limit`, the alternative
   fetch). The remediation text is written by the hook author, not derived from
   the failure, so it can be wrong.

| Result of the one retry | Do |
|---|---|
| Returns the real content | Use the suggested form for the rest of the session |
| Returns the same substitution again | Switch to the shell path (step 4) and stop retrying the tool |

4. **Reach the bytes through a channel the hook does not match.** Hooks are
   registered per tool name, so a different tool is not intercepted: locate with
   `grep -n '<symbol>' <path>`, then read the range with
   `awk 'NR>=120 && NR<=240' <path>`. Confirm the fallback works by checking the
   output has more than one line before relying on it.

5. **Put the resolved channel in the brief of every session you spawn against
   that repo.** State the tool that is mediated, that its own remediation was
   tested and failed, and the exact fallback command form. Each worker that
   rediscovers this spends its own probe-retry-fallback round on it.

6. **Record the file's real length once** (`wc -l`) so later range reads are
   bounded by a number you measured, not by a truncated view.

## Edge cases

| Case | Then |
|------|------|
| Only some files return the substitution | The hook matched on a path pattern; treat the mediated set as the unit and use the fallback for the whole directory rather than per file |
| The substitution names a retrieval call (`get_observations`, a corpus search) | Run it once — when it answers the question, prefer it; the index is cheaper than the file. When it returns unrelated or stale content, fall back to the shell path |
| Output is plausible but shorter than the file | Do not treat it as the file. Compare against `wc -l` before quoting it in a review, a diff, or a claim about coverage |
| A second agent reports the tool working normally | Hook config is per settings scope (user/project/local); confirm which scope each session loaded before concluding the hook was removed |
| The tool is mediated but writes still land | `PostToolUse` runs after execution, so write tools take effect even when their reported result is rewritten — verify the write on disk, not from the returned text |
| The wrapping hook also intercepts your shell fallback | Read through a different mechanism (an editor/Write-tool round trip, `base64` of a byte range) and escalate the harness configuration to the human — a harness that blocks every read path is a configuration fault, not a puzzle to route around |
| The mediating tool is a fetch/summarize call (`WebFetch`) rather than a file read, and its result is about to be recorded as a verified quote or number | Fetch the raw page yourself (`curl -sL <url>`) and grep for the literal string before recording it — treat the tool's summary as a lead, not proof |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Retry the tool a third time with new offsets | Switch to `grep -n` + `awk` after the first failed retry | The substitution is produced by a hook that does not inspect your arguments; more argument variants return the same text |
| Conclude the file is empty, one line, or missing | Check `wc -l` on the path | The one-line result is the hook's message, not the file's length |
| Let each spawned worker discover the mediation itself | Name the mediated tool and the fallback command in the brief | The cost is per agent otherwise, and each pays it before doing any real work |
| Disable the plugin to get a clean read | Use the unmediated tool for the read you need | The plugin serves the session's other work; a per-read fallback is reversible and scoped |
| Cite a WebFetch summary's quoted sentence or number as a verified fact | Fetch the raw page with `curl -sL <url>` and grep for the literal string before recording it | The summary is produced by a small, fast intermediary model that can paraphrase or fabricate specifics even when the general gist is accurate |

## Sources

- https://code.claude.com/docs/en/hooks — `PostToolUse` `hookSpecificOutput.updatedToolOutput` "replaces the tool's result"; `PreToolUse` `hookSpecificOutput.updatedInput` "replaces a tool's arguments before it runs"; "For redaction or transformation use cases, intercept at `PreToolUse` for outbound tool inputs and `PostToolUse` for inbound tool results"; `PostToolUse` fires after the tool has executed
- https://code.claude.com/docs/en/tools-reference — "WebFetch takes a URL and a prompt describing what to extract. It fetches the page, converts the response to Markdown when the server returns HTML, and runs the prompt against the content using a small, fast model. For most fetches, Claude receives that model's answer, not the raw page"; the docs' own remedy: "use curl via Bash for the unprocessed page" (raw page grep 2026-09-03)

## Field context

Observed 2026-08-05 in a repo with a session-memory plugin installed: `Read` on
four source files returned only line 1 plus a note suggesting `offset`/`limit`;
the suggested retry (`offset=151, limit=120`) returned line 1 again. Two
orchestrated worker sessions independently logged the same interception and each
fell back to `cat -n`/`sed` on its own, having spent three to four tool calls
apiece rediscovering it.

Observed 2026-09-02 (repo wt-v3-docs): WebFetch on tmap-skopenapi.readme.io's
`routeSequential30` page reported the quoted sentence "경유지는 최대 30개까지
설정할 수 있습니다." (waypoints up to a maximum of 30); a direct `curl` + grep
against the raw page confirmed the exact string inside the `viaPoints` field's
description (re-confirmed 2026-09-03). The same check on the `matrix` page
showed WebFetch's negative claim (no limit stated) was also accurate — the
summary is not always wrong, which is why a spot-check, not blanket distrust,
is the right response.
