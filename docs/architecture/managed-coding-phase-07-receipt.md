# Managed Coding Phase 7 Topology And Release Receipt

## Status

This receipt records the Phase 7 implementation candidate verified locally.
MCG7 and the overall managed coding plan remain **merge-pending** until the
implementation pull request passes clean-checkout CI, merges, and its exact
merge commit and merge date are pinned here.

The candidate pins Jido.Pod behavior, implements a graph-projected bounded
specialist evaluation runtime, rejects specialist production adoption after an
insignificant measured gain, rejects AgentOS after a capability and authority
audit, and publishes the final single-agent release contract with independent
verification and human merge authority.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted MCG6 implementation candidate | `3744759726696193ea2fd40f273c06fc2e29c250` |
| Authorized Phase 7 branch baseline / MCG6 closure | `0d583e4b75ac4c11935494933ce81b7cfdef699e` |
| Section 7.1 | `96b0413` - topology and compatibility contract |
| Section 7.2 | `044548b` - bounded Pod reconciliation and delegation |
| Section 7.3 | `73680eb` - specialist roles and comparative evaluation |
| Section 7.4 | `2c8da8c` - AgentOS decision and runtime-port correction |
| Section 7.5 | `f905c49` - final release and operating contract |
| Section 7.6 | This receipt, integration matrix, audit, and final gates; exact commit recorded by Git history |
| Merged candidate | **merge-pending** |

## Contract Pins

| Contract | Candidate SHA-256 |
| --- | --- |
| Topology contract source | `c8f69f69293598b9c41c7bbf30fa7ae22424c55eb7fbc9b931d2787a768b01bb` |
| Topology coordinator source | `04b48328c41ee15405bc12dbba1779dd27fa559aeb1a09148d4f54a6239c51b1` |
| Specialist evaluation source | `60e806aef6592c27f437af377c4a2d47a0f4d0866dfc8984d3b73163d5b3ab4f` |
| AgentOS decision source | `0d010fd063059b91907647ed91f280d5e7657ff837472e0c6ad0e7c95f911cbe` |
| Final release source | `9b35e7fb482b8badbbb22d9402fe3f0453525dffbfbb3c61a863e78276cdd385` |
| Release architecture document | `a6f75cdc0aa46d11addcfa0942d8b799ee3188edb585fbc902c1a546bfc29504` |
| Phase 7 integration fixture source | `97c1d433b5c2012aa8174225abb7aff07f9fe10b0784c2fc36fc55bc48ff94e0` |
| Phase 7 integration test source | `036d9c751c3e0248b303adcccb9c8905a20eec0c1535fafd4584298e94b987cb` |
| Canonical integration fixture | `f86aae722bfbbe3d2b171ab80dff202e8c68812161375e363bed7229aa541914` |
| Specialist evaluation program | `df324ee6f5e018dcbae2c86673836bb2c1ab7f4afabd0ae4df620749cd6cfa89` |
| Specialist comparison result | `86d876cb0ec52904d8283cad49e9d84f4cfc12e07794d3e7630f66423586f0cd` |
| AgentOS decision result | `45a67783f203aabe930a5df288026b657bccf83e4785c04e276c1afa5f845b37` |
| Final managed coding release | `64b43c9786eb9c6d59de817aaa41f0efd287a0a7d08d84357bc604dc6f36e464` |

## Topology And Delegation Evidence

- Jido remains pinned exactly to `2.3.2`; the compatibility suite exercises
  Pod topology construction, reconciliation, eager child startup, lookup,
  membership, process loss, replacement, teardown, signal sequencing, fixed
  manager identity, and storage-disabled InstanceManagers.
- The graph projection pins topology IRI, revision, Phase 6 profile digest,
  state, and reconstruction watermark. Running Pod, specialist, registry,
  monitor, mailbox, and ETS state is disposable and cannot create topology
  history or acceptance evidence.
- Only fixed compiled investigator, coder, and reviewer roles are available.
  Caller/model values never become atoms, modules, process names, managers, or
  new topology nodes.
- Delegation admission checks policy, capability, content-addressed context,
  profile, task, attempt, fence, depth, fan-out, recursion, active roles, shared
  and role budgets before returning a correlated intent. Context, model, tool,
  and memory work routes back through existing Factory gateways.
- Closed content-addressed packets bind topology, delegation, task, attempt,
  fence, role, sequence, payload, and size. Duplicate, late, stale, forged,
  cross-role, corrupt, oversize, recursive, and superseded input fails closed.

## Specialist Evaluation And Decision

- Investigator, coder, and reviewer contracts pin inputs, outputs, tool
  digests, context limits, budgets, termination classes, and unavailable graph,
  policy, topology, verification, acceptance, publication, and merge authority.
- Handoffs require complete source identities, revisions, digests,
  classifications, and content digests. Recipients receive freshly compiled
  manifests; opaque process memory and mutable transcripts are excluded.
- The coder is the sole specialist candidate owner. Host arbitration can select
  a revision proposal but cannot accept or merge it.
- Paired blinded trials bind the exact Phase 6 profile and corpus and compare
  correctness, unsafe behavior, regressions, abstention, recovery, latency,
  tokens, cost, and operator burden against predeclared thresholds.
- The deterministic fixture shows no material correctness gain and adds
  overhead. The decision is **reject**, not accept or restrict. The
  `single_agent` production profile remains the only enabled profile; Pod and
  specialist managers are absent from default supervision.

## AgentOS And Release Evidence

- The evaluated AgentOS revision is
  `548b2a345765ba33e687341c661bbbcbdda73d94`. Lifecycle, registry, scheduling,
  telemetry, operations, and persistence overlap accepted services without a
  measured benefit from adding another runtime dependency.
- AgentOS is absent from dependencies and supervision. No adapter, Ecto
  repository, schema, migration, dual write, credential, backup, restoration,
  or authority path was added.
- Restart, split-state, lag, duplicate, conflict, migration, backup/restore,
  and disable fixtures all retain the accepted graph-only outcome with AgentOS
  irrelevant. Current-release adoption is **rejected** with explicit reopening
  conditions.
- Release contract `7.0.0` pins graph authority, the Phase 6 production profile,
  Factory-owned effects, independent fresh-checkout verification, separated
  publication, human merge, disabled features, SLOs, review cadence, security
  reevaluation, capacity review, and requalification on material upgrade.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 7 topology, coordinator, specialist, AgentOS, release, compatibility, and integration suites | 23 tests, 0 failures |
| Managed-coding component, runtime, verifier, UI, and integration regressions | 155 tests, 0 failures |
| Repository-wide `mix precommit` | 886 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 177 existing warnings skipped by policy, zero unignored errors |
| Clean-checkout CI | Pending implementation pull request |

## Known Limits And Disabled Posture

- The comparative corpus and fault matrix are deterministic repository
  fixtures. They prove contract behavior and reproduce the rejection decision;
  they do not claim hosted-provider multi-agent benefit or production load
  certification.
- Evaluation modules remain compiled so a future signed experiment can reuse
  the closed schemas. They have no product-facade route, default manager,
  feature flag, production profile, persistence, credential, publication, or
  merge authority.
- The Phase 6 draft publisher remains a port with human review and repository
  protections. Broader rollout still requires deployment evidence bound to the
  same exact profile.
- AgentOS and specialist adoption require new compatibility, security,
  capacity, evaluation, operations, and clean-checkout evidence. Prior results
  do not transfer after a material change.

## Gate MCG7

Status: **merge-pending**

MCG7 remains open until clean-checkout CI passes, the implementation pull
request merges, and the exact merged candidate and merge date are pinned in
this receipt. Only then may Phase 7 and the overall managed coding runtime plan
be marked complete.

MCG7 reopens regardless of checklist state if process, Pod, AgentOS, Ecto,
registry, mailbox, cache, workspace, provider, or scheduler state competes with
the graph; topology intent, history, role, delegation, evidence, conflict,
completion, cancellation, or watermark identity is incomplete or mutable;
Jido/Pod behavior or compatibility changes without a new exact pin and hostile
probe; a specialist request, reply, evidence packet, handoff, artifact, error,
or terminal proposal is open, unbounded, uncorrelated, or accepts a stale
fence; caller/model input creates an atom, role, module, manager, process name,
topology node, capability, credential, gateway, or policy; reconciliation,
restart, timeout, cancellation, supersession, quarantine, or reconstruction
trusts process state or loses graph evidence; delegation bypasses policy,
capability, context, profile, task, attempt, fence, concurrency, fan-out, depth,
recursion, message, shared-budget, or role-budget checks; a specialist obtains
direct model, tool, context, memory, workspace, graph, credential,
verification, acceptance, publication, or merge authority; handoff evidence is
incomplete, mutable, corrupt, unattributed, or includes opaque memory; candidate
ownership is ambiguous or arbitration is not deterministic and host-controlled;
the topology comparison is unpaired, unblinded, under-sampled, changes corpus,
profile, thresholds, or analysis after viewing results, omits a declared
quality/safety/reliability/cost metric, or enables a topology with insignificant,
unsafe, unstable, or disproportionate gains; the single-agent fallback fails;
AgentOS or another store becomes authoritative, dual-writes, prevents graph-only
reconstruction, or is adopted without measured benefit and complete operations;
a rejected/deferred feature becomes reachable through public API,
configuration, supervision, migration, dependency, telemetry, UI, or
documentation; profile pins, threats, runbooks, dashboards, data handling,
incident ownership, SLOs, review cadence, upgrade gates, capacity, security, or
future automation prerequisites are incomplete; any runtime, agent, specialist,
Pod, verifier, publisher, or model can approve or merge; human merge authority
or repository protections weaken; any MCG1-MCG6 gate reopens; or the exact
architecture, Dialyzer, precommit, and clean-checkout gates fail.
