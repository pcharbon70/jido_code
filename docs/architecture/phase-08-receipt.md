# Phase 8 Governed Execution Receipt

## Status

This receipt records the Phase 8 candidate verified locally on 2026-08-03 and
accepted after pull request merge on 2026-08-03.
Bounded execution context, disposable Jido workers, fenced attempts, sandbox
and tool effects, content-addressed patches, immutable run closure, bounded
projections, and graph-driven recovery are implemented through the graph-only
authority boundary.

G7 is accepted at merged candidate `6a0b3d192e5b87862d2735ccfcfc7f4dcff28631`
after the pull request passed clean-checkout CI on 2026-08-03. No local
evidence found an effect admitted without the current lease/fence, runtime or
sandbox state required for recovery, provider output promoted to accepted
evidence, or execution completion able to satisfy its own goal.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G6 | `f7b3d57748c7c830add4a815257ed3a79ce54e29` |
| Section 8.1 | `68b66a480e89904a95506825ea81d93dc7225483` - define governed execution runtime boundaries |
| Section 8.2 | `6368b3b7f64cacaac697785e2682adb0815a4fa3` - implement fenced execution attempts |
| Section 8.3 | `92a5dabaf7b33f87c9e306860d6187935b650234` - govern execution effects and artifacts |
| Section 8.4 | `b8f02d282ebb69fb9b1bbbf13b72efa91fb14a24` - recover execution from graph provenance |
| Section 8.5 | This receipt and its integration/security tests; exact commit recorded by Git history |
| Merged candidate | `6a0b3d192e5b87862d2735ccfcfc7f4dcff28631` |

## Contract Pins

| Contract | Accepted candidate value |
| --- | --- |
| Runtime identity | `jido:2.3.2/runtime-contract:1.0.0` |
| Jido storage | ephemeral ETS; no product persistence |
| Tool fixture | `phase-08-integration-tool/1.0.0` through the effect-only tool port |
| Sandbox fixture | `JidoCode.Integrations.MemorySandbox` reference adapter at Section 8.3 commit |
| Command registry version | `1.6.0` |
| Registered intent commands | 38 |
| Query catalog version | `1.6.0` |
| Reviewed queries | 68 |
| Query catalog SHA-256 | `8c068c271d745ee5ece91bbc05dcb9b6205898f46f7f5a0bbc69199e50839a3c` |
| Factory ontology / operational shapes | `1.0.0` / `1.0.0` |
| Ontology package SHA-256 | `5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1f8b73535c5903` |
| TripleStore pin | `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| Exact source tree | `abab0e5418ae59d6c7640d93e053833a982978e0` |
| Source snapshot IRI | `https://jido.run/id/repository-snapshot/47c4434f3f3a830fae73502eb2a1fe43` |
| Patch content SHA-256 | `sha256:85c1e25255455dad35ecfeb199f7b6d4da3e688cbb150e3c7a9ce60444313d2a` |

## Accepted Contract

- Execution request identity contains attempt, task, goal, plan, repository,
  lease/fence, actor, agent, capability, exact snapshot, context digest,
  runtime version, and bounded constraints. It contains no graph handle,
  process identifier, provider session, local path, or secret value.
- Context is assembled from reviewed queries and exact graph revisions under
  item, byte, token, visibility, freshness, contradiction, and omission
  policy. Its normalized digest is committed with the attempt start.
- Attempt, lease, and task transitions commit atomically. Every runtime,
  sandbox, tool, outcome, artifact, cancellation, and closure operation
  revalidates the current, unexpired lease and monotonic fence.
- Runtime workers, Jido agents, scheduler memory, provider refs, sandboxes,
  worktrees, and recovery process state are disposable. Duplicate local
  workers are rejected and losing all disposable state changes no domain fact.
- Tool invocation is committed before an effect. Tool results cannot issue
  semantic commands, and outcome/artifact recording independently rechecks
  graph authority after the effect.
- Patches bind exact base snapshot, normalized content digest, media type,
  byte count, generator, and affected scope. Bounded public/internal text may
  be embedded; other content requires an immutable external URI plus digest.
- `FinalizeExecutionRun` atomically closes the run graph as complete or
  incomplete only after terminal transition and complete provenance checks.
  Closed run graphs reject later appends.
- Runtime completion is operational provenance only. Verification, evidence,
  goal decision, and knowledge adoption remain distinct Phase 9 states.
- Recovery rediscovers active attempts from reviewed graph queries, rebuilds
  bounded projections and requests, checks runtime/sandbox status, applies a
  conservative semantic decision, and removes only unreferenced opaque
  provider state.
- Runtime events, outputs, tool results, sandbox events, artifact text,
  diagnostics, interaction content, and persisted provenance reject recognized
  secret material before it can cross or remain in a durable boundary.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Attempt/context/lease fixture | `ba738cfb06d21e6f24b213e548a4e8669b617600977c67e32b3ac85eb6b4bf79` |
| Complete runtime/tool/sandbox/patch fixture | `537ce066600bb55a60a2a13fcf6d3fce08fa6e65a65d81b714634cde8cf1103c` |
| Governed execution and race scenarios | `16c481e65ce7e28f10b2123acacb3f0572eb7466c83e5b6bfa3a3738441f4c04` |
| Recovery, restore, hostile-input, and redaction scenarios | `5892a92efbaa1d1b7444777b2f5c4ab2734c512664e6ee044fb5d147d20d0929` |

The fixtures start the real StoreServer, Writer, QueryRunner, Maintenance, and
embedded TripleStore; load the pinned ontology; bootstrap graph authority;
construct the Phase 6 exact Git snapshot and Phase 7 fenced lease; and commit
all execution facts through semantic commands. Fixed clocks, deterministic
identities, exact graph revisions, and isolated temporary stores make race,
restore, and recovery outcomes comparable.

## Executable Evidence

The Phase 8 integration and retained focused suites prove:

- one leased task proceeds through attempt start, running state, disposable
  sandbox lifecycle, governed tool invocation/outcome, patch recording,
  terminal transition, immutable run closure, and bounded projection;
- attempt, invocation, and artifact graph resources retain task/lease/fence,
  actor/agent/capability, snapshot, input, generator, and revision attribution;
- a completed run remains `not_evaluated`, `not_recorded`, and `not_decided`,
  and its patch is not an `EvidenceBundle`;
- duplicate starts and events are idempotent, while divergent replay, stale
  fences, expired leases, and post-cancellation effects fail closed;
- cancellation stops retry, and any permitted retry receives a distinct
  attempt identity with explicit `retryOf` lineage;
- runtime crash/lost-response scenarios, attempt-worker and sandbox loss,
  scheduler recreation, store-stack reopen, retained abrupt backend/BEAM
  crash tests, and graph-driven recovery do not require process state;
- orphan cleanup retains the active graph-derived provider ref and destroys an
  unreferenced opaque ref without changing graph meaning;
- backup/restore returns a completed store to the running attempt lineage,
  preserves the restored graph revision, reopens TripleStore, and produces the
  same conservative recovery decision; and
- path escape, hook/config writes, unauthorized network and secret injection,
  resource/output limits, tool timeout, stale callbacks, secret-bearing runtime
  values, tool output, sandbox details, artifact content, and run provenance
  are rejected without exposing fixture secrets in errors, logs, telemetry,
  projections, or canonical graph exports.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 8 final integration files | 5 tests, 0 failures |
| Phase 8 focused and integration files | 33 tests, 0 failures |
| `mix precommit` | 239 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| `mix jido_code.ontology verify` | Package and canonical ontology digests verified |
| `mix hex.audit` | No retired packages found |

No frontend or asset behavior changed in Phase 8, so browser and production
asset gates remain inherited from the merged Phase 7 baseline.

## Operational Limits

- Context packages admit at most 20 source graphs and 200 items, with a hard
  262,144-byte and 65,536-token budget; one instruction is at most 16,384
  bytes and one source item at most 32,768 bytes.
- Execution requests admit 32,768 bytes of constraints. Runtime usage is at
  most 4,096 bytes; diagnostics are at most 1,024 bytes; and runtime outputs
  cite at most 100 artifacts.
- Sandbox policy permits at most 100 paths, 50 commands, 100 environment
  names, and 50 secret references. CPU/time are bounded to 3,600,000 ms,
  memory to 16 GiB, disk to 100 GiB, output to 10 MiB, and network to deny or
  explicit allowlisting. The integration fixture uses 1 second, 1 MiB
  memory/disk, 2 KiB output, and denied network.
- Tool requests permit 100 allowed effects and input refs/digests, 32,768
  bytes of arguments, and at most 1 MiB output. Persisted tool stdout plus
  stderr is at most 65,536 bytes and persisted usage has four numeric fields.
- Embedded textual artifacts are at most 32 KiB, with at most 100 affected
  paths/symbols and 50 findings. External artifacts are capped at 1 GiB and
  are verified by size and digest on every use.
- Attempt projections admit at most 200 rows per lens and expose at most 100
  tool invocations and 100 artifacts. Recovery scans at most 100 control
  graphs and runtime versions and 1,000 provider refs every 30 seconds.
- Reviewed queries retain the five-second, 200-row, 500-triple, 256,000-byte,
  20-graph, and 100-parameter defaults.

## Gate G7

G7 is accepted at merged candidate `6a0b3d192e5b87862d2735ccfcfc7f4dcff28631`,
pinned in this receipt and the Phase 8 plan. Any
evidence that disposable runtime state is required for recovery, a stale or
expired fence can cause or record an effect, provider output can bypass
verification, or completion can self-satisfy a goal reopens the gate.
