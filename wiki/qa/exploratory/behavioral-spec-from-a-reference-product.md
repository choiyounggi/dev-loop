---
id: qa-exploratory-behavioral-spec-from-a-reference-product
domain: qa
category: exploratory
applies_to: [general]
confidence: verified
sources:
  - https://github.com/morluto/rea
  - https://github.com/yibie/awesome-rea
  - https://redreamality.com/blog/ai-reverse-engineering-clean-room-rewrite-licensing/
  - https://curia.europa.eu/juris/liste.jsf?num=C-406/10
  - https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32009L0024
  - https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32001L0029
  - https://www.law.cornell.edu/uscode/text/17/1201
  - https://www.law.go.kr/법령/저작권법
  - https://law.justia.com/cases/federal/appellate-courts/F2/977/1510/
  - https://www.supremecourt.gov/opinions/20pdf/18-956_d18f.pdf
last_verified: 2026-10-15
related: [qa-process-acceptance-criteria, qa-exploratory-exploratory-sessions, infrastructure-agent-orchestration-reference-study-in-a-plan, security-dependencies-agent-skill-supply-chain]
---

# A Behavioral Spec Derived From a Reference Product

## When this applies

A feature you are about to build mirrors a behavior an existing product already
has (another app's search box, an editor's canvas tool, the protocol a device
speaks) and you are deciding what may be studied, what to observe, how to
record it, and what may enter your repository; an agent reverse-engineering
tool (the REA MCP, a HAR capture, a decompiler) returned findings and you are
turning them into requirements; reviewing a plan whose Rule rows say "like
product X does". Who runs the study and where its files live is owned by
`wiki/infrastructure/agent-orchestration/reference-study-in-a-plan.md`.

## Do this

1. **Settle the right to study before the first capture.** The table is an
   engineering checklist, not legal advice; a case that matches no row goes to
   the requester (or legal) before anything is captured.

| Case | Do |
|------|----|
| Software you own or are licensed to run, or a public site used under your own account within its terms | Study it; record the terms version you read in `## Constraints` |
| The licence carries an anti-reverse-engineering clause | In the EU, observing, studying and testing a licensed copy stays permitted and a contrary clause is void (Directive 2009/24 art. 5(3), art. 8; CJEU C-406/10); in Korea a lawful user may analyse program code for interoperability when the needed information is not otherwise available, limited to the unavoidable parts (저작권법 제101조의4); elsewhere keep to black-box observation of the UI and documented behavior — no static analysis of the shipped code and no decompiler — and record the clause as a constraint |
| A site or service whose terms forbid automated access or scraping, and you hold no licence beyond those terms | Observe by hand in an ordinary browser and write down what you saw; a driven browser or a capture tool is not run against it |
| The product carries a technical protection measure (DRM, anti-tamper, a licence check) | Stop at what runs without touching the measure — circumvention is prohibited whatever the purpose (17 U.S.C. §1201, Directive 2001/29 art. 6, 저작권법 제104조의2); behaviors behind it go in the Unknown cell |
| You want to decompile a licensed binary | State the interoperability or research purpose in the plan and record why black-box observation cannot answer the question (the US disassembly cases turned on a legitimate purpose and no other means of access, Sega v. Accolade); in Korea the decompilation stays limited to the unavoidable, interoperability-necessary parts (제101조의4) |
| The reference is your own earlier product, or source you may read under its licence | Follow that licence (copyleft binds the derived code) and cite the source path instead of a capture |
| The terms forbid generating output in order to replicate the product | Use your own inputs, keep one oracle example per rule, and keep no corpus of its outputs |

2. **Write the oracle before the study.** One sentence per behavior in the form
   "input X -> the original shows Y". That sentence is the Concrete example of
   the Rule row it will become, and the PASS/FAIL check the implementer runs
   later; define it before any agent iterates, because a plausible rebuild and a
   correct one look the same without it.

3. **Record behavior and facts, never expression — one row per behavior.**
   `| Observed behavior | Evidence (tool -> evidence id or capture name) | Unknown |`.
   The row carries the behavior in words; the Evidence cell names the tool and
   the capture (REA's `ev_<sha>` evidence id, `search.har`), while the artifact
   itself (screenshot, HAR, decompiler session, pseudocode dump) stays outside
   the tracked tree and is opened only by the study agent and the reviewer.
   Identifier names, function decomposition, table layouts, string tables,
   icons and copy are expression and stay in the artifact; constants a standard
   dictates (file-format magic, protocol opcodes) are facts and go in the row.

4. **Name what the tool could not see.** Every row has an Unknown cell:
   server-side logic behind an endpoint, an obfuscated branch, timing that was
   not measured, or `none` when the tool reported no limitation. An unknown the
   design depends on goes back to a spike or to the requester; it is never
   carried into Phase B as a guess.

5. **Promote rows into requirements.** Each row that shapes the design becomes
   an `R<n>` row whose Concrete example is the oracle sentence from step 2; rows
   that do not shape the design stay in the study as context. A requirement that
   says only "match product X" is replaced by its rows.

6. **Keep the trail with the captures, and the outcome with the plan.** The
   study agent writes the tool-call list, the files it read, the product
   version, the licence-table outcome and a `## Fingerprints` list of the
   distinctive identifiers and string literals it saw next to the captures;
   the licence outcome and product version are copied into `## Constraints`
   so the plan itself answers "where did this rule come from".

## Edge cases

| Case | Then |
|------|------|
| The tool returned decompiled pseudocode | Read it, write the behavior sentence, keep the pseudocode with the captures and cite its evidence id; `analysis.md` and the repository receive the sentence only |
| The study needs the browser to act (type, click, submit) | Use a test account and read-only actions (type, click, wait, scroll); purchases, messages and account changes stay out, and the action list goes in the trail |
| Only the client is visible and the behavior happens server-side | Record the request/response contract (endpoint shape, pagination, latency) as the behavior and mark the logic Unknown |
| Observation disagrees with the product's own documentation | Record both; the observation is the oracle, and the row notes the documentation version |
| The distinctive part is the visual identity (logo, trade dress, product names) | Exclude it from the rows: identity is trademark, not behavior |
| The study will be quoted in public (PR body, blog, issue) | Publish the behavior sentences; strip evidence ids, payloads and screenshots that show the original's UI |
| The same product was studied for an earlier feature | Reuse its rows and re-verify only the rows this feature depends on; record the product version both times |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Paste a decompiled function into the repository "as a starting point" | Write its behavior as a Rule row with an oracle and let the implementer write fresh code from the row | The pasted text is the original's expression; the implementer anchors on it and the result is derivative |
| Write "behaves like product X's search" as the requirement | One `R<n>` row per observed behavior, each with a concrete input -> output example | "Like X" cannot be tested; the rows can |
| Start the capture and check the licence afterwards | Run the step 1 table first and record the outcome in `## Constraints` | A capture made without the right to make it cannot be undone |

## Sources

- https://github.com/morluto/rea — README: results carry "the evidence and limitations behind each conclusion" and the agent receives "code, references and unknowns"; DISCLAIMER names lawful research, education, interoperability, preservation, and software you own or are authorized to examine as the permitted scope
- https://github.com/yibie/awesome-rea — the shared rule across the listed projects: define correctness as a PASS/FAIL check before letting agents iterate, because wrong decompiled code looks plausible; ports ship none of the original's assets
- https://redreamality.com/blog/ai-reverse-engineering-clean-room-rewrite-licensing/ — a spec carries behavior and facts; the original's output is the test oracle, not its code; check the target's EULA for reverse-engineering clauses and keep findings in internal notes; check whether generating the original's output is itself restricted by the terms (Adobe's terms name monitoring inputs and outputs "in order to recreate that system"); enforce isolation in the environment and keep complete logs
- https://curia.europa.eu/juris/liste.jsf?num=C-406/10 — SAS Institute v World Programming: functionality, programming language and data-file formats are not protected expression; a licensee may observe, study and test the program to determine its underlying ideas
- https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32009L0024 — Directive 2009/24/EC art. 5(3) (observe, study, test without authorisation), art. 6 (decompilation for interoperability), art. 8 voiding contrary contract terms
- https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32001L0029 — Directive 2001/29/EC art. 6: protection against the circumvention of effective technological measures
- https://www.law.cornell.edu/uscode/text/17/1201 — 17 U.S.C. §1201(a)(1): "No person shall circumvent a technological measure that effectively controls access to a work"
- https://www.law.go.kr/법령/저작권법 — 제101조의4 (프로그램코드역분석: a lawful user may analyse program code for interoperability, limited to the necessary parts) and 제104조의2 (기술적 보호조치의 무력화 금지)
- https://law.justia.com/cases/federal/appellate-courts/F2/977/1510/ — Sega v. Accolade (9th Cir. 1992): disassembly to reach unprotected functional elements, for a legitimate purpose and where no other means of access exists, is fair use
- https://www.supremecourt.gov/opinions/20pdf/18-956_d18f.pdf — Google v. Oracle (2021): reimplementing a declaring interface in new code held fair use; none of the cited cases involved AI-assisted reimplementation
