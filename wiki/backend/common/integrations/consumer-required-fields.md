---
id: backend-common-integrations-consumer-required-fields
domain: backend
category: integrations
applies_to: [general]
confidence: verified
sources:
  - https://docs.pact.io/
  - https://json-schema.org/understanding-json-schema/reference/object
last_verified: 2026-08-10
related:
  [
    backend-common-change-impact-call-site-enumeration,
    backend-common-integrations-externally-owned-defaults,
    backend-common-llm-completion-response-validation,
    testing-quality-tests-that-cannot-fail,
    testing-quality-minimum-case-set,
  ]
---

# Building a Payload for a Consumer Whose Required Fields You Inferred

## When this applies

You are writing an adapter that maps one module's records (a selection query, a
repository row, a scraped item) into the shape a second module consumes — a
scoring engine, a plugin, an external API client — and you took that shape from
the consumer's docstring, README example, or a sample payload. Also when such an
adapter runs end to end with no error and the downstream numbers look low, and
when deciding which mapped fields need an assertion of their own.

Enumerating call sites when *you* own the callee →
[backend-common-change-impact-call-site-enumeration].

## Do this

1. **Call the real consumer once with a mapped record before writing the rest of
   the adapter.** An example payload is an instance, not a specification: in JSON
   Schema terms "the properties defined by the `properties` keyword are not
   required" unless a `required` list says so, so a sample cannot tell you which
   keys the consumer depends on. Pact makes the same distinction — "unlike a
   schema or specification (eg. OAS), which is a static artefact", a contract is
   "enforced by executing a collection of test cases", and a test double is
   trusted only when its calls "return the same results as a call to the real
   application would".

2. **Split the fields the consumer reads into loud and silent by how it reads
   them**, and drive the split from the consumer's source, not its prose:

| How the consumer reads the field | Class | Missing-field symptom |
|---|---|---|
| Presence check or direct subscript (`if k not in d`, `d[k]`, required-field validation) | Loud | Raises on the first record; the run stops |
| Read with a default (`d.get(k, …)`, `??`, `COALESCE`, optional destructuring) | Silent | No error; the computed value is wrong for every record |
| Used only for logging or display | Cosmetic | No error; output text is thinner |

3. **Let the loud fields be found by one end-to-end run, and write an explicit
   assertion for every silent field.** The loud ones announce themselves; the
   silent ones cannot fail any test that only checks "the pipeline completed"
   ([testing-quality-tests-that-cannot-fail]).

4. **Make each silent-field assertion compare two runs of the real consumer —
   one with the field populated, one with it dropped — and require the outputs
   to differ.** Asserting only "the key is present in the mapped dict" passes on
   a key the consumer never reads and on a value that never reaches the formula.

5. **Record the discovered required-field list next to the mapping code**, with
   the consumer version or commit you probed. The list is the adapter's real
   contract, and step 1 is re-run against it when the consumer is upgraded
   ([backend-common-integrations-externally-owned-defaults]).

## Edge cases

| Case | Then |
|------|------|
| The consumer is expensive or has side effects | Probe it once in a test with a single record and cache the field list — the probe is required even then, and the cache is what keeps it cheap |
| The consumer accepts the record but ignores unknown keys | The unknown key is not evidence of anything — keep the step-4 two-run comparison as the only proof a field is consumed |
| The consumer validates with a machine-readable schema (pydantic model, JSON Schema, protobuf) | Read `required`/non-default fields from the schema instead of probing, and still run step 4 for the defaulted ones |
| A silent field's absence changes the output by less than the assertion's tolerance | Choose the probe record that maximizes the field's contribution (longest text, largest count) so the two runs separate |
| The consumer defaults a missing field to a neutral value that looks plausible | Treat it as silent, not absent — a plausible default is what lets the defect reach production |
| Several silent fields feed one output number | Drop them one at a time; dropping all of them at once cannot attribute the difference |
| The consumer is non-deterministic (LLM scorer, sampling, clock-dependent) | Pin the seed/temperature or stub the non-deterministic part before comparing — otherwise the two runs differ for every field, including ones the consumer never reads, and step 4 passes vacuously |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Map fields from the consumer's docstring schema and move on | Call the consumer with one mapped record first, then map the rest | The docstring lists the shape, not which keys are load-bearing; the run tells you |
| Treat "the pipeline finished with no exception" as evidence the mapping is complete | Assert each silent field changes the output when dropped | The loud fields are the only ones an exception-free run proves |
| Assert `"desc" in payload` for each field the consumer reads | Run the consumer twice, with and without the field, and assert the outputs differ | Key presence is satisfied by a key the consumer ignores or reads from a different name |
| Add a default in the adapter for a field you are unsure the consumer needs | Probe first, then map the field or leave it out deliberately | A speculative default converts a loud failure into a silent one — the class that survives to production |

## Sources

- https://docs.pact.io/ — "The contract is generated during the execution of the automated consumer tests"; contract tests "check that all the calls to your test doubles return the same results as a call to the real application would"; and "unlike a schema or specification (eg. OAS), which is a static artefact that describes all possible states of a resource, a Pact contract is enforced by executing a collection of test cases, each of which describes a single concrete request/response pair" — the basis for step 1 preferring an execution over the documented shape
- https://json-schema.org/understanding-json-schema/reference/object — "By default, the properties defined by the `properties` keyword are not required"; an example payload therefore carries no required/optional distinction
- Reproduction 2026-08-10 (Python 3): a consumer that reads `assignee_id` with `if "assignee_id" not in item: raise ValueError` and computes `1.0 + 0.5 * len(item.get("desc", ""))`. Dropping `assignee_id` raised on the first record; dropping `desc` raised nothing and moved the returned score from 21.0 (`desc` of length 40) to 1.0 — same adapter output, one failure visible in the first run and one visible only to an assertion
- Field measurement 2026-08-10 (manday estimation engine, `manday-sp/engine.py`): the two read sites are `check_assignee_ids(items)` at line 511, whose contract is "키 존재 + 값 형식" (key presence, not just value shape), and `d = it.get("desc") or ""` at line 399 — loud and silent respectively. The split is a property of the read site, not of the field, so record the file:line (a sibling copy of the same scorer reads `it["desc"]` by subscript, which makes the same field loud). A mapping built from the engine's docstring schema produced `ValueError` on 100% of records for the missing `assignee_id` key, while the missing `desc` key produced no error and scored 0.31 against 1.63 for the same item — a 5.3x under-estimate that the end-to-end run reported as success
