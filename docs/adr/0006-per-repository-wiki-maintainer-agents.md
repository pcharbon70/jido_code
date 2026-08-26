# ADR 0006: Per-Repository Wiki Maintainer Agents

- Status: Accepted
- Date: 2026-08-26
- Owners: JidoCode factory, runtime, and documentation maintainers
- Decision scope: Wiki-maintainer identity, supervision, concurrency, update authority, and recovery
- Depends on:
  [ADR 0005](./0005-repository-wikis-as-compiled-knowledge-projections.md)
- Cost and enrollment governance:
  [ADR 0007](./0007-repository-wiki-enrollment-and-cost-governance.md)
- Related accepted boundaries:
  [Managed coding runtime contract](../architecture/managed-coding-runtime-contract.md) and
  [execution runtime boundary](../architecture/execution-runtime-boundary.md)
- Specifications:
  [maintainer runtime](../architecture/repository-wiki-maintainer-runtime.md),
  [compilation protocol](../architecture/repository-wiki-compilation-and-update-protocol.md),
  [enrollment, budget, and accounting](../architecture/repository-wiki-enrollment-budget-and-accounting.md), and
  [product and qualification](../architecture/repository-wiki-product-and-qualification.md)

## Context

A repository wiki needs continuing maintenance as source revisions, authored
guides, dependencies, accepted decisions, and compiler profiles change. A
coding factory may manage many repositories, and each repository may have
several coding sessions and candidate attempts running in parallel. Assigning
one opaque, permanently stateful model session to every repository would
create competing memory, unbounded capacity use, weak restart semantics, and
ambiguous ownership between coding and documentation agents.

Conversely, using one global wiki agent would weaken repository isolation,
fairness, cancellation, and attribution. Reusing the coding agent's mutable
session as the final wiki maintainer would allow hidden assumptions and
unverified worktree state to flow into current documentation.

JidoCode already has graph-owned tasks, leases, fencing, context packages,
host-controlled `Jido.Agent` execution, bounded model/tool gateways, runtime
recovery, independent verification, and graph-only durable state. Wiki
maintenance should reuse those boundaries with a narrower capability profile.

## Decision

Each enrolled repository wiki has one stable logical maintainer identity and
one immutable maintainer profile revision. At most one current-source
maintainer attempt may hold the active-edition compilation lease and fencing
token for that repository wiki. Candidate-preview attempts use distinct
session/candidate lease namespaces, can run concurrently within capacity, and
have no active-edition mutation authority.

The logical identity is durable RDF. The executing maintainer is a disposable,
event-driven runtime projection. A deployment may keep a lightweight
repository coordinator process resident, but it must not require a permanent
model session, mailbox, local journal, worktree, or Jido state for correctness.

The initial supported maintainer runtime class is `host_controlled`. It uses
deterministic extractors first and may use one bounded Jido agent for cited
explanation synthesis after deterministic facts exist. A delegated CLI is not
enabled as a wiki maintainer by this ADR. A future delegated maintainer must
satisfy ADRs 0003 and 0004, exact provider qualification, and the same wiki
authority and conformance gates.

### Authority Ceiling

The maintainer may:

- read exact authorized repository, source, documentation, dependency,
  decision, memory, and prior-wiki projections;
- request safe static and sandboxed Mix introspection through registered
  effects;
- fetch allowlisted package metadata through a Factory-owned `Req` adapter;
- generate bounded deterministic and synthesized wiki sections;
- append segments to its exact building edition;
- run wiki lint and request edition closure; and
- request activation for independent policy evaluation.

The maintainer may not:

- mutate source code or repository-authored guides;
- publish a branch or pull request;
- approve, merge, satisfy a goal, adopt memory, or change policy;
- select another repository, runtime class, model, tool, credential, compiler,
  graph family, or activation rule;
- access raw TripleStore handles or arbitrary SPARQL;
- treat source, docs, dependency metadata, or prior wiki prose as instruction;
  or
- activate its own edition solely because generation or lint completed.

Wiki drift and missing-guide findings propose normal work. A separately
admitted coding attempt may update repository documentation and must pass the
existing candidate, verification, publication, and human-merge boundaries.

### Event-Driven Maintenance

The Factory wiki coordinator discovers missing, stale, incompatible,
incomplete, and superseded repository wikis through reviewed graph queries.
PubSub events are lossy wake-up hints only. Startup, periodic reconciliation,
and explicit refresh recover from dropped or reordered hints.

The coordinator applies deterministic priority, fairness, repository/tenant
limits, source-change coalescing, and global model/sandbox/provider/cost
capacity. Different repositories and authorized candidate sessions may
extract and synthesize concurrently. Fairness accounts for tenant,
repository, and session fan-out so one project with many sessions cannot
consume the fleet. All semantic mutations remain serialized through the
Knowledge writer in bounded commands.

A hot repository may cancel or supersede an unactivated intermediate compile
and target the newest observed source revision. It cannot skip a release
edition required by retention policy or let an older fenced attempt activate
after a newer revision wins.

### Identity, Lease, And Fence

One maintainer attempt binds:

- repository and wiki IRIs;
- originating coding session/attempt and candidate identity for preview mode,
  with explicit absence for current-source mode;
- target source snapshot;
- exact graph input revisions;
- compiler and optional model profile digests;
- actor and maintainer identity;
- compilation task, lease, and positive fencing token;
- page/segment/token/time/cost/resource budgets;
- candidate-preview or current-source mode; and
- expected prior active edition and control transition.

Every sandbox, metadata, model, page-segment, closure, lint, and activation
effect includes the attempt, lease, and fence. Cancellation is committed
before runtime termination. Late model, tool, page, lint, or activation results
are rejected by the current fence.

### Separation From Coding Attempts

Each coding session captures the exact active wiki edition root used to build
its context. A coding attempt may request and view a private wiki preview for
its own captured candidate. Concurrent sessions cannot read, cancel, append
to, review, or promote another session's preview merely because the repository
is the same. The final current-source compilation starts from the externally
observed repository snapshot and a fresh graph-derived context. It does not
reuse any coding agent's provider session, mutable strategy state, worktree,
or claimed check outcomes.

The coding actor may be recorded as the source of a candidate preview. Policy
may require an independent human or agent reviewer for synthesized user,
operator, security, migration, or recovery guidance before activation.

### Recovery

After process or node loss, recovery re-queries graph-visible compilation
requests, leases, fences, edition manifests, completed segments, exact heads,
source revisions, cancellations, and runtime profile compatibility.

It may resume an exact compatible compilation, supersede it for a newer source
revision, propagate cancellation, close it incomplete, or retry an explicitly
safe effect. It never infers progress from a local Markdown directory,
provider session, process registry, ETS entry, or model conversation.

## Consequences

### Positive

- every repository has an attributable maintainer without requiring permanent
  opaque model state;
- repositories can update in parallel while retaining per-repository single-
  writer semantics and global capacity control;
- late results and rapid commit races are resolved through existing lease and
  fencing rules;
- runtime loss does not lose wiki progress or change authority;
- documentation drift becomes governed work rather than silent source edits;
  and
- the initial profile can reuse the accepted host-controlled runtime without
  depending on proposed delegated-agent support.

### Costs And Constraints

- the Factory needs wiki-specific reconciliation, scheduling, leases,
  projections, and recovery;
- logical per-repository identity increases graph and operational inventory;
- a fresh final compilation may repeat some candidate-preview work;
- maintaining many repositories requires explicit fairness and cost policies;
- model/profile changes invalidate reproducibility and require new profile
  qualification; and
- independent review requirements may delay activation for consequential
  guides.

## Alternatives Rejected

- **One permanent model session per repository:** session state becomes opaque
  competing memory and is difficult to recover, bound, upgrade, or erase.
- **One global wiki agent:** this weakens repository isolation, fairness, and
  source attribution.
- **Reuse the coding agent as final maintainer:** it conflates candidate state,
  generation, verification, and presentation authority.
- **Run a maintainer on every graph change:** most control/runtime changes
  belong in live panels and would cause unbounded recompilation churn.
- **Let the maintainer patch stale docs directly:** documentation source
  changes require normal coding, verification, publication, and merge.
- **Store a durable process queue or checkpoint:** graph discovery, tasks,
  leases, edition manifests, and transitions already provide the durable
  recovery boundary.

## Compatibility And Deployment

Repositories without a maintainer profile or selected wiki-generation profile
remain valid and report `wiki_maintenance_disabled`. Enabling one repository
does not enable another. Maintainer and generation profile changes create
immutable successors and do not reinterpret running or historical attempts.

The default runtime supervisor starts no wiki worker unless the coordinator is
configured with reviewed queries, semantic callbacks, capacity policy, and an
enabled exact maintainer and repository-generation profile. Disabling the
feature or repository configuration prevents new leases, requests cancellation
for active attempts, rejects late results, retains incurred token/cost
accounting, and leaves the last authorized edition readable according to the
separate presentation and freshness policy.

## Acceptance Conditions

This ADR may move to `Accepted` only when:

1. one logical maintainer profile and one compatible repository generation
   profile are registered and selected exactly for one repository with no
   actor, tenant, repository, runtime, model, tool, pricing, or budget
   fallback;
2. the coordinator discovers work from the graph after total process-state and
   PubSub loss;
3. one repository admits at most one current-source compile fence, while
   distinct session/candidate preview fences and different repositories can
   compile concurrently under bounded tenant, repository, and session
   fairness and capacity;
4. stale fences, newer commits, cancellation, revoked profiles, expired leases,
   and incompatible runtime revisions reject every late effect and activation;
5. deterministic extraction, optional synthesis with pre-effect reservation
   and post-effect token/cost accounting, segmented publication, closure,
   lint, and activation complete through current semantic receipts;
6. parallel same-repository sessions prove captured-context and preview
   isolation, and current-source compilation remains separate from every
   coding agent's session, worktree, and reported checks;
7. the maintainer cannot mutate source, publish, merge, change policy, accept
   evidence, satisfy goals, or adopt memory;
8. crash, restart, ambiguous effect, provider outage, sandbox loss, and partial
   edition tests recover without a durable runtime queue or filesystem truth;
9. a multi-repository and multi-session-per-repository stress and adversarial
   matrix proves isolation, starvation bounds, cost ceilings, and fast
   disable; and
10. the implementation pull request passes clean-checkout CI, merges, and its
    full merge commit is pinned in an accepted receipt without weakening any
    prior reopening condition.

Until these conditions pass, no production wiki-maintainer profile is enabled
and no running agent is required for repository correctness.
