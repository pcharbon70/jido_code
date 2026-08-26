# Repository Wiki Maintainer Runtime Specification

- Status: Approved and normative under accepted ADRs 0006 and 0007
- Specification version: `0.1.0`
- Owners: JidoCode Factory, runtime, knowledge, and documentation maintainers
- Decision: [ADR 0006](../adr/0006-per-repository-wiki-maintainer-agents.md)
- Wiki decision: [ADR 0005](../adr/0005-repository-wikis-as-compiled-knowledge-projections.md)
- Compilation protocol: [Repository wiki compilation and update](./repository-wiki-compilation-and-update-protocol.md)
- Enrollment and cost protocol: [Repository wiki enrollment, budget, and accounting](./repository-wiki-enrollment-budget-and-accounting.md)
- Existing boundaries:
  [Factory control loop](./factory-control-loop.md),
  [execution runtime](./execution-runtime-boundary.md), and
  [managed coding runtime](./managed-coding-runtime-contract.md)

## Purpose And Runtime Model

This specification defines “one running agent per project” as a stable logical
maintenance responsibility, not a permanent opaque model conversation.

Each enabled repository has exactly one selected logical
`WikiMaintainerProfile`. Work executes through disposable, fenced
`WikiMaintenanceAttempt` processes when reconciliation finds a missing,
stale, or explicitly requested edition. A deployment may keep lightweight
per-repository coordinator processes resident, but the graph is the only
durable queue, identity, progress, and recovery boundary.

Different repositories and multiple candidate sessions within one repository
may compile concurrently. One repository may have at most one current-source
winning compilation fence. Each preview has a distinct session/candidate
lease and fence and cannot request active-edition mutation. All graph
mutations still pass through the serialized Knowledge writer as bounded
semantic commands.

## Terms

| Term | Meaning |
| --- | --- |
| `WikiMaintainerProfile` | Immutable authority, compiler, runtime, model, tool, budget, review, and rollout envelope for one repository wiki |
| logical maintainer | Stable RDF identity selected by repository control |
| coordinator | Disposable Factory process that reconciles graph-visible wiki need and schedules attempts |
| maintenance attempt | One exact-source compilation run under a task, lease, and fence |
| deterministic worker | Process performing inventory, extraction, assembly, finalization, or lint without model synthesis |
| synthesis worker | Optional bounded host-controlled Jido agent invoked for one or more cited sections |
| winning fence | Current positive fencing token permitted to append/close/request activation for the repository wiki |

## Profile Resource

`WikiMaintainerProfile` is immutable. Any material change creates a successor
and cannot reinterpret a running or historical attempt.

### Required Fields

| Field | Contract |
| --- | --- |
| `iri`, `revision`, `profileDigest`, `signedDigest` | Deterministic immutable identity and authorized full material digest |
| `maintainerKey`, `displayName` | Stable closed key and bounded presentation label; never dispatch input |
| `repository`, `wiki`, `owner`, `tenantBindings` | Exact authority partition; no wildcard fallback in the initial profile |
| `runtimeClass` | Initially exactly `host_controlled` |
| `compilerProfile` | Exact inventory, page schema, renderer, redaction, link, metadata, and edition-root revisions |
| `mixProfile` | Exact static parser, lock parser, sandbox introspection, resolver, toolchain, and environment/target envelope |
| `synthesisPolicy` | `disabled` or exact allowed page/section/risk classes |
| `modelProfile` | Exact model access/profile identity when synthesis is enabled; explicit absence otherwise |
| `toolProfile` | Closed deterministic extractor, source-content, sandbox, metadata, and lint registry keys/digests |
| `queryProfile` | Exact reviewed input, discovery, recovery, and activation-readiness query versions |
| `reviewPolicy` | Page/risk classes requiring independent review before activation |
| `retentionPolicy` | Edition-purpose retention and artifact classes |
| `schedulePolicy` | Reconciliation interval, debounce/coalescing, maximum staleness, priority class, and session-fan-out rules |
| `capacityPolicy` | Finite per-attempt, per-session, per-repository, per-tenant, and fleet file/page/segment/token/time/process/memory/disk/request/cost ceilings |
| `state` | `disabled`, `enabled`, `revoked`, or `superseded` |
| `rolloutStage` | `disabled`, `evaluation`, `shadow`, `pilot`, or `production` |
| `approvedAt`, `expiresAt`, `signer` | Approval provenance and finite validity |

Repository files, prompts, model output, UI fields, process state, and
environment variables cannot select or override these values.

The profile is necessary but not sufficient to start work. Repository control
must also select a current compatible `WikiGenerationProfile`. Missing or
disabled configuration prevents all work; manual mode prevents coordinator-
discovered automatic work; deterministic-only mode removes the synthesis
gateway capability; and preview-disabled mode rejects session previews.

The initial accepted deployment MUST NOT use `delegated_cli` for wiki
maintenance. A future delegated profile requires accepted ADRs 0003 and 0004,
a qualified exact adapter/profile pair, and all authority and conformance rules
in this specification. No implicit fallback exists between native and
delegated runtimes.

## Authority Ceiling

The maintainer's effective authority is the intersection of authenticated
actor/delegation, repository policy, exact profile, task, lease, fence,
runtime, tool registry, source visibility, and current rollout.

It MAY:

- read bounded reviewed projections for its exact repository and input
  revisions;
- obtain an exact disposable checkout through the registered source adapter;
- run registered deterministic parsing, inventory, and lint operations;
- request fixed sandboxed Mix introspection;
- request allowlisted metadata observations through the host adapter;
- invoke the exact optional synthesis model through the model gateway;
- submit bounded segments for its exact building edition;
- request finalization, lint recording, closure, and independent activation
  evaluation; and
- record bounded findings, costs, health, and receipts.

It MUST NOT:

- read or select another repository or tenant;
- receive raw TripleStore handles, arbitrary SPARQL, a generic command writer,
  or arbitrary filesystem/network/process tools;
- mutate source, authored documentation, branches, tags, pull requests, or
  provider issues;
- approve, publish, merge, deploy, release, satisfy a goal, accept evidence,
  adopt memory, or change policy;
- select a graph family, compiler, model, tool, endpoint, credential, sandbox,
  profile, review rule, or activation rule;
- treat untrusted repository, dependency, prior-wiki, issue, or model content
  as control instructions;
- preserve hidden reasoning or unbounded provider transcripts; or
- activate an edition merely because its own compile or lint returned success.

A missing or stale guide produces a finding or proposed work intent. Source
repair is performed by a separately admitted coding workflow.

## Durable Identity And Attempt Admission

A maintenance attempt binds:

- repository, wiki, maintainer profile revision, and compilation request;
- originating coding session/attempt, candidate, private audience, and
  session-local fence for preview mode, with explicit absence for current
  source;
- target source snapshot/candidate manifest and exact graph input revisions;
- compiler, Mix, tool, query, optional model, and review profile digests;
- accountable actor, delegation when used, tenant, and capability;
- task, lease, positive fence, idempotency, correlation, and causation;
- expected active/predecessor edition;
- edition purpose and visibility;
- all budgets and deadlines; and
- admitted runtime deployment and worker image revisions.

Admission is committed before checkout, sandbox, metadata, or model effects.
It rejects missing identity, wildcard resolution, stale source/control heads,
expired profile, incompatible version, unavailable required capability,
existing winning lease, or insufficient capacity.

Process PIDs, supervisor children, worktree paths, sandbox IDs, provider
request/session IDs, local caches, model conversation state, and PubSub
messages are disposable observations.

## Supervision Topology

The implementation SHOULD extend the accepted Factory topology with modules
equivalent to:

```text
JidoCode.Factory.Supervisor
  WikiCoordinator
  WikiAttemptSupervisor (DynamicSupervisor)
    WikiMaintenanceAttempt
      deterministic task supervisor children
      optional bounded synthesis agent
      effect adapters through existing gateways
```

One fleet-level `WikiCoordinator` is sufficient when it preserves repository
partitioning. A sharded or per-repository coordinator deployment is allowed
only when graph leases/fences remain the correctness boundary and shard
assignment is deterministic, bounded, recoverable, and non-authoritative.

`Registry`, ETS, process mailboxes, timers, and local queues may accelerate
delivery but cannot prove ownership or progress. Every child has an explicit
OTP name/registry strategy and no repository-controlled atom is created.

## Reconciliation Loop

The coordinator runs on startup, a bounded periodic schedule, after a worker
exit, and on lossy PubSub wake hints. Each pass:

1. reads a bounded page of `WikiCompilationCandidatesByPriority` at one
   dataset revision;
2. authorizes the exact selected maintainer profile and repository scope;
3. coalesces only compatible current-source requests for the same repository,
   preserves mandatory releases, and keeps distinct session/candidate preview
   requests isolated;
4. checks global, tenant, repository, sandbox, metadata, model, and cost
   capacity;
5. acquires one semantic lease and next fencing token;
6. commits attempt admission and exact compilation inputs;
7. starts a disposable attempt child; and
8. schedules the next pass from graph state, not the local result alone.

PubSub payloads contain only bounded refresh identity and are never applied as
truth. Dropped, duplicated, reordered, or forged hints cannot lose work or
create authority.

## Per-Repository And Per-Session Serialization

For the current-source line of one repository wiki:

- at most one active compilation lease and winning fence exist;
- every effect and semantic mutation carries attempt, lease, and fence;
- lease renewal verifies request, profile, source, cancellation, and current
  fence;
- a newer source may create a successor request and cancel/supersede the old
  ordinary compile;
- the prior attempt's late metadata, model, segment, lint, or activation
  result is rejected after fence loss; and
- exact preview and release work use separate purpose identities but still
  obey policy-defined per-repository concurrency.

For candidate previews:

- the serialization key includes repository, coding session/attempt,
  candidate identity, audience, and edition purpose;
- at most one winning compile fence exists for that exact preview key;
- multiple preview keys may run concurrently under repository/tenant/fleet
  limits;
- a preview fence has no authority over the current-source lease, active
  pointer, sibling preview, or another session's cancellation; and
- identical base revisions, dependency graphs, or generated page digests do
  not collapse session ownership or visibility.

Cancellation intent commits before terminating runtime processes. Process
termination without semantic cancellation does not revoke graph authority;
fence change or lease expiry does.

## Cross-Repository Concurrency And Fairness

Repositories may inventory, run isolated Mix introspection, fetch metadata,
and synthesize in parallel, including bounded preview work for multiple coding
sessions on one repository. The initial scheduler MUST enforce:

- finite global and per-tenant active-attempt limits;
- finite per-session and per-repository preview-attempt limits;
- finite sandbox, model, provider-request, token, and cost pools;
- at most one ordinary current-source attempt per repository;
- weighted deterministic priority for security/release/current/stale/preview
  classes, with preview fan-out unable to starve current-source freshness;
- aging so an eligible quiet repository cannot starve behind hot repositories;
- round-robin or equivalent tenant fairness within a priority/age band;
- per-repository debounce and source-change coalescing;
- bounded candidate query pages and dispatch batches; and
- explicit unavailable/backpressure state when capacity is exhausted.

A repository with repeated commits cannot monopolize compilation. The
coordinator may abandon unactivated intermediate ordinary editions and compile
the newest observed source, while preserving editions mandated by release or
audit policy.

A repository with many parallel coding sessions also cannot monopolize
sandbox, model, metadata, or writer capacity. Session-level aging applies only
within its repository/tenant allocation and cannot amplify the repository's
fleet share by opening more sessions.

All graph mutations remain serial through the Knowledge writer. Worker
parallelism does not authorize direct concurrent store handles.

## Attempt Execution

The attempt follows these runtime phases:

```text
admitted -> acquiring_source -> extracting -> assembling
  -> synthesizing? -> publishing -> finalizing -> linting
  -> awaiting_review? -> activation_requested -> completed

any nonterminal phase -> cancelling -> cancelled
any nonterminal phase -> failed | incomplete | superseded
```

The exact semantic states and transitions MUST be versioned; this diagram does
not authorize a mutable process-only state machine.

Before every phase and external effect, the worker rechecks current request,
lease, fence, cancellation, profile, source head where relevant, and budget.
Phase output is a bounded value or provider-owned artifact adopted through a
semantic command. No phase passes raw graph/store capability to the next.

## Deterministic Work And Optional Agent Synthesis

Deterministic extraction is always attempted before model work. A repository
with synthesis disabled or an unavailable model can still produce a useful
deterministic edition with explicit gaps.

When enabled, synthesis uses a host-controlled `Jido.Agent` under the exact
model/tool/context profile. The agent receives section-scoped citation-first
context, closed structured output, finite tokens/turns/time/cost, and no
filesystem, shell, network, graph, source-write, publication, or activation
tool.

Before every model call, the runtime obtains the exact committed budget
reservation defined by ADR 0007. Provider dispatch without it is impossible.
Afterward the runtime adopts provider/gateway token observations and calculated
cost, releases only proven unused exposure, and holds ambiguous exposure. A
local token counter or telemetry event cannot authorize the next call.

One process may synthesize multiple bounded sections, but every adopted
section records its own inputs and output digest. Process conversation is not
repository memory and is destroyed after the attempt. Cross-attempt or cross-
repository provider sessions are forbidden in the initial profile.

## Separation From Coding Agents

A coding session/attempt and wiki maintenance attempt have distinct profiles,
tasks, leases, fences, contexts, workspaces, runtime identities, budgets, and
authority. Each coding session pins one exact wiki-context identity; the
maintainer does not mutate that captured context when a newer active edition
appears.

The coding agent MAY request a private candidate preview through a governed
intent and consume authorized wiki projections as context. The request binds
its session/attempt, candidate, fence, and audience. It cannot append to or
activate the wiki directly, nor observe or control a sibling session's
preview. Its provider session, worktree analysis, claimed checks, summaries,
and hidden state are not reused as the final current-source compiler.

After external merge observation, a fresh maintenance attempt reads the exact
observed tree and accepted graph projections. This enforces generation,
verification, external publication, and documentation-presentation separation.

## Interaction And Review

The initial runtime is autonomous within its exact profile; it cannot ask a
model or arbitrary person to expand authority. When required information or
review is missing, it commits a bounded `WikiGap` or `WikiReviewRequest` and
stops or closes incomplete according to policy.

Review is an independent graph-scoped action. The reviewer sees the exact
edition, source snapshot, synthesized sections, citations, lint, differences,
and limitations. Approval binds edition root, review policy, reviewer scope,
and time. A changed edition root or blocking lint invalidates prior approval.

Review approval permits activation evaluation only. It is not source
acceptance, evidence acceptance, goal satisfaction, or memory adoption.

## Effects, Accounting, And Telemetry

Every checkout, sandbox, metadata, model, artifact, lint, and activation
operation records invocation before effect and terminal or ambiguous outcome.
Adopted observations include exact attempt/fence/profile correlation, bounded
timing, resource use, provider request class, reservation identity, token/cost
values with provider/gateway/estimated provenance, explicit unavailable or
contradicted dimensions, output digest, and omission state.

Telemetry MUST include bounded dimensions for:

- candidate discovery, queue age, dispatch, coalescing, session fan-out, and
  starvation;
- attempts and duration by phase/outcome/purpose/runtime/profile;
- source files/bytes, pages, dependencies, segments, statements, citations,
  links, gaps, and lint findings;
- sandbox and metadata request outcomes;
- model calls/tokens/cost/invalid-output/uncited-claim rates;
- lease/fence conflicts, late-result rejection, cancellation, and recovery;
- activation lag from externally observed source;
- active-edition freshness and compiler compatibility; and
- capacity saturation by pool without repository names in low-cardinality
  metric labels.

Logs, traces, telemetry, receipts, and UI MUST NOT expose source bodies,
authored private docs, prompts, generated unredacted prose, raw model output,
credentials, provider sessions, absolute paths, graph names, raw SPARQL, or
high-cardinality dependency/repository identifiers outside authorized detail.

## Cancellation And Supersession

Cancellation order is:

1. commit cancellation/supersession intent;
2. invalidate or advance the winning fence as policy requires;
3. revoke outstanding source, sandbox, metadata, model, artifact, and command
   permits;
4. request cooperative worker stop;
5. terminate sandbox/process descendants within the bound;
6. reject every late observation and mutation by fence; and
7. commit terminal accounting and retention disposition.

An already closed edition remains immutable. If cancellation occurs before
activation, it stays private/inactive and follows failed/superseded retention.
If activation already committed, a new authorized control transition is
required to select a successor or invalidate selection.

## Crash And Restart Recovery

On process or node restart, the coordinator re-queries:

- enabled exact profiles and compatibility;
- compilation requests and priority;
- current leases, fences, cancellations, and deadlines;
- current repository wiki configuration, pricing, budget accounts/windows,
  outstanding reservations, and usage-accounting compatibility;
- admitted attempts and last semantic phase;
- edition manifests, graph revisions, and accepted segment receipts;
- source and repository-control heads;
- external effect invocation/result/ambiguity records;
- lint, review, closure, and activation state; and
- current capacity/accounting policy.

It MAY resume at the next missing deterministic/segment phase when all
identities match, repeat a proven safe deterministic operation, reconcile an
external effect, cancel/supersede, close incomplete, or schedule a fresh
attempt. It MUST NOT infer success from a surviving PID, worktree, sandbox,
cache, journal, model session, PubSub event, or local file.

Runtime-profile incompatibility prevents automatic resume. An operator can
cancel or create a successor request through semantic commands; they cannot
edit graph state around the contract.

## Feature Disable And Degradation

The runtime starts no attempt unless exact queries, callbacks, profiles,
sandboxes, metadata adapters, lint, and capacity policy are configured and
compatible. Disabling a profile or fleet feature:

- prevents new lease acquisition immediately;
- requests cancellation for active attempts;
- causes current fence/profile checks to reject late results;
- leaves already closed/active editions readable under freshness and
  compatibility policy; and
- requires no process-local queue drain for durable correctness.

Repository-level opt-out follows the same fail-closed effect order without
requiring the fleet feature or shared maintainer profile to be disabled for
other repositories. It retains attributable cost from already dispatched
effects and applies existing-edition read/retention policy separately.

Model, package-provider, or sandbox outage may degrade to deterministic pages
or explicit unavailable/incomplete state when policy permits. TripleStore or
semantic-writer unavailability prevents new durable progress; workers
backpressure/cancel rather than accumulating an unbounded local queue.

## Required Commands And Queries

Implementation planning MUST introduce versioned resources and semantic
intents equivalent to:

- `RegisterWikiMaintainerProfile`;
- `TransitionWikiMaintainerProfile`;
- `AssignRepositoryWikiMaintainer`;
- `AdmitWikiMaintenanceAttempt`;
- `AcquireWikiMaintenanceLease` and `RenewWikiMaintenanceLease`;
- `CancelWikiMaintenanceAttempt`; and
- terminal attempt/accounting transitions.

Reviewed queries MUST include:

- `WikiMaintainerByRepository`;
- `WikiMaintainerProfileDetail`;
- `WikiCompilationCandidatesByPriority`;
- `WikiAttemptRecoveryState`;
- `WikiFleetCapacitySummary`;
- `WikiRepositoryMaintenanceHistory`; and
- operator-only bounded late-result and ambiguity diagnostics.

Every registration/assignment/transition uses exact expected graph revisions,
signature/approval, actor, tenant, repository, reason, idempotency,
provenance, audit, and bounded receipts.

## Conformance Requirements

Tests MUST prove:

1. exact maintainer and generation profile identity/signature, closed
   runtime/tool/model/mode vocabularies, repository assignment, expiry,
   revocation, opt-out, and no fallback;
2. recovery discovers missing work after complete coordinator, Registry, ETS,
   timer, and PubSub loss;
3. one winning current-source lease/fence per repository, one winning fence
   per exact session/candidate preview, and concurrent bounded progress for
   multiple repositories and same-repository sessions;
4. fairness, aging, capacity, current-source coalescing, preview isolation,
   session-fan-out limits, and hot-repository starvation bounds;
5. every checkout/sandbox/metadata/model/segment/lint/activation effect rejects
   stale fence, expired lease, cancellation, newer source, or revoked profile;
6. deterministic-only editions have no model gateway capability and zero model
   calls/tokens, while synthesis editions reserve and account every call and
   both preserve citation, authority, and completeness semantics;
7. coding-agent worktree/session/output cannot become final wiki authority or
   leak into another session's captured context or preview;
8. maintainer tools cannot mutate source, access arbitrary graphs/network,
   publish, merge, accept, satisfy, adopt, or activate directly;
9. crash, restart, resistant descendant, provider outage, ambiguous effect or
   usage, budget exhaustion, partial edition, repository opt-out, disabled
   feature, and incompatible profile recover without local durable state; and
10. multi-repository and parallel same-repository-session adversarial tests
    show zero cross-tenant or cross-session context, credential, metadata,
    artifact, page, cache, log, wake-hint, or query disclosure.
