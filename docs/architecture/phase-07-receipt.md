# Phase 7 Factory Control Loop Receipt

## Status

This receipt records the Phase 7 candidate verified locally on 2026-08-03 and
accepted after pull request merge on 2026-08-03.
Desired outcomes, policies, cohorts, obligations, graph-native work,
reconciliation, closed-world eligibility, capabilities, deterministic
scheduling, and fenced leases are implemented through the graph-only authority
boundary.

G6 is accepted at merged candidate `f7b3d57748c7c830add4a815257ed3a79ce54e29`
after the pull request passed clean-checkout CI on 2026-08-03. No local
evidence found durable work outside TripleStore, absence-based eligibility
without a complete boundary, inferred authority, an unfenced execution grant,
or a scheduler queue required for restart recovery.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G5 | `394657afdb1ad2453f7f21a0ceef61351d60860e` |
| Section 7.1 | `6a375c135951a99ebc6903d3e4e9809e306ad35e` - model desired state and work graphs |
| Section 7.2 | `e752526e5d5963890905900794cca90082be24b5` - add graph-native governance contracts |
| Section 7.3 | `8ae6748be3d27b6644ddf866b93e95d1359b7c84` - implement graph-native reconciliation |
| Section 7.4 | `596189762e5366d6bab6ccdded04ad27f4f2b269` - add fenced graph scheduling |
| Section 7.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Merged candidate | `f7b3d57748c7c830add4a815257ed3a79ce54e29` |

## Contract Pins

| Contract | Accepted candidate value |
| --- | --- |
| Command registry version | `1.5.0` |
| Registered intent commands | 29 |
| Query catalog version | `1.5.0` |
| Reviewed queries | 57 |
| Query catalog SHA-256 | `b8bc265213287531bde5c66307ac6eb9af04f66747d14e4370f9ddddd3cbefbc` |
| Policy/applicability evaluator | `protected_main/1.0.0`; `repository_attributes/1.0.0` |
| Reconciliation rule/query | `1.0.0` / `1.4.0` input package, `1.5.0` scheduling reads |
| Factory ontology / operational shapes | `1.0.0` / `1.0.0` |
| Ontology package SHA-256 | `5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1e3f8b73535c5903` |
| TripleStore pin | `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| Capability fixture | Two observed `phase-07-agent/1.0.0` providers with explicit execution authorization and concurrency 1 |
| Scheduler defaults | global 16, repository 2, cohort 8, capability 4, maximum risk 10, 30-second graph rediscovery |
| Scheduler hard bounds | 1,000 candidates, 32 concurrent acquisitions, 10-300,000 ms rediscovery interval |

## Accepted Contract

- Desired outcomes remain policy intent, observations remain sourced claims,
  inferred facts remain rebuildable, and only authorized accepted transitions
  change control state.
- Goals, plans, tasks, dependencies, constraints, policies, cohorts,
  obligations, capabilities, reconciliation inputs/results, eligibility
  receipts, leases, and decisions are connected RDF resources. `WorkItem`,
  queue, scheduler, and coordinator values are disposable projections.
- Plan adoption is distinct from proposal. Reconciliation can derive or reuse
  gaps, obligations, and goals but cannot adopt work or grant a lease.
- Reconciliation packages bind one coherent enrollment, observation, source,
  policy, derived, and control revision set. Mixed, stale, unauthorized,
  contradictory, over-budget, or incomplete inputs fail closed or retain an
  explicit unknown/decision classification.
- Eligibility requires explicit complete dependency, artifact, source,
  cancellation, policy, capability, capacity, and lease boundaries. Unknown,
  stale, contradictory, unauthorized, over-capacity, or incomplete input
  returns machine-readable blockers.
- Capability possession, availability, classification, and authorization are
  distinct. Inferred hierarchy facts cannot grant scheduling authority.
- `AcquireExecutionLease` atomically persists the eligibility receipt, task
  eligible/leased transition, complete lease proposed/active chain, expiry,
  holder, capability, policy, and next monotonic task fence.
- Renewal requires the current fence, endpoint, liveness evidence, unchanged
  holder/capability, and bounded later expiry. Release, cancellation, observed
  expiry, supersession, and reacquisition append history instead of replacing
  lease records.
- Every execution mutation presents a control graph, task, lease IRI, fence,
  and evaluation time to the current-lease guard. An expired, released,
  cancelled, superseded, or stale-fence process has no write authority.
- Scheduler and reconciler startup, periodic passes, retries, and wake-up hints
  rediscover graph state. Recent results and coalescing maps are diagnostics,
  not a durable queue or hidden ownership source.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Desired outcome, goal, plan, and task graph fixture | `c8ca325e431d1600ccb82be449642c7c18805dead9d6a6e2371f2f075d26f84c` |
| Policy, cohort, obligation, and capability fixture | `1ad147e82c6be34582221edc1f8f1c39db220895d10a984255e388020eb45734` |
| Exact-context reconciliation fixture | `8e516adb592c2bbac9eaffd8f127958305a78993aa18222446885d612f6d6395` |
| Eligibility and fenced-lease fixture | `8ddb01518455dcfd54945c5f2ed83def56181911231c9f96ad5471ff99926ac6` |
| Scheduling lifecycle/race/restart scenarios | `151f534c0f5cbdbdf108569922eed0df7615de2fbf6b399985431623944f0e8e` |
| End-to-end control-loop integration | `bfc4bc3ff16c065288b26cbc164d622ca9c23f92db4d628d98c2a9e0fbd21f52` |

The fixtures start the real StoreServer, Writer, QueryRunner, Maintenance, and
embedded TripleStore; load the pinned ontology; bootstrap graph authority; and
commit product facts only through semantic commands. Fixed clocks,
deterministic identities, exact graph revisions, and isolated temporary stores
make replay and race outcomes comparable.

## Executable Evidence

The Phase 7 integration and retained focused suites prove:

- one repository observation, contradictory desired outcome, policy,
  applicability path, obligation, approved goal/task plan, reconciliation gap,
  and reused work proposal remain connected and reconstructable by exact graph
  revision;
- identical and reordered reconciliation input reuses the same semantic
  identities, while a policy/source revision change creates an explicit new
  context;
- unknown observations, contradictions, policy conflicts, stale source,
  missing or inferred-only capabilities, suspended enrollment, incomplete
  boundaries, approval requirements, and capacity exhaustion do not become
  eligible work;
- one active policy is evaluated over a graph-derived cohort containing two
  independently enrolled repositories, with complete applicability paths and
  denied repository-scoped cohort enumeration;
- two authorized capability providers race one task and produce exactly one
  committed lease/fence and one deterministic refreshable conflict;
- lease renewal, release, cancellation, expiry, supersession, monotonic
  reacquisition, and stale-fence rejection preserve prior lease history;
- scheduler ordering and global/cohort/repository/capability/risk admission are
  deterministic from graph-discovered candidates and active leases; and
- reconciler and scheduler restart plus periodic rediscovery recover eligible,
  blocked, leased, and incomplete work when wake-up notifications are absent.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 7 final integration file | 3 tests, 0 failures |
| Phase 7 focused work/governance/reconciliation/scheduling files | 19 tests, 0 failures |
| `mix precommit` | 205 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| `mix jido_code.ontology verify` | Package and canonical ontology digests verified |
| `mix hex.audit` | No retired packages found |

No frontend or asset behavior changed in Phase 7, so browser and production
asset gates remain inherited from the merged Phase 6 baseline.

## Operational Limits

- Reconciliation admits at most 100 evaluations, 30 references per bounded
  relation, package-defined row/change/time budgets, and exact authorized graph
  revisions.
- Eligibility admits at most 16 exact graphs and 100 dependency, artifact, or
  capability values. Every required negative conclusion has an explicit
  complete boundary.
- Lease acquisition and transition use one repository-control graph command,
  the command pipeline's 100-guard and 262,144-byte payload limits, one current
  task/lease endpoint, and one monotonic task fence.
- Reviewed queries retain the five-second, 200-row, 500-triple, 256,000-byte,
  20-graph, and 100-parameter defaults.
- Scheduler process state retains at most 1,000 candidates and 200 recent
  results. Candidate and active-lease snapshots are rediscovered and never
  persisted outside the graph.

## Gate G6

G6 is accepted at merged candidate `f7b3d57748c7c830add4a815257ed3a79ce54e29`,
pinned in this receipt and the Phase 7 plan. Any
evidence that work exists only in a queue/struct, incomplete absence satisfies
eligibility, inferred capability grants authority, or execution mutates state
without the current lease/fence reopens the gate.
