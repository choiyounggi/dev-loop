---
id: qa-document-verification-korean-particles-after-a-token-rewrite
domain: qa
category: document-verification
applies_to: [general]
confidence: field-tested
sources:
  - https://www.koreanvalley.com/korean-grammar/korean-subject-particles
  - https://www.koreanvalley.com/korean-grammar/the-object-particles-and
  - https://ko.wiktionary.org/wiki/%EB%A1%9C
  - https://jakup.com/tools/josa
last_verified: 2026-10-29
related: [qa-document-verification-superseding-a-knowledge-record, qa-document-verification-editing-a-gated-document, platforms-shells-non-ascii-text-after-an-unbraced-parameter, platforms-environment-unicode-text-matching]
---

# Korean Particles After a Rewritten Token

## When this applies

A script, sed/awk pass, or find-and-replace rewrites a token inside Korean prose
— a document number (`RFC-0002` → `RFC-0067`), a version, a count, an id, a
product name — and a particle is attached directly to the token
(`RFC-0002가`, `3개를`, `v2로`). Byte-level fidelity checks (hash per unit,
diff against a manifest) pass, because they compare the bytes the rewrite was
told to write, not whether the sentence still reads correctly.

## Do this

1. **List every rewritten occurrence with what follows it.** Grep the new
   tokens plus the next one or two characters, e.g.
   `grep -noE 'RFC-00(6[6-9]|7[0-7]).?.?' file`. Only occurrences followed by a
   Hangul particle need the next step.
2. **Classify the old and the new token by how the token is read aloud.** The
   particle agrees with the final sound of the spoken form, not with the
   written character. For a number read in Sino-Korean, the last digit decides,
   and a number ending in 0 is read with a place unit (십, 백, 천, 만) or 영/공,
   all of which end in a consonant:

   | Class | Digits (reading) | 이/가 | 은/는 | 을/를 | 과/와 | (으)로 |
   |-------|------------------|-------|-------|-------|-------|--------|
   | Vowel ending | 2 이, 4 사, 5 오, 9 구 | 가 | 는 | 를 | 와 | 로 |
   | ㄹ ending | 1 일, 7 칠, 8 팔 | 이 | 은 | 을 | 과 | **로** |
   | Other consonant | 0 영/십/백/천/만, 3 삼, 6 육 | 이 | 은 | 을 | 과 | 으로 |

3. **Fix only the occurrences whose class flipped** between the old and the
   new token. A rewrite `RFC-0002가` → `RFC-0067가` flips vowel → ㄹ, so it
   becomes `RFC-0067이`. For (으)로 the ㄹ class behaves like the vowel class,
   so check that particle against its own column.
4. **Record the check as its own step** in the rewrite's verification list,
   next to the byte-level checks, with the grep from step 1 and the count of
   occurrences it inspected.

## Edge cases

| Case | Then |
|------|------|
| The rewrite must stay byte-for-byte with a source (a manifest pins the bytes) | Record each flipped occurrence as a finding for a later edit instead of changing it in the pinned output |
| The token is read with a native Korean numeral (`3개` 세 개, `2명` 두 명) | Classify by that reading (세 → vowel, 둘 → ㄹ): the counter word, not the digit, usually carries the particle, so check the counter instead |
| The token ends in a Latin letter or is read in English (`v2`, `API`, `SQL`) | Classify by the spoken English name of the last letter or syllable (L 엘 and R 알 end in ㄹ; M 엠, N 엔 end in a consonant; most other letters end in a vowel) |
| The particle is written in the double form already (`RFC-0067은(는)`) | Leave it; the double form already covers both classes |
| A generator inserts tokens into Korean templates (i18n, release notes) | Choose the particle from the inserted value at render time (a josa helper that applies the table above), so the template never hard-codes one particle |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust a per-unit hash or diff check to cover a token rewrite in Korean text | Add the particle scan from step 1 as a separate check | The hash proves the bytes match the plan; the plan itself kept the old particle |
| Re-check every rewritten token by hand | Compare the reading class of the old and new token and inspect only the flipped ones | Most rewrites keep the class; the table turns a full re-read into a short list |
| Classify (으)로 with the same two classes as 이/가 | Use the three-class table | ㄹ-final words take 로, not 으로, so 1/7/8 move between columns |

## Sources

- https://www.koreanvalley.com/korean-grammar/korean-subject-particles — 이 after a final consonant (받침), 가 after a vowel. Read through a web-search summary in a headless run without page fetch.
- https://www.koreanvalley.com/korean-grammar/the-object-particles-and — 을 after a final consonant, 를 after a vowel. Read through a web-search summary.
- https://ko.wiktionary.org/wiki/%EB%A1%9C — 로 attaches after a noun with no final consonant or a ㄹ final consonant; 으로 after any other final consonant. Read through a web-search summary.
- https://jakup.com/tools/josa — a particle-selection tool that classifies a number by its spoken reading (1 = 일 → ㄹ, 3 = 삼 → ㅁ). A tool's convention, not a norm; the search found no National Institute of Korean Language rule specific to Arabic numerals.
- Field case 2026-10-29 (an RFC-consolidation run that re-pointed references to superseded RFCs): a worker recorded `RFC-0067가` after rewriting `RFC-0002가`. In the consolidated RFC, `grep -noE 'RFC-00(6[6-9]|7[0-7]).?.?'` found 49 re-points; two had attached particles (`RFC-0066이`, `RFC-0068이`) and kept their class, plus `RFC-0071의` (의 does not alternate). The byte-level checks of that run did not report the `RFC-0067가` case.
