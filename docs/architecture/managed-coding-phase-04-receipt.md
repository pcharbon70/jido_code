# Managed Coding Phase 4 Candidate Workflow Receipt

## Status

This receipt records the Phase 4 implementation candidate verified locally and
accepted after pull request merge on 2026-08-25. The implementation pull
request passed clean-checkout CI and merged as
`24c6b7928d11452a08edf24963df9f0b8788afd2`; MCG4 is accepted at that merged
candidate and Phase 5 is authorized from this pinned baseline.

The candidate supplies ledger-first admission, a graph-backed lifecycle,
immutable content-addressed candidate closure, independent fresh-checkout
verification, separately authorized disposition, a human-merge publication
handoff, and an authenticated graph-derived operator surface.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Authorized Phase 4 baseline / accepted MCG3 | `1c98c3a592303a36cc7c807f4763b587ad5908dc` |
| Section 4.1 | `d38a5a300ff5d662449bde9ee81719f319cbea37` - add managed coding admission service |
| Section 4.2 | `7d53e6ce5bc04682c5294fae9e4b99413271f503` - add durable managed coding lifecycle |
| Section 4.3 | `3819a2e7c531d94e6682fadba2642cd0b14a03b2` - close immutable managed coding candidates |
| Section 4.4 | `93f6ae6c6f1788430764f61a27630bbe19482751` - separate candidate verification authority |
| Section 4.5 | `214d3c073161c3611de1266c36de1dc4b6ec8931` - expose managed coding attempt controls |
| Section 4.6 | This receipt, workflow coordinator, integration matrix, and final local gates; exact commit recorded by Git history |
| Merged candidate | `24c6b7928d11452a08edf24963df9f0b8788afd2` - merged 2026-08-25 |

## Contract Pins

| Contract | Candidate SHA-256 |
| --- | --- |
| Admission service | `ba7cae5895d276137ad8e23b84c03e4c9e75d2d57d140e2686b98de40722a10d` |
| Durable lifecycle coordinator | `0e1f0bd890f695b29f2d0318561cfd658d1b6f91176ce6d8cca43092f72e247e` |
| Candidate manifest | `df6c87a07f1e1f52e20a9fd1d51d5ecfb0bd7839bca022d52177d4560104817e` |
| Candidate workflow | `2ec55212a9b0d708d6fce46c6000f98f0f4d6a1ba53d4e463ceee1bbf4201d26` |
| Verification request | `c17e8dd006887aa7b1dc5ae3582e87923f1bb0a7f4f8d8c05a4f1b80f0423281` |
| Disposition | `57477e9d77382130defc29c538ebe71a3d7ae823d5123024a44806688b534d8b` |
| Publication handoff | `ac6fd73a8722b11dca78c045654822c7da88ade5b0ee89d2b7ba095692a51909` |
| Product projection | `99128d0db0965e2124f8b9323e05fc978f829c77e1a5b76e0b015ff8d6b1a036` |
| Authenticated LiveView | `21a3adf757c8b3d5fe019b8ce4cc5399f52af2f2f29f419f911d83a86f6c9c4a` |
| Phase 4 integration fixture | `979279c02b7b951f41a27c26bd1f765789823595c48b32bc2be855216a36a0eb` |

## Admission And Lifecycle Evidence

- The Factory service resolves tenant, repository, task, actor, policy,
  profile, snapshot, budget, credential reference, and capability revisions.
  It commits attempt identity, lease fence, exact inputs, admitted state, and
  admission evidence before asking the runtime to start.
- Admission and runtime ports expose no graph handle or workspace. Duplicate
  commits are idempotent; conflict, stale fence, authorization, unsupported
  input, and capacity failures return closed errors without starting a runtime.
  A failed runtime start is reconciled against the committed admission rather
  than inferred from process state.
- The lifecycle permits only admitted, preparing, running, awaiting actor,
  assembling candidate, candidate ready, verifying, dispositioned, cancelled,
  and failed transitions with explicit predecessor sets. Workspace,
  invocation, interaction, tool effect, check, artifact, budget, terminal
  proposal, and candidate relationships share the current attempt and fence.
- Event causes make repeated callbacks idempotent. Sequence preconditions and
  fences reject stale writers. `occurred_at`, `recorded_at`, origin sequence,
  and an explicit late-observation marker preserve causal attribution without
  rewriting history.

## Candidate, Verification, And Publication Evidence

- Candidate closure binds repository and base revision, normalized patch and
  tree digests, exact changed-file modes/digests/sizes, generated artifacts,
  check evidence, model/tool lineage, terminal summary, profile, policy,
  toolchain, and secret-scan evidence. Canonical ordering makes equivalent
  captures stable; every tested material input mutation changes identity.
- Closure rejects paths outside scope, excessive file or diff size,
  unsupported modes, prohibited binary content, forbidden content, incomplete
  secret scans, and untracked material outside the manifest. Empty, partial,
  conflicting, oversized, policy-blocked, and capture-failed results remain
  explicit and never enter verification.
- The create-once candidate store compares canonical material and never reads
  a mutable producer workspace after closure. Verification re-fetches that
  exact candidate and binds its result to candidate digest, verifier profile,
  environment, toolchain, policy, check results, logs, artifacts, resource
  observations, deadline, and evidence digest.
- The verifier has neither acceptance nor publication authority. Accept,
  reject, indeterminate, expired, and superseded disposition requires a
  separately authorized non-verifier actor and a current policy. Producer
  success text is not an input to disposition.
- The publication handoff performs no push, pull-request, approval, or merge
  effect. It requires a distinct publication workflow and retains human merge
  as the initial rule.

## Projection And Isolation Evidence

- The authenticated LiveView loads one reviewed, actor-scoped graph projection
  using a 32-character one-way presentation reference. Attempt, repository,
  tenant, actor, candidate, and evidence IRIs do not enter URLs, DOM IDs, or
  browser-visible projection values.
- The product decoder accepts only bounded task labels, budgets, and exact
  `kind`/`label`/`status` summaries. Raw log, prompt, model output, patch, extra
  keys, credentials, filesystem paths, and detected secrets fail closed.
- Steer, answer, cancel, and retry controls create finite Factory commands with
  the authenticated actor, exact attempt, current fence, and deterministic
  idempotency identity. Cancellation and retry require explicit confirmation.
- Delayed, unavailable, indeterminate, cancelled, superseded, and
  policy-blocked states remain distinct. Refresh, reconnect, and process
  restart rebuild the same view from the provider; LiveView streams and form
  state carry no durable authority.

## Workflow And Failure Evidence

- The Phase 4 integration fixture covers accepted, rejected, indeterminate,
  superseded, empty, policy-blocked, clarification, cancellation, and corrupt
  verifier paths through durable final state. It proves candidate and verifier
  relationships are projected from the lifecycle ledger and that corrupt
  verifier output closes the attempt as failed.
- Focused admission, lifecycle, closure, verification, product, LiveView,
  Phase 3 real AgentServer, Phase 2 real worktree, and existing fresh-checkout
  verifier suites cover process loss, duplicate commands, stale fences, graph
  contention, capture failure, verifier timeout, corrupt receipts, checkout
  mismatch, protected paths, cleanup failure, and UI reconnect.
- The existing real AgentServer fixture executes inspect, edit, registered
  check, and candidate capture in an isolated Git workspace. The existing
  `GitVerificationWorkspace` fixture independently checks out the pinned base,
  applies exact immutable artifacts with `executor_state_used?: false`, runs
  verifier-owned checks, and cleans both disposable workspaces.
- Runtime, verifier, disposition, and projection contracts contain no branch
  push, PR creation, approval, or merge callback. The only Phase 4 publication
  value reports `human_merge_required` with every inherited effect authority
  set to false.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 4 focused workflow and component suites plus MCG1-MCG3 regressions | 109 tests, 0 failures |
| Repository-wide `mix precommit` | 822 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 177 existing warnings skipped by policy, zero unignored errors |
| Clean-checkout CI | Passed on PR #68; verify and Dialyzer succeeded |

## Known Limits And Disabled Posture

- Phase 4 retains one managed agent and one candidate workflow per attempt.
  Crash reconstruction, cancellation races, fleet fairness, security
  hardening, and sustained capacity behavior are Phase 5 scope.
- The verifier contract and local Git fixtures are production-shaped but do
  not certify hosted provider, external sandbox, or network availability.
- The graph projection provider requires the reviewed production graph loader;
  missing, unauthorized, or mismatched scoped data renders unavailable.
- Publication remains a separately authorized human workflow. Autonomous
  branch push, approval, publication, and merge remain disabled.
- MCG4 closed only after PR #68 clean-checkout CI passed and the exact merged
  candidate was pinned; later discovery of a reopening condition overrides
  this accepted status.

## Gate MCG4

Status: **accepted at merged candidate**

MCG4 is accepted at merged candidate
`24c6b7928d11452a08edf24963df9f0b8788afd2` after clean-checkout CI and merge
on 2026-08-25. Phase 5 is authorized only from this exact pinned baseline.

MCG4 reopens regardless of checklist state if admission starts a process or
effect before exact identity and evidence commit; process, workspace, cache, or
UI state becomes durable authority; a stale fence or duplicate cause advances
the lifecycle; causal ordering or attributable timestamps are lost; candidate
material is mutable, incomplete, nondeterministic, or omits material
provenance; unmanifested, forbidden, binary, oversized, secret, or out-of-scope
content can close successfully; producer workspace state or producer claims
can enter independent verification; verifier output is not bound to exact
candidate, profile, environment, toolchain, policy, and evidence revisions; a
producer or verifier can accept, publish, approve, push, or merge; disposition
bypasses current actor, capability, or policy authority; any product projection
or control leaks raw logs, model output, patches, secrets, cross-tenant
identifiers, or stale authority; refresh, reconnect, replay, or process restart
repeats an effect or changes the graph-derived view; MCG1, MCG2, or MCG3
reopens; or the exact architecture, Dialyzer, precommit, and clean-checkout
gates fail.
