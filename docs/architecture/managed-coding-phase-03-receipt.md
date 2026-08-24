# Managed Coding Phase 3 Single-Agent Loop Receipt

## Status

This receipt records the locally verified Phase 3 implementation candidate.
MCG3 remains **merge-pending** until the implementation pull request passes
clean-checkout CI and its merge commit is pinned here. Phase 4 is not yet
authorized.

The candidate supplies one disposable `Jido.Agent`, a pure custom strategy,
closed correlated actions and directives, a supervised dispatcher, exact
context and separately ledgered model turns, ToolGateway-only tool effects,
bounded continuation, authenticated steering, and proposal-only candidate
capture.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Authorized Phase 3 baseline | `9c484d1cda35e21fae98168ebad1119dd1b3df8a` |
| Section 3.1 | `563848f` - implement managed coding agent strategy |
| Section 3.2 | `1b8b4b7` - add managed coding directive dispatcher |
| Section 3.3 | `98ea904` - connect managed context and model turns |
| Section 3.4 | `ba29f62` - enforce managed coding loop controls |
| Section 3.5 | This receipt, the real-loop matrix, and final gate evidence; exact commit recorded by Git history |
| Merged candidate | **merge-pending** |

## Contract Pins

| Contract | Candidate value |
| --- | --- |
| Managed agent | `810df7795aebed705a720e28a5782d9c3441ccf46c14c1a67ff23ff0cbd0f830` |
| Custom strategy | `66f69f9cdfe6ff68247c7c35ad9a542c0f4082a8f9272b7280d3c9cb196f38ff` |
| Directive dispatcher | `b19a3cc911354fbc7cbb5beaac11d536a6b582a873c9e63cefb944d9f812e189` |
| Single-agent loop | `4f813540534ca27928dabb7a3cca1a506b26d9bcaee61900fc9b9e175c6062b0` |
| Exact context contract | `878168c5c0e999ff6eca51621b7d7237db37265a97f652e1bcf2c919120f4570` |
| Strict model union | `36bfb0bd9668ceb60adc6fc7246500d2c87733d7a23bffb846a3897a2bb3f8bd` |
| Loop budget contract | `3afdc1d9c4a07b8cc945d950ffb37d399b2b0e041662cc0fc7bd8bc103e0552b` |
| Tool directive seam | `ec283c6a3a37bf7c507d176a67b8af9adbadbd170ad5c570101b0db85f4ccc4b` |
| Real-loop fixture | `039df7d2aada8f3fa408cd23b3977723d67c9cca41d4e983ea1157f5938d20db` |

## Agent, Directive, And Accounting Evidence

- Agent state binds the exact attempt, positive fence, sequence, profile,
  context, tool and model digests, current invocation, budgets, pending model
  decision, candidate digests, cancellation, terminal class, and recovery
  watermark. Pure transitions reject stale, duplicate, gap, cross-attempt,
  wrong-fence, wrong-invocation, unknown, and post-terminal actions.
- The strategy declares nine closed actions and stable signal routes. It runs
  only those host-owned actions and cannot call Knowledge, providers,
  integrations, workspaces, or effects.
- Seven directive types share exact attempt/fence/sequence/effect/invocation
  correlation. The dispatcher bounds global and per-attempt concurrency,
  queues, deadlines, cancellation, crashes, corrupt returns, and delivery to
  the current AgentServer identity.
- Context pins task, snapshot, lease, capability, source, workspace, policy,
  prompt, tool, profile, authority, graph, memory partition, and erasure
  revisions. Disabled memory is bit-equivalent; admitted memory must be
  separately authorized, temporally eligible, source-complete, and explicitly
  non-instructional.
- Every model turn commits a ledger start before the sole ModelGateway dispatch,
  performs explicit credential release through the existing authority seam,
  accepts one strict non-coercing response union, and commits one bounded
  outcome before continuation. Model output cannot select an adapter.
- Tool proposals are re-normalized against the closed catalog and reach effects
  only through ToolGateway. The integration matrix exposed and removed a cold-
  start dependency on pre-existing VM atoms by replacing dynamic tool dispatch
  with explicit closed function routes.
- Loop observations persist limits and enforcement for turns, model calls,
  tokens, tools, bytes, time, cost, workspace changes, checks, and clarification.
  Hard and next-effect exhaustion stop before another effect; observed-only and
  unavailable dimensions remain explicit.

## Loop And Hostile Evidence

- A real AgentServer executes context-model-read, context-model-edit,
  context-model-registered-check, and context-model-candidate turns through the
  supervised dispatcher. The fixture uses deterministic model responses, a
  real isolated Git workspace, real registered adapters, ToolGateway ledger and
  effect accounting, and immutable candidate capture.
- Existing Phase 2 real-worktree fixtures cover inspect, search, read, edit,
  create, delete, registered check, diff, candidate capture, stale fence, and
  replay. Phase 3 focused suites cover clarification and abstention outcomes,
  all four strict model variants, malformed/legacy/provider tool-call output,
  stale context pins, hard and next-effect budgets, authenticated actor
  responses, steering/pause/resume/cancel authorization, and terminal-claim
  rejection.
- Dispatcher and strategy hostile fixtures cover invalid tools and payloads,
  prompt/runtime-state smuggling, duplicate and late signals, cross-attempt and
  wrong-fence delivery, queue pressure, deadline timeout, adapter error, task
  crash, cancellation, and post-terminal replay.
- Candidate completion remains `proposal_only`, starts unverified, and has no
  publication authority. Claims of test success, evidence sufficiency,
  acceptance, approval, publication, or merge are rejected.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 3 focused and Phase 2 regression matrix | 19 tests, 0 failures |
| Real AgentServer inspect-edit-check-candidate loop | Passed repeatedly with deterministic fixtures |
| Architecture checks | Passed locally |
| Dialyzer | Passed; zero unignored candidate warnings |
| `mix precommit` | 791 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | **merge-pending** |

## Known Limits And Disabled Posture

- Phase 3 is intentionally one agent and one bounded effect at a time per
  attempt. Pods, specialist delegation, parallel coding, and topology changes
  remain disabled until later phases.
- Clarification sessions and operator controls define the authenticated contract;
  production transport and UI wiring remain host concerns for later phases.
- Candidate capture is not verification, acceptance, publication, or merge.
  Those authorities remain outside this runtime and require later independent
  gates.
- Runtime recovery records a watermark and rejects stale replay, while complete
  crash reconstruction and deployment rollout are addressed by later phases.

## Gate MCG3

Status: **merge-pending**

MCG3 remains open until clean-checkout CI passes, the implementation pull
request merges, and this receipt pins the full merge-commit SHA and merge date.
Phase 4 is not authorized from an unmerged branch candidate.

MCG3 reopens regardless of checklist state if any strategy action calls
Knowledge, an adapter, workspace, store, or effect directly; any external action
bypasses a closed directive, current attempt/fence/invocation correlation,
invocation-before-effect accounting, or bounded terminal outcome; any model can
select an adapter, provider fallback, sink, executable, credential, or authority;
context can silently reuse a changed source, workspace, policy, lease,
capability, prompt, tool, memory partition, or erasure generation; repository or
memory data becomes instruction or widens authority; any budget permits another
effect after exhaustion; steering or clarification bypasses graph authority,
audience, purpose, expiry, size, attempt, or fence; any terminal model claim
becomes verification, evidence, acceptance, publication, or merge authority;
any candidate capture publishes or mutates protected state; MCG1 or MCG2
reopens; or the exact architecture, Dialyzer, precommit, and clean-checkout gates
fail.
