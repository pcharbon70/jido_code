# Memory Evaluation And Release Program

Phase 7 evaluates governed memory products against one pinned chronological
dataset manifest. It does not train, register, checkpoint, or deploy a model.

## Contract

Evaluation contract revision `1.0.0` requires all of these ablations:

- no memory;
- recent history and all eligible history;
- summaries;
- lexical, dense, and graph retrieval;
- cases and procedures;
- hybrid and oracle retrieval; and
- stale or poisoned memory.

Every ablation reports the exact retrieval, task-outcome, cost, and harm metric
sets implemented by `MemoryEvaluationProgram`. Missing or additional metric
keys fail the run instead of silently changing the release contract.

## Release Gate

Release requires a confidence interval strictly above zero, `p <= 0.05`, and
at least 30 samples for one proposed launch product. Each launch product binds
an accountable owner and a `DisableMemoryProduct` path with a maximum response
time of five minutes.

The following are zero-tolerance metrics: cross-scope leaks, secret leaks,
accounting drift, missing sources, temporal violations, permit bypasses,
stale-claim acceptance, erasure failures, future-patch leakage, and critical
false acceptance. Any non-zero value blocks release regardless of utility.

The graph stores the manifest link, evaluator, complete ablation set,
deterministic evaluation digest, decision, reasons, and disable ownership. It
does not store exported dataset payloads or create model lifecycle authority.
