# Analysis — non-execution proof fixture (baseline-tests-ran)

The Baseline command below always fails if executed. `check baseline-tests-ran`
must still return `ok` — it validates target presence + parseability only;
execution belongs solely to the emitted ledger's own CHECK line (design §3 D4).

## Ground truth
- Baseline: false -> rc=1, HEAD abc1234, git status dirty
