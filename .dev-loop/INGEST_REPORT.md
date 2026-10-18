# Knowledge flush — 1 insight(s)

If you point `TMPDIR` at a project-local folder, tools that create a socket under `os.tmpdir()` (tsx) can go past macOS's 104-byte socket path limit and fail with `listen EINVAL`. **1 page amended (1 new edge-case row), 0 new pages.** Of 5 claimed rows, 1 was ingested and 4 were released back to `pending`: 2 may duplicate open PRs, and 2 sit in queue files this headless run could not find.

## Verified best-practice

**`7bb9e584c216294a`: deep `TMPDIR` overflows tsx's IPC socket path**
- Claim: tsx creates its IPC pipe at `<TMPDIR>/tsx-<uid>/<pid>.pipe`. A Unix socket address on macOS fits in a 104-byte `sun_path` buffer, so a `TMPDIR` inside a deep worktree makes `listen` fail with `EINVAL` before any test runs. Keep the whole `TMPDIR` value short (under about 80 bytes), or leave it at the system default for commands that start such tools.
- Sources checked:
  - https://github.com/privatenumber/tsx/issues/457: the error path `/tmp/tsx-0/26.pipe` shows the `<tmpdir>/tsx-<uid>/<pid>.pipe` layout.
  - https://github.com/openai/codex/issues/8343: tsx creates a named pipe under `/tmp/tsx-<uid>/*.pipe`.
  - The page already cites https://nodejs.org/api/net.html ("Typical values are 107 bytes on Linux and 103 bytes on macOS"), the macOS SDK `sys/un.h` (`char sun_path[104]`), and a local reproduction from 2026-09-04 in which a 131-byte path failed with `listen EINVAL`.
- Field evidence (from the candidate): in a 2026-10-18 macOS worktree e2e run with `TMPDIR=<worktree>/.claude/tmp/pw-tmp`, the Playwright `webServer` crashed with `listen EINVAL ... .worktrees/t4-motion3d/.claude/tmp/pw-tmp/tsx-501/81159.pipe`. The same command without `TMPDIR` passed 6/6.
- Confidence: **verified**. The buffer limit and the Node behaviour come from official docs and the SDK header. The tsx pipe layout comes from two public issue reports, not from tsx's own docs; I could not find the `get-pipe-path` source through search. The "about 80 bytes" margin is a rule of thumb: 104 bytes minus the tool's own suffix (`/tsx-501/81159.pipe` is 19 bytes) and slack for longer uid/pid values.

## Existing-layer check

Pages read: platforms-filesystems-unix-domain-socket-path-length, platforms-filesystems-paths-case-and-line-endings

- `wiki_search` for the trigger returned `platforms-filesystems-unix-domain-socket-path-length` as the top hit. That page already covers the mechanism (the fixed `sun_path` limit, worktree depth, `listen EINVAL` on macOS) and has an edge row saying `TMPDIR` itself can be long.
- What was missing: the case where **you** move `TMPDIR` into the project on purpose (a "keep scratch files local" policy) and a third-party tool you do not control derives its socket from it. The page's Do table says "keep it under `os.tmpdir()`", which is the very advice that breaks once `TMPDIR` points into the worktree.
- Action: **merged**, no new page. Added one edge-case row, two frontmatter sources and two Sources lines, and set `last_verified` to 2026-10-19. Also extended the page's "load when" line in `wiki/platforms/index.md`. The page body is still well under 120 lines.
- Conflicts: none. The new row narrows the existing "keep it in `os.tmpdir()`" advice and does not contradict it.
- Related links: the page already links to `platforms-filesystems-paths-case-and-line-endings` (its socket edge row was the second search hit), so no new links were needed.

## Open-PR check

Open `knowledge/*` heads (16): #285, #284, #283, #282, #280, #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run cannot git-diff them, so I judged overlap from each PR's title and changed-file list (`gh pr list --json number,title,files`).

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| `7bb9e584c216294a` (TMPDIR and socket path length) | none: no open PR touches `wiki/platforms/filesystems/`, and a title/body search for `unix-domain-socket-path-length` returned `[]` | **new**, ingested |
| `0358d858600ee3e0` (three.js shadows that "can't be seen" under headless/software GL: measure the shadow's reach and the pixel difference before changing settings) | #285 adds `wiki/testing/e2e/webgl-scene-stalls-under-software-gl.md`: same session, same headless SwiftShader/WebGL trigger | **pending duplicate**, claim released |
| `d631595a0e889652` (give a reviewer of a "red only on X" colour rule the exact token hex and allowed selectors, and have it list computed-colour matches) | #265 adds `wiki/qa/process/blind-llm-judgment-of-a-visual-rule.md`: same visual-rule review trigger | **pending duplicate**, claim released |
| `12aa086463fd4e2a`, `97c37473b53e63c2` | not assessed: content unreadable (see below) | claim released |

`12aa086463fd4e2a` and `97c37473b53e63c2` were claimed, but this run cannot list `~/.dev-loop/queue/`: Bash `ls`/`grep` and Glob are blocked outside the allowed working directory. Their `<sessionId>.jsonl` files did not match any session id I could find in `~/.claude/history.jsonl`. I released both untouched so the next manual `/dev-loop:knowledge-flush` can process them.

## Routing decision

- `7bb9e584c216294a` → `platforms/filesystems/unix-domain-socket-path-length.md` (existing page, new edge-case row). The candidate was tagged `testing`, but the cause is an OS socket-address limit that applies to any tool, not just test runners. The platforms page already owns that limit, so `testing` would have split one mechanism across two pages. No new category needed.

## Local-layer candidates

none. The only ingested candidate is general: it names tsx, Playwright and macOS, not one repository's own files.
