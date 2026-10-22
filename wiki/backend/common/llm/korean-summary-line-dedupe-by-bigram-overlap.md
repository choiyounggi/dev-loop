---
id: backend-common-llm-korean-summary-line-dedupe-by-bigram-overlap
domain: backend
category: llm
applies_to: [general, korean]
confidence: verified
sources:
  - https://aclanthology.org/2020.acl-main.450/
  - https://ar5iv.labs.arxiv.org/html/2004.04228
  - "표준국어대사전 (https://stdict.korean.go.kr): entries 안2, 못4, 없다, 않다, 불-12, 비-30, 무-10, 미-11"
  - "Local computation 2026-10-11 (Node 26.7.0, character-bigram sets with whitespace removed)"
last_verified: 2026-10-11
related: [backend-common-llm-completion-response-validation, platforms-environment-unicode-text-matching]
---

# Deduplicating Korean Summary Lines by Character-Bigram Overlap

## When this applies

Code removes repeated lines from a model-written Korean summary with sections
(장점/단점, pros/cons, 요약/주의사항) by character-bigram overlap (overlap
coefficient, Dice, Jaccard) against a threshold; a 단점 line disappears after the
dedupe; choosing the comparison scope, the negation rule and the short-line rule.

## Do this

1. **Normalize every line to NFC before building bigrams.** In NFD each syllable
   splits into jamo, and the bigrams of the same text share nothing with its NFC
   form (measured: identical text scored 0; after `normalize('NFC')`, 1).
2. **Compare lines within one section, and across sections of the same polarity
   only.** Opposite-polarity sections restate one topic with the opposite claim,
   and the score of such a pair follows the length of the shared topic, not the
   negation: 주차 가능/주차 불가 scores 0.33, 유연근무 가능/유연근무 불가 0.60.
3. **Treat a pair as different when a negation marker occurs in exactly one
   line.** Match markers as words or word endings, and the Sino-Korean prefixes
   only through a word list you keep for the domain:

| Marker | Match as | A bare substring also hits |
|---|---|---|
| 안, 못 (short negation) | A separate word before the verb (`안 됨`, `못 함`), or `못하` | 못자리 |
| -지 않다, -지 못하다 (long negation) | `않` or `못하` after `-지` | — |
| 없다 | `없음`, `없다`, `없어` as a separate word (`야근 없음`); a compound that ends in 없다 counts only when it is on your word list | 어처구니없다 |
| 불-, 비-, 무-, 미- (不, 非, 無, 未) | Listed words: 불가, 불가능, 비공개, 무급, 미지원 | 불꽃, 불가리아, 비용, 무 (radish), 미래 |

4. **Count lines with fewer than 3 bigrams as duplicates only when identical.** The
   overlap coefficient divides by the smaller set, so a short line contained in a
   longer one scores 1.0: 가능 vs 유연근무 가능 = 1.0. A line of exactly 3 bigrams
   is above this floor and also scores 1.0 against a longer line that contains it
   (식대 지원 vs 점심 식대 지원); set its floor with the first edge case.

Overlap coefficient `|A∩B| / min(|A|, |B|)` and Dice `2|A∩B| / (|A| + |B|)` on
bigram sets, whitespace removed (measured):

| Pair | Overlap | Dice |
|---|---|---|
| 유연근무 가능 / 유연근무 불가 | 0.60 | 0.60 |
| 재택근무 가능 / 재택근무 불가능 | 0.80 | 0.73 |
| 연봉 협상 가능 / 연봉 협상 불가 | 0.60 | 0.60 |
| 주말 근무 없음 / 주말 근무 있음 | 0.60 | 0.60 |
| 식대 지원 / 식대 미지원 | 0.67 | 0.57 |
| 주차 가능 / 주차 불가 | 0.33 | 0.33 |
| 유연근무 가능 / 유연근무제 운영 (a paraphrase) | 0.60 | 0.55 |

## Edge cases

| Case | Then |
|------|------|
| 3-bigram lines carry distinct facts | Raise the exact-match floor to 4 bigrams: a 3-bigram line scores 0.67 against a line that differs in one bigram ((n − 1)/n is 0.50, 0.67, 0.80, 0.875 for n = 2, 3, 5, 8) and 1.0 against a longer line that contains it, so a 0.6 threshold merges both, and a 0.7 threshold separates only the first |
| Polarity carried by an antonym (있음/없음, 많음/적음) | 있음/없음 is caught by the `없` marker; an antonym pair with no marker is kept apart only by the step-2 section scope |
| Whitespace kept as a character in the bigrams | The scores move (유연근무 가능/불가: overlap 0.67 instead of 0.60); fix one variant and calibrate the threshold on it |
| English or mixed-language lines | Negation is a separate word there; match `not` and `no` on word boundaries — QAGS's pair "I am writing my paper in Vancouver." / "I am not writing my paper in Vancouver." shares nearly all unigrams and bigrams |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Tune the threshold until the 장점/단점 pair stops merging | Scope the comparisons by section polarity (step 2) and apply the marker rule (step 3) | A polarity pair scores 0.33 with a 2-syllable topic and 0.60 with a 4-syllable topic, so a threshold that is safe for one length fails for the other |
| Match negation with the bare substrings 불, 비, 무, 미, 못, 없 | Match words and word endings, and the prefixes through a word list | The bare substrings hit 불꽃, 불가리아, 비용, 무 (radish), 미래, 못자리 and 어처구니없다 |

## Sources

- https://aclanthology.org/2020.acl-main.450/ — Wang, Cho, Lewis, "Asking and Answering Questions to Evaluate the Factual Consistency of Summaries" (ACL 2020); §2 (full text at https://ar5iv.labs.arxiv.org/html/2004.04228): "Factual inconsistencies caused by minor changes may be drowned out by otherwise high n-gram overlap, making these metrics insensitive to these errors. For example, the sentences "I am writing my paper in Vancouver." and "I am not writing my paper in Vancouver." share nearly all unigrams and bigrams despite having the opposite meaning." (ar5iv's HTML renders the italic n as "nn-gram")
- 표준국어대사전 (https://stdict.korean.go.kr), search results: 안2 「부사」 "‘아니’의 준말."; 못4 「부사」 "동사가 나타내는 동작을 할 수 없다거나 상태가 이루어지지 않았다는 부정의 뜻을 나타내는 말."; 없다 「형용사」 "사람, 동물, 물체 따위가 실제로 존재하지 않는 상태이다."; 않다 「동사」 "어떤 행동을 안 하다."; 불-12 (不) 「접사」 "‘아님, 아니함, 어긋남’의 뜻을 더하는 접두사."; 비-30 (非) 「접사」 "‘아님’의 뜻을 더하는 접두사."; 무-10 (無) 「접사」 "‘그것이 없음’의 뜻을 더하는 접두사."; 미-11 (未) 「접사」 "‘그것이 아직 아닌’ 또는 ‘그것이 아직 되지 않은’의 뜻을 더하는 접두사."; entries with no negating sense: 불꽃, 불가리아, 비용(費用), 무2 (식물), 미래, 못자리, 어처구니없다
- Local computation 2026-10-11 (Node 26.7.0, bigram sets, whitespace removed unless the row says otherwise): every number in the tables above; one changed bigram on equal-size sets (n − 1)/n for n = 1, 2, 3, 5, 8; identical text in NFC vs NFD scored 0, and 1 after `normalize('NFC')` on both (a one-off `node -e` computation)
- Field origin 2026-10-10 (a Korean job-posting summary pipeline; recorded by the originating session, not re-run in this flush): its dedupe unit test fails on 유연근무 가능/불가 with the negation check off and passes with it on; a reviewer's hand count gave 0.8 for 재택근무 가능/불가능
