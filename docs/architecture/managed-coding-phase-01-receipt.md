# Managed Coding Phase 1 Runtime Contract Receipt

## Status

This receipt records the Phase 1 implementation candidate verified locally and
accepted after pull request merge on 2026-08-24. The implementation pull
request passed clean-checkout CI and merged as
`92d32f55a5afb5c59099a08fe4da762653dafdc3`; MCG1 is accepted at that merged
candidate and Phase 2 is authorized from this pinned baseline.

The candidate establishes the managed coding ownership contract, immutable
profile and budget contracts, additive ontology and semantic-command protocol,
exact attempt pins, Jido 2.3.2 compatibility boundary, hostile-runtime
fixtures, and graph-only restart classification. Managed coding effects remain
disabled; this phase does not call a model, mutate a workspace, publish, or
merge.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline | `1273c9785abb1c365e8e15a6a583806646b32ae2` |
| Section 1.1 | `8b24b891117e3a5c5ca813e0b2c82ec6a8ce074b` - define managed coding runtime boundary |
| Section 1.2 | `47a9fc69e3a45b1776aad62a0bc6b56b2180f556` - define profiles, budgets, and closed vocabularies |
| Section 1.3 | `c13193d2d7e27e9a6e741c8b2abc05ca281c7935` - add graph protocol and ontology 1.3.0 |
| Section 1.4 | `eae82ae43b0bf778dda19a62fcb7a2e35e0ff025` - pin Jido and threat conformance |
| Section 1.5 | This receipt, integration fixture, and final gate fixes; exact commit recorded by Git history |
| Merged candidate | `92d32f55a5afb5c59099a08fe4da762653dafdc3` - merged 2026-08-24 |

## Contract Pins

| Contract | Candidate value |
| --- | --- |
| Managed coding Factory API | admission, start, steering, cancellation, status, candidate handoff; runtime internals excluded |
| Runtime identity | execution-attempt IRI plus positive fencing token |
| Managed coding profile | immutable exact revision with 15 budget dimensions and explicit bindings |
| Jido | exactly `2.3.2`; later patches incompatible by default |
| Jido storage | ephemeral `Jido.Storage.ETS` only; hibernate/thaw and alternate persistence prohibited |
| Runtime topology | one disposable `Jido.Agent`; specialist pods, AgentOS persistence, nested JidoHarness, and autonomous merge disabled |
| Ontology / shapes | `1.3.0` / `1.3.0`; additive from `1.2.0` |
| Ontology package SHA-256 | `bf037bef8293f1aedf79f675db792286a330cff2a664e2d2d7766536601309cf` |
| Canonical ontology SHA-256 | `2b2162ec5aa9cd145786ec99d2c3f9b7f3cd1f839541760c90c33d7acfb582d3`; 1,940 quads |
| Semantic command registry | `2.8.0`; 97 registered commands |
| Reviewed query catalog | `2.8.0`; 133 queries; SHA-256 `8fc791874d097e452c1a94ea3404083cd2a49b2ab3a79eed6f8b3e60da2d48a8` |

## Ownership And Compatibility Evidence

- Durable work, policy, profiles, leases, attempts, observations, candidates,
  evidence, decisions, and recovery inputs remain graph-owned. Factory values
  are bounded command/projection data; agent, strategy, directive, process,
  registry, ETS, provider-session, sandbox, and workspace state is disposable.
- The stable Factory facade exposes semantic operations and outcomes without
  pids, pod nodes, graph handles, provider sessions, reusable credentials, or
  sandbox paths. Nested runtime-state and adapter-selection smuggling is denied.
- Managed profiles pin Jido, strategy, prompts, model access, context, memory,
  tools, adapters, sandbox, verifier, candidate schema, budgets, rollout, task
  classes, and actor/tenant/repository/capability ceilings. Selection cannot
  widen any binding.
- Ontology 1.3.0 adds managed profile, strategy, runtime observation, budget,
  clarification, completion, and handoff resources without opening a new graph
  family. Older graph ontology pins may consume only explicitly additive newer
  shapes; reverse compatibility is rejected.
- Attempts bind the exact managed profile, strategy digest, fence, and
  reconstruction watermark. Runtime observations use the existing immutable
  predecessor sequence and do not serialize raw transcripts or strategy state.
- The project-owned Jido probe exercises Agent, Direct strategy, AgentServer,
  directives, signal routing, InstanceManager, partitioning, and supervision.
  Directive output cannot mutate agent state; duplicate, stale, and gapped
  sequences are classified before semantic acceptance.
- Architecture enforcement rejects `Jido.Persist`, File/Redis storage,
  hibernate/thaw, and AgentOS persistence from Runtime. Loss of ETS state never
  satisfies semantic recovery.

## Threat And Restart Evidence

The closed hostile fixture denies repository prompt injection, tool-argument
smuggling, capability drift, stale fences, context substitution, secret
exposure, exhausted budgets, and self-verification. The isolated integration
fixture starts and destroys a real Jido worker at each non-effecting managed
phase and derives the same recovery classification twice from exact graph pins.
Effecting phases require reconciliation; incompatible profile or strategy pins
are superseded rather than reinterpreted.

| Evidence | SHA-256 |
| --- | --- |
| Runtime ownership contract | `bbe33f1c0af37ab3f5b98963d588b1f4a6ba6f220ad9b2e9ca1e70f45cd996e5` |
| Jido compatibility record | `1690373172c8534f183d1d0bf2b613d31cfa14a0061764acc813535efe1af071` |
| Real-store Phase 1 integration fixture | `3d9b92cef205ee59ce1c746e03707c24e0612416bd6b692ddc75fa00f4b66a3c` |
| Threat-conformance fixture | `d6297888da8bacc1f690eb316cd210dfb36979935edf7f3da02e34704ec0a9c4` |
| Jido compatibility fixture | `30014d79afabfcb0b2b74f777aae1aa80e7a76898ed5dbe27bb7146ac77db579` |

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Managed profile/graph focused suite | Passed locally |
| Jido, threat, command, and architecture focused suite | 20 tests, 0 failures; architecture passed |
| Real isolated graph integration | 2 tests, 0 failures |
| Dialyzer | Passed; zero unignored candidate warnings |
| `mix precommit` | 754 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | Passed on PR #62; verify and Dialyzer succeeded |

## Known Limits And Disabled Posture

- Phase 1 defines and proves contracts only. Model calls, governed coding tools,
  workspace mutation, candidate generation, and verification handoff begin in
  later phases and remain unavailable here.
- The initial runtime is single-agent. Pod topology and specialists remain
  disabled until Phase 7 evidence explicitly accepts an exact task class.
- Recovery classification identifies effecting phases that require semantic
  reconciliation; it does not infer an effect result from missing runtime state.
- Human review and merge remain mandatory. No runtime, model, or candidate can
  attest verification, decide acceptance, publish, or merge.

## Gate MCG1

Status: **accepted at merged candidate**

MCG1 is accepted at merged candidate
`92d32f55a5afb5c59099a08fe4da762653dafdc3` after clean-checkout CI and merge
on 2026-08-24. Phase 2 is authorized only from this exact pinned baseline.

MCG1 reopens regardless of checklist state if any runtime field has ambiguous
ownership; any profile can widen authority or omit a required enforceable
budget; any runtime, Jido, pod, provider, sandbox, or workspace state becomes
required product truth; a command can carry runtime internals, credentials, or
unbounded content; an attempt can run without exact profile, strategy, fence,
and watermark pins; an effect can escape semantic accounting; Jido persistence
or hibernate/thaw becomes reachable; recovery depends on an agent checkpoint;
the threat matrix no longer fails closed; or the exact compatibility and
clean-checkout gates fail.
