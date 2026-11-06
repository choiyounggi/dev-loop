---
id: backend-common-ml-inference-device-choice-on-apple-silicon
domain: backend
category: ml
applies_to: [general]
confidence: verified
sources:
  - https://docs.pytorch.org/docs/2.14/notes/mps.html
  - https://github.com/pytorch/pytorch/issues/148219
  - https://github.com/pytorch/pytorch/issues/77799
  - https://sbert.net/docs/sentence_transformer/usage/efficiency.html
  - https://sbert.net/examples/sentence_transformer/applications/computing-embeddings/README.html
  - https://github.com/huggingface/sentence-transformers/pull/4169
  - https://github.com/kkollsga/kglite/pull/208
last_verified: 2026-11-06
related: [debugging-performance-profile-before-optimizing, backend-common-llm-self-hosted-model-load-latency]
---

# Choosing CPU or MPS for Per-Request Transformer Inference on Apple Silicon

## When this applies

A service or script on an Apple Silicon Mac runs a PyTorch transformer model
(a sentence-transformers embedding model, a classifier encoder) one request at a
time — batch size 1, latency matters — and you are choosing the device (`cpu`
or `mps`) and the dtype (fp32 or fp16). Also when a rule of thumb like "MPS is
slower than CPU for small batches" is about to decide the device unmeasured.

## Do this

1. **Pin the device and dtype explicitly.** SentenceTransformer places the
   model "on the most performant available device, e.g. cuda or mps if
   available" when `device` is not given, and Transformers v5 loads the
   checkpoint's stored dtype by default. Pass `device=` and
   `model_kwargs={"dtype": ...}` (`torch_dtype` before Transformers v5) so the
   configuration you measured is the one that runs.
2. **Measure three configurations on the target machine:** CPU fp32, MPS fp32,
   MPS fp16. Use the production call shape (one sentence per call, real text
   lengths). Send warm-up calls first and keep them out of the numbers
   ([debugging-performance-profile-before-optimizing] step 3).
3. **Decide on p95 per call**, not on the mean, over at least a few hundred
   calls per configuration. Call `torch.mps.synchronize()` before stopping the
   clock when you time raw tensor work; `encode()` returning NumPy already waits
   for the GPU.
4. **After switching to fp16, re-run the task metric** (retrieval recall,
   classification F1) on your evaluation set and compare it with the fp32
   score. The sentence-transformers docs promise only "minimal loss of model
   accuracy"; your threshold-based decisions are what can move.
5. **Record the versions next to the result** (chip, macOS, torch,
   sentence-transformers). MPS speed has changed between macOS and PyTorch
   releases, so re-measure after an upgrade.

| Measured result | Choose |
|-----------------|--------|
| MPS p95 clearly below CPU p95 and the task metric holds in fp16 | MPS fp16 |
| MPS faster only in fp32, or fp16 moves the task metric | MPS fp32 |
| CPU p95 at or below MPS p95 (small model, very short inputs) | CPU fp32 |
| Process memory on MPS too large for the host | CPU fp32, even if slower |

## Edge cases

| Case | Then |
|------|------|
| Model of a few tens of millions of parameters with short inputs | Per-op dispatch on MPS (~24 µs per op for 1-element tensors in issue #148219) can exceed the compute; CPU often wins here, so measure it rather than assume MPS |
| Model of hundreds of millions of parameters | The compute per call outweighs dispatch even at batch 1; field measurement below had MPS 2–3× faster than CPU |
| fp16 or bf16 weights end up on CPU (checkpoint dtype loaded by default) | CPU inference in half precision can be much slower than fp32; load with `dtype=torch.float32` for CPU (sentence-transformers PR #4169 added a warning for this) |
| An op has no MPS kernel (`NotImplementedError`) | `PYTORCH_ENABLE_MPS_FALLBACK=1` runs it on CPU; re-measure, since each fallback copies tensors between devices |
| `torch.backends.mps.is_available()` is False | The process runs under Rosetta (x86_64 Python), macOS is below the version the torch build requires, or torch was built without MPS (`is_built()` tells which) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pick CPU because "GPU is slow for small batches" | Measure CPU fp32, MPS fp32 and MPS fp16 p95 at batch 1 | The rule holds for tiny ops and small models; a large encoder at batch 1 can still be 2–3× faster on MPS |
| Ship fp16 because it was faster | Re-run the task metric in fp16 first | Speed was the only thing measured; thresholds tuned in fp32 can shift |
| Leave `device` unset | Pass `device=` explicitly | The library picks MPS when present, so a CPU benchmark may not be what production runs |

## Sources

- https://docs.pytorch.org/docs/2.14/notes/mps.html — MPS backend maps computation onto Metal Performance Shaders; `torch.backends.mps.is_available()` / `is_built()` and the "macOS version … and/or you do not have an MPS-enabled device" cause
- https://github.com/pytorch/pytorch/issues/148219 — "dispatch time of MPS ops trashes their performance for small to medium size inputs"; 1-element `mul` 24.5 µs (24.2 dispatch) on MPS vs 0.9 µs on CPU
- https://github.com/pytorch/pytorch/issues/77799 — BERT inference about 2× slower on MPS than CPU in the report; gap grows with smaller tensors
- https://sbert.net/docs/sentence_transformer/usage/efficiency.html — float16 "can speed up inference on GPUs at a minimal loss of model accuracy"; loading with `model_kwargs={"torch_dtype": "float16"}`
- https://sbert.net/examples/sentence_transformer/applications/computing-embeddings/README.html — the model "will automatically be placed on the most performant available device, e.g. cuda or mps if available"
- https://github.com/huggingface/sentence-transformers/pull/4169 — since Transformers v5 models load in the checkpoint dtype, so a half-precision model can land on CPU where inference "can be significantly slower than float32"; suggests `model_kwargs={"dtype": torch.float32}`
- https://github.com/kkollsga/kglite/pull/208 — a server defaulted sentence-transformers to CPU on Apple Silicon because MPS placement grew process memory by several GB per server (bge-m3: ~30 ms per query on MPS vs ~65 ms on CPU) — the memory row of the decision table
- Field evidence 2026-11-06 (M4 Pro, torch 2.15, one sentence per call, p95): `arctic-embed-l-v2.0-ko` at 46.0 ms CPU fp32, 20.6 ms MPS fp32, 13.5 ms MPS fp16; Qwen3-Embedding-0.6B at 62.6 / 30.7 / 18.7 ms. The fp16 model kept the downstream intent-classification F1 at 0.931 on the project's evaluation set. Single machine and model pair; the page's directive is to re-measure, not to reuse these numbers
