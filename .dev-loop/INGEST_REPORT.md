# Knowledge flush — 6 insight(s): 5 ingested, 1 dropped

Queue drained: `~/.dev-loop/queue/{231f63bc,27bf507a,498e892c}.jsonl` — 6 pending rows.

## Verified best-practice

Every URL below was opened in this session and the quoted sentence checked against
the fetched page. No citation was inherited from a draft, another wiki page, or a
prior flush without reopening it.

**1. Assertions for a signed/tokenized link** → `confidence: verified`
Claim: assert the token through the verifier the receiver runs (correct subject
accepts; wrong subject and wrong key reject), and issue the real request with a
token-stripped control — presence of `?t=` is satisfied by a hardcoded placeholder.
- `https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html` —
  confirmed verbatim: "When you create a presigned URL, you must provide your
  security credentials, and then specify the following:" + bucket / object key /
  HTTP method / expiration interval; "Amazon S3 checks the expiration date and time
  of a signed URL at the time of the HTTP request"; the `SignatureDoesNotMatch` FAQ
  "verify that all request parameters—including the HTTP method, headers, and query
  string—match exactly between URL generation and usage".
- `https://docs.python.org/3/library/hmac.html` — confirmed verbatim: "When
  comparing the output of `digest()` to an externally supplied digest during a
  verification routine, it is recommended to use the `compare_digest()` function
  instead of the `==` operator"; `compare_digest` "uses an approach designed to
  prevent timing analysis by avoiding content-based short circuiting behaviour".
- Field reproduction (2026-08-11, Python HMAC approval link): 6 mutations of the
  assembly path; wrong-key and wrong-batch mutants left `?t=` well-formed so every
  format assertion stayed green, while the verifier assertion and 3 live-GET
  assertions reddened; the no-op control survived.

**2. Cross-module consumer census** → `confidence: verified`
Claim: count production references to a task's new public symbols outside the
defining module and outside its own tests, then treat only symbols with *declared*
cross-module intent as defects.
- `https://knip.dev/reference/configuration` — confirmed verbatim: "In files with
  multiple exports, some of them might be used only internally. If these exports
  should not be reported, there is a `ignoreExportsUsedInFile` option available";
  "By default, Knip does not report unused exports in entry files". These two
  options are the tool's own encoding of the internal-helper and entry-point
  populations that a raw zero-reference count cannot separate from real orphans.
- `https://knip.dev/guides/handling-issues` — confirmed verbatim: "So a surprising
  result is usually a real finding or a configuration gap, not a false positive to
  silence", plus the pre-deletion checks (export in an entry file, re-exported from
  an entry file, consumed externally).
- Field measurement (2026-08-11, 6 parallel tasks split by file ownership): 14
  public functions had zero cross-module production references; exactly 1 was a
  real gap (a URL builder whose docstring named its consumer), the other 13 were
  same-module helpers. All 6 tasks had passed review, 402 tests green, no conflicts.

**3. Defect-class re-sweep over your own remediation diff** → `confidence: verified`
Claim: re-run each finding's *class* search over the post-edit file including the
lines the remediation just added; read the remediation as unreviewed code.
- `https://www.eecg.utoronto.ca/~yuan/papers/incorrect_fix_abstract.html` —
  confirmed verbatim: "at least 14.8% to 24.4% of sampled fixes for post-release
  bugs in these large OSes are incorrect" and "27% of the incorrect fixes are made
  by developers who have never touched the source code files associated with the
  fix". Title/authors/venue confirmed on the same page: Yin, Yuan, Zhou, Pasupathy,
  Bairavasundaram, "How Do Fixes Become Bugs?", FSE 2011.
- `https://dl.acm.org/doi/10.1145/2025113.2025121` — cited as the published record
  for that paper. **Not opened** (ACM interstitial); it is a locator for the
  abstract page above, which was opened and quote-checked. Flagged here rather
  than presented as read.
- Field incident (2026-08-11): review round 1 said a checker echoed a raw external
  string into its error message; the same round's remediation added a sibling
  checker with the identical leak, reproduced by an independent audit with a key
  containing a carriage return.

**4. Failing pod on a repo-synced cluster** → `confidence: verified`
Claim: branch on pod phase before reading logs; read `lastState.terminated`
exitCode/reason first; land the fix as a manifest PR, not a live edit.
- `https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/` — confirmed
  verbatim: "Check the current state of the Pod and recent events with the following
  command: `kubectl describe pods ${POD_NAME}`"; "There should be messages from the
  scheduler about why it can not schedule your pod"; "The most common cause of
  `Waiting` pods is a failure to pull the image".
- `https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/` —
  confirmed verbatim: the worked example prints `exitCode: 137` / `reason: OOMKilled`
  under `lastState: terminated:`, introduced by "The output shows that the Container
  was killed because it is out of memory (OOM)".
- `https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/` — confirmed
  verbatim: `-p, --previous` = "If true, print the logs for the previous instance of
  the container in a pod if it exists."
- `https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/` — confirmed
  verbatim: "By default, changes that are made to the live cluster will not trigger
  automated sync"; self-heal = "To enable automatic sync when the live cluster's
  state deviates from the state defined in Git"; and the multi-source caveat
  "Disabling self-heal does not guarantee that live cluster changes in multi-source
  applications will persist."
- `https://man7.org/linux/man-pages/man1/bash.1.html` — confirmed verbatim: "The
  return value of a *simple command* is its exit status, or 128+*n* if the command
  is terminated by signal *n*" — the convention that makes 137 read as 128+9.

**5. Cloud CLI invocation bounds** → `confidence: verified`
Claim: read the leaf subcommand's help; name the scope on every invocation; cap
list output at the call site; disable pager/prompts for unattended callers.
- `https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-help.html` — confirmed
  verbatim: `aws help` "displays help for the general AWS CLI options and the
  available top-level commands"; `aws ec2 help` "displays the available Amazon
  Elastic Compute Cloud (Amazon EC2) specific commands"; operation help "includes
  descriptions of its input parameters, available filters, and what is included as
  output"; and "`describe-instances` has a default behavior that describes ***all***
  instances in the current account and AWS Region".
- `https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html` —
  confirmed verbatim: "By default, the AWS CLI uses a page size determined by the
  individual service and retrieves all available items"; `--max-items` "prints out
  only the number of items at a time that you specify"; mixing `--page-size` and
  `--max-items` "you can get unexpected results with missing or duplicated items";
  "By default, this feature returns all output through your operating system's
  default pager program", disabled per command by `--no-cli-pager`.
- `https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html` —
  confirmed verbatim: "You can override an individual setting by either setting one
  of the supported environment variables, or by using a command line parameter."
- `https://docs.cloud.google.com/sdk/gcloud/reference` — confirmed verbatim:
  `--project` "The Google Cloud project ID to use for this invocation. If omitted,
  then the current project is assumed"; `--quiet` "Disable all interactive prompts
  when running `gcloud` commands. If input is required, defaults will be used, or an
  error will be raised."
- Field incident (2026-06-17, macOS hook shelling out to `aws cloudwatch`): calls
  inherited no region, every invocation failed closed, and the guard the hook
  implemented never evaluated.

**6. Python `.pyc` cache staleness in a mutation harness** → dropped, see Open-PR check.
Its remedy was checked anyway: `https://docs.python.org/3/using/cmdline.html`
confirms `-B` = "If given, Python won't try to write `.pyc` files on the import of
source modules" and `PYTHONDONTWRITEBYTECODE` "is equivalent to specifying the `-B`
option". Both govern **writing** only — so the candidate's directive ("run under
`-B`") is incomplete on its own: an existing `.pyc` is still validated and reused.
Open PR #52 already states exactly this correction, which is why the candidate is
dropped rather than ingested.

## Existing-layer check

Routed via `INDEX.md`, then each target domain's `index.md`, then every page whose
"load when" line overlapped the candidate.

Pages read: testing-quality-signed-link-verification-assertions, testing-quality-harness-reverse-controls, backend-python-language-bytecode-cache-staleness, backend-common-change-impact-cross-module-consumer-census, qa-process-defect-class-resweep-after-review, infrastructure-containers-failing-pod-on-a-repo-synced-cluster, platforms-processes-cloud-cli-invocation-bounds

Read at frontmatter level only (to add reciprocal `related:` ids, bodies not
re-read): `testing-quality-write-path-assertions`,
`infrastructure-containers-resource-limits-and-probes`,
`platforms-processes-parsing-cli-structured-output`. Domain indexes read in full:
`wiki/{testing,qa,backend,infrastructure,platforms}/index.md`.

**Overlaps found and how they were resolved**

- **Candidate 6 vs `backend-python-language-bytecode-cache-staleness` (on `main`)** —
  the merged page already carries the mtime+size invalidation mechanism, the
  equal-size mutation case, `__pycache__` purging and hash-based `.pyc`. The
  candidate's only new material was the `-B` / `exec(compile(...))` remedy, and
  open PR #52 already adds precisely that (and corrects it). No amend written here:
  amending that file would have collided with #52 for content #52 states better.
- **Candidate 1 vs `testing-quality-harness-reverse-controls`** — that page owns
  the *harness-level* control (a no-op mutant must survive). The new page owns the
  *assertion shape* for a signed link and cites the harness page for its
  prove-it-can-fail step. Distinct cases; linked, not merged.
- **Candidate 2 vs `backend-common-change-impact-call-site-enumeration`** — that
  page enumerates callers of a symbol whose contract you are *changing*; the new
  page counts consumers of a symbol you just *added*. The new page states the
  boundary in "When this applies" and links across.
- **Candidate 3 vs `infrastructure-containers-resource-limits-and-probes`** — that
  page is authoring-time sizing of limits and probes; the new page is diagnosis of
  an already-failing pod. Boundary stated in both directions.
- **Candidate 5 vs `qa-process-regression-scope`** — that page scopes re-testing for
  a release; the new page sweeps one defect class across one remediation diff.

**Conflicts flagged:** none. No new directive contradicts an existing page.

**Reciprocal links added** to `write-path-assertions`, `resource-limits-and-probes`,
`parsing-cli-structured-output`. Reciprocal links were deliberately **not** added to
`call-site-enumeration.md`, `regression-scope.md` and `non-interactive-cli-invocation.md`
even though the new pages cite them: open PRs #68/#58/#51/#50 (the first two) and
#66/#57 (the third) already modify those files, and a one-line `related:` edit there
would conflict for no knowledge gain. Every id resolves either way — invariant 4 does
not require reciprocity.

**Invariants re-checked programmatically after the edits** (whole repo, not just the
diff): every `related:` and inline page-id resolves (0 unresolved); each new page is
listed in its domain index; all 5 new pages are ≤120 body lines (72/74/67/76/84).
The resolver was run with a fabricated id as a negative control and reported it
unresolved, so a clean result is not a silently-empty check.

## Open-PR check

Listed with `gh pr list --repo choiyounggi/dev-loop --state open` — 18 open heads:
#74, #73, #72, #69, #68, #66, #64, #62, #61, #58, #57, #56, #55, #52, #51, #50, #49, #47.
Every head's changed-file list was pulled (`gh api .../pulls/N/files`) and filtered to
the five candidate paths plus the amend target.

| Candidate | Overlapping open head | Verdict |
|---|---|---|
| 1 signed-link assertions | none creates this slug; #52 adds the adjacent `testing-quality-source-text-wiring-assertions` (regex-over-source wiring guards — different case, read to confirm) | **new** |
| 2 cross-module consumer census | none creates this slug; #58 adds `corpus-sweep-before-a-rejection-rule` (bounding a new *rejection rule* against a corpus — different case, read to confirm) | **new** |
| 3 failing pod on a synced cluster | no open head touches `wiki/infrastructure/containers/` | **new** |
| 4 cloud CLI invocation bounds | #66/#57/#62 touch other `platforms/processes/` pages; none touches this slug or its subject | **new** |
| 5 defect-class re-sweep | no open head touches `wiki/qa/process/` except #58 (`regression-scope`, a different page) | **new** |
| 6 Python `.pyc` cache in a mutation harness | **#52 modifies the exact target file** and already adds the `-B`/`PYTHONDONTWRITEBYTECODE` row, the `spec_from_file_location` row, the `exec(compile(...))` remedy and two 2026-08-11 reproductions | **drop** (pending duplicate, #52 carries it in better form) |

No sibling duplicate PR was opened for candidate 6, and nothing was pushed to #52 —
it needs no additions from this candidate.

**Repo-state note for the reviewer.** Two local branches from interrupted 2026-08-11
flushes, `knowledge/dch0202-rsquare-20260811-151241` and `…-160220`, were pushed to
the fork but never opened as PRs. They carry earlier drafts of candidates 1–5 under
different slugs (`signed-link-assertions`, `new-symbols-without-a-consumer`,
`defect-class-sweep-over-a-fix`, `workload-startup-failure-triage`,
`cloud-cli-query-scoping`). This PR supersedes both; they can be deleted.

## Routing decision

| # | Insight | Target | New category? |
|---|---|---|---|
| 1 | Signed/tokenized link assertions | `testing/quality/signed-link-verification-assertions.md` | no — `testing/quality` owns assertion-shape decisions |
| 2 | Cross-module consumer census | `backend/common/change-impact/cross-module-consumer-census.md` | no — `change-impact` already owns "who consumes this symbol" |
| 3 | Failing pod on a synced cluster | `infrastructure/containers/failing-pod-on-a-repo-synced-cluster.md` | no — `containers` holds the sizing/probe sibling |
| 4 | Cloud CLI invocation bounds | `platforms/processes/cloud-cli-invocation-bounds.md` | no — `processes` owns invoking other CLIs |
| 5 | Defect-class re-sweep after review | `qa/process/defect-class-resweep-after-review.md` | no — `qa/process` owns release-quality process |
| 6 | Python `.pyc` cache in a harness | — dropped to open PR #52 | n/a |

Candidate 3's harvested `domain: infrastructure` and candidate 4's `platforms` hints
were both honoured. Candidate 2 was harvested as `testing`; it was routed to
`backend/common/change-impact` instead, because the artifact under examination is
application source (a symbol and its consumers), not a test — `INDEX.md` routes to
the domain owning the artifact you will change, and `change-impact` already holds the
sibling page for callers of a changed symbol. Candidate 5 was harvested as `qa` and
stayed there.

Cross-Check: no independent second agent was run — subagent dispatch is disabled for
this session — so this is a single-agent flush. What that leaves: all 14 quoted
sources were re-opened first-hand here (not inherited), the ACM DOI is disclosed
above as a locator that was *not* opened, and the wiki invariants were verified by a
script carrying its own negative control. The five page bodies were drafted by an
interrupted 2026-08-11 flush and were reviewed and re-sourced in this session rather
than trusted; their field-reproduction paragraphs report that session's measurements
and are not independently re-runnable here.
