# Knowledge flush — 4 insight(s)

4 queued candidates → **3 pages** (2 new platforms pages, 1 new qa page in a new
category). Two qa candidates were merged into a single page because they are the same
case seen twice; nothing was dropped.

Cross-Check: primary-source verification of every directive (man pages, official tool
docs) plus local reproduction of the two mechanism claims against this repo's own hook
source. No independent adversarial agent review was run for this flush — the
verification is documentary and reproducible, not a second opinion.

## Verified best-practice

### 1. A non-interactive flag is not a closed stdin → `confidence: verified`
**Claim.** When invoking a prompt-capable CLI unattended, pass the tool's
non-interactive switch *and* redirect stdin from `/dev/null`; a hang with zero output
is evidence about the client until the far side's log shows the request arrived.

| Source | What it establishes |
|---|---|
| [nohup(1)](https://man7.org/linux/man-pages/man1/nohup.1.html) | "If standard input is a terminal, redirect it from an unreadable file" — detaching includes taking terminal stdin away |
| [ssh(1)](https://man.openbsd.org/ssh.1) | `-n` "Redirects stdin from /dev/null (actually, prevents reading from stdin). This must be used when ssh is run in the background" |
| [ssh_config(5)](https://man.openbsd.org/ssh_config.5) | `BatchMode=yes` disables "password prompts and host key confirmation requests", "useful in scripts and other batch jobs where no user is present" |
| [timeout(1)](https://man7.org/linux/man-pages/man1/timeout.1.html) | "Start COMMAND, and kill it if still running after DURATION"; exit 124 on timeout — a distinguishable "blocked" signal |

Two established tools implement *both* halves (close stdin **and** a fail-fast
interaction switch) as separate mechanisms, which is exactly the candidate's directive.
The client/server split step is field-derived (a gateway access log showed zero
requests from the host during two hangs; `</dev/null` fixed it immediately) and is
labelled as such in the page's Field context rather than presented as documented.

### 2. Command-inspecting gates read pre-expansion text → `confidence: verified`
**Claim.** Write values literally in an argument a gate inspects; create files a gate
reads in a *prior* command.

- [Claude Code hooks docs](https://code.claude.com/docs/en/hooks) — `PreToolUse` runs
  "Before a tool call executes. Can block it"; the hook's stdin JSON carries
  `tool_input.command`, the unexecuted command string. Exit 2 blocks and "stderr text
  is fed back to Claude as an error message."
- [POSIX shell 2.6](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
  — word expansion is performed by the shell as it processes the line, so an external
  reader of the command text sees none of it applied.

**Reproduced locally** against this repo's own extraction pattern
(``--body-file[= ]+[^ '"`]+``, `hooks/pre-flush-pr-gate.sh:56`), 2026-07-30:

| Command text | Extracted | Refusal |
|---|---|---|
| `--body-file "$REPO/…"` | *(empty)* | "no `--body-file` found" |
| `--body-file $REPO/…` | literal `$REPO/…` | "body file does not exist yet" |
| `--body-file "/abs/…"` | *(empty)* | "no `--body-file` found" |
| `--body-file /abs/…` | `/abs/…` | passes |
| `--body-file=/abs/…` | `/abs/…` | passes |

This **corrects the candidate**, which attributed the failure to quoting alone. The run
shows two distinct failure modes with two different error messages — quotes defeat
*extraction*, an unexpanded variable defeats *resolution* — and that a quoted
**literal** path fails too. The page states both; the sharper form is what makes the
error message diagnostic.

### 3+4. Editing a document that text gates check → `confidence: field-tested`
**Claim.** Inventory a file's gate anchors before editing; describe an upstream
contract as an observed shape rather than with definition verbs; scope a check outside
the region that quotes it; record scoped conditions, not global counts.

The *hazards* are documented; the *directives* are field-derived, hence `field-tested`
rather than `verified`:

| Source | What it establishes |
|---|---|
| [Vale `existence`](https://docs.vale.sh/checks/existence) | The check "looks for the 'existence' of particular tokens" as a word-bounded non-capturing group — a lexical gate matches patterns, not intent. This is why a purely descriptive sentence trips a "do not redefine" gate |
| [Vale scopes](https://docs.vale.sh/topics/scopes.md) | Scopes restrict where a rule applies; "Any scope prefaced with `~` is negated" and scopes chain — keeping checks off regions such as code examples is first-class |
| [markdownlint MD013](https://github.com/DavidAnson/markdownlint/blob/main/doc/md013.md) | Rules expose `code_blocks`/`tables`/`headings` booleans (default `true`) so quoted code can be excluded from a prose rule |
| [pgrep(1)](https://man7.org/linux/man-pages/man1/pgrep.1.html) | "The running pgrep, pkill, or pidwait process will never report itself as a match" — self-exclusion is designed in because self-matching is the expected failure |

Field evidence retained in the page: a vague-word audit that matched its own quoted
pattern (1 global hit → 3 after quoting the fix, 0 under an `awk`-scoped run; the same
self-reference observed 3× across two documents), and a vocabulary gate
(`(arena|pool)…(재정의|정의한다|규정한다)`) that failed a true descriptive sentence
until it was rewritten as an observation, restoring the suite 60 → 61.

## Existing-layer check

**Read in full:** `INDEX.md`, `AGENTS.md`, `templates/page.md`,
`wiki/platforms/index.md`, `wiki/qa/index.md`,
`wiki/platforms/processes/background-services.md`,
`wiki/platforms/shells/portable-shell-scripts.md`, `log.md`, plus the two in-flight
pages `wiki/qa/document-verification/spec-document-gates.md` (PR #10) and
`wiki/testing/docs-as-spec/document-conformance-checks.md` (PR #9), fetched from the
fork. **Repo-wide greps** for `grep|self-referen|lexical|doc-as-spec`,
`stdin|/dev/null|non-interactive|tty`, and `PreToolUse|pre-commit|hook`.
**Queue dedup:** all 4 candidate hashes absent from `.processed.jsonl`.

**Open-PR dedup was decisive here.** PRs #6–#10 are open and unmerged, and
#7/#8/#9/#10 all sit in the doc-gate theme, so `main` alone understates coverage.
Overlap verdicts:

| Overlap candidate | Verdict |
|---|---|
| `qa-document-verification-spec-document-gates` (**PR #10, open**) | **Complement, not duplicate.** It owns the *gate author's* side (four axes, controls, fail-closed anchors). The new page owns the *document author's* side: what to do when your prose must survive gates that already exist, including gates whose pattern your text quotes. Neither self-reference scoping nor anchor inventory appears in #10; its nearest row ("Examples section satisfies the check") is a different cause |
| `testing-docs-as-spec-document-conformance-checks` (**PR #9, open**) | No overlap. Positive/negative controls and GFM pipe parsing for checks under construction; says nothing about editing an already-gated document |
| `testing-quality-tests-that-cannot-fail` | Adjacent, linked. Owns proving a *test* can fail. The new qa page routes gate-construction questions to it rather than restating them |
| `qa-process-regression-scope` | Adjacent, linked. Supplies the "re-run the full set, compare the baseline" principle the new page applies to gate suites |
| `platforms-processes-background-services` | Closest neighbour to insight 1 and **already covers `nohup … & disown`** for *lifetime*. It does not cover stdin as a blocking input or the client/server split. Kept separate (its "load when" is persistence), linked **both ways** |
| `platforms-shells-portable-shell-scripts` | Closest neighbour to insight 2, owns quoting *for the shell* — and its rule is "quote every expansion". The new page narrows one argument read by an external gate, so an unqualified reader could see a contradiction; the new page's edge-case table states explicitly that it "narrows one argument, it does not license unquoted expansions elsewhere". Linked both ways |
| `platforms-environment-path-resolution` | Linked only (literal-vs-resolved paths in non-interactive contexts) |

**Conflicts flagged:** one *soft* directive tension (quote-everything vs. write-this-one-
argument-literally), resolved inside the new page rather than by editing the old one. No
factual contradiction found.

**Reciprocal `related:` links added** to `background-services.md` and
`portable-shell-scripts.md` (frontmatter only; `last_verified` deliberately not bumped,
since nothing on those pages was re-verified).

### Merge conflict to expect (please read before merging)
This branch and **PR #10** both introduce the `## document-verification` section in
`wiki/qa/index.md` at the same insertion point, each with its own page row. Whichever
merges second will conflict there. **Resolution: keep one heading and both rows.** To
keep the conflict to that single hunk, this branch deliberately does **not** touch
`INDEX.md` — PR #10's qa route line ("automated verification of document deliverables
(spec/RFC gates)") already covers this new page. If #10 is rejected instead, the qa
route line in `wiki/qa/index.md` should gain a document-verification clause in a
follow-up. No `related:` id in this branch points at #10's page, so nothing here breaks
under either outcome; once both are merged the two pages are worth cross-linking.

## Routing decision

| Insight | Target | New category? |
|---|---|---|
| 1 — non-interactive CLI hang | `platforms/processes/non-interactive-cli-invocation.md` (new page) | No — `processes` already owns process/session lifetime |
| 2 — gate reads command text | `platforms/shells/command-text-inspected-before-execution.md` (new page) | No — `shells`, justified below |
| 3 + 4 — self-reference & lexical gates | `qa/document-verification/editing-a-gated-document.md` (new page) | **Yes** — `document-verification`, the same category PR #10 introduces |

**Insight 1 → platforms, not debugging.** Half the insight is diagnostic, but the
artifact the reader changes is the invocation command, and `AGENTS.md` routes by owned
artifact. `debugging-methodology-reproduce-first` is linked for the isolation half.
Merging into `background-services` was rejected: that page's case is *persistence*, and
adding a blocking-stdin case would drift its "load when".

**Insight 2 → `shells`, not a new category and not `tools`.** The mechanism is expansion
timing — *when* the shell rewrites the line relative to other readers of it — which is
shell semantics, so `shells` holds two coherent pages (portability; expansion timing vs.
external inspectors). `tools` is BSD-vs-GNU userland differences, which this is not. A
dedicated category (e.g. `policy-gates`) was considered and rejected as a one-page
category with no second member in sight.

**Insights 3+4 → one page, not two.** Both are the document author's side of the
doc-gate loop: 3 is "the gate matched the pattern I quoted", 4 is "the gate matched the
verb I used / the anchor I moved". `AGENTS.md` requires one case per page, and the shared
case is "writing prose inside a document that lexical gates run over" — the directives
interleave (scope the check, phrase as observation, record a scoped condition, re-run the
suite), so splitting would have produced two pages that each need the other. **New
category justified:** the existing qa categories are `process` (human release process),
`environments`, `bug-reports`, `exploratory` — none covers automated checks over a
written deliverable. PR #10 reached the same conclusion independently, which is
corroboration rather than duplication.

### Invariants checked on this branch
Body lines 83 / 82 / 93 (limit 120) · all four required sections present on each page ·
every `related:` id and inline `[page-id]` resolves (13 checks, 0 misses) · each new page
listed in its domain index with a multi-use-case "load when" · every index relative link
resolves · no banned vague qualifiers · `log.md` entry appended.

## Decision Log

**의도**
- 큐에 쌓인 4건을 3페이지로 인그레스트한다. qa 2건(자기참조 grep · 어휘 게이트/앵커)은
  "게이트가 걸린 문서를 편집하는 쪽"이라는 **한 케이스**라서 1페이지로 합쳤다
  (`AGENTS.md` "one case per page" + 지시문이 서로를 필요로 함).
- 후보의 *why*를 그대로 받지 않고 실측으로 교정했다: `--body-file` 차단 원인은
  "따옴표 때문"이 아니라 **따옴표=추출 실패 / 미확장 변수=경로 부재**의 두 모드이고
  따옴표 친 리터럴 경로도 실패한다(본문 표에 5변형 실측).
- 열린 PR(#6~#10)까지 중복 검사 대상에 포함했다. `main`만 보면 커버리지를 과소평가해
  #10과 같은 페이지를 또 만들 위험이 있었다.
- `INDEX.md`는 **의도적으로 건드리지 않았다** — #10이 이미 qa 라우트 라인을 갱신하므로
  충돌면을 `wiki/qa/index.md` 한 훅으로 줄였다.

**배제한 대안**
- *insight 1을 `background-services`에 병합* → 기각. 그 페이지의 케이스는 *지속성*이고,
  블로킹 stdin을 넣으면 "load when"이 흐려진다(양방향 링크로 대체).
- *insight 2를 `portable-shell-scripts`에 병합* → 기각. 그 페이지 규칙은 "모든 확장을
  따옴표로 감싸라"인데 이 건은 한 인자를 리터럴로 쓰라는 것 — 트리거도 다르고 규칙이
  충돌해 보인다. 새 페이지에 "이 페이지는 인자 하나만 좁히며 다른 곳의 무따옴표 확장을
  허용하지 않는다"를 명시.
- *insight 2용 새 카테고리(`policy-gates`)* → 기각. 두 번째 멤버가 안 보이는 1페이지
  카테고리. 메커니즘이 확장 타이밍이라 `shells`가 맞다.
- *insight 1을 `debugging`으로* → 기각. 바꾸는 산출물이 호출 명령이므로 소유 도메인 우선
  규칙에 따라 platforms(진단 절반은 `debugging-methodology-reproduce-first`로 링크).
- *qa 2건을 #10 머지까지 보류* → 기각. 범위 축소는 소유자 판단이므로, 대신 충돌 위치와
  해소법(헤딩 1개 + 행 2개)을 위에 명시했다.
- *#10 브랜치를 base로 스택 PR* → 기각. 스킬이 `--base main`을 요구하고, 리뷰 diff에
  #10 변경이 섞인다.

**리뷰어가 볼 곳**
1. `wiki/qa/index.md` — #10과 충돌 예정 지점. **헤딩 1개 유지 + 행 2개**로 해소.
2. `wiki/qa/document-verification/editing-a-gated-document.md` — #10의 페이지와
   중복이 아닌지(저자 측 vs 게이트 저자 측 분담)가 이 PR의 핵심 판단.
3. `command-text-inspected-before-execution.md`의 Field context 5변형 표 —
   `hooks/pre-flush-pr-gate.sh:56` 패턴으로 재현 가능.
4. confidence 등급: 1·2는 `verified`(공식 문서+재현), 3+4는 `field-tested`
   (위험은 문서화되어 있으나 지시문은 현장 유래). 1번 페이지의 클라이언트/서버 분리
   단계는 문서 근거가 아니라 현장 유래라서 Field context로 분리해 표기했다.
5. **[추정]** `platforms/shells`에 2페이지(이식성 + 확장 타이밍)가 앞으로도 응집적으로
   남을 것이라는 판단은 추정이다 — 유사 사례가 더 쌓이면 별도 카테고리가 나을 수 있다.
