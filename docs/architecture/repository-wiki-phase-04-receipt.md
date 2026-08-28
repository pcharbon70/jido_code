# Repository Wiki Phase 4 Maintainer, Budget, And Accounting Receipt

## Status

This merge-pending receipt records the Phase 4 implementation built from
repository main commit `28cc2c8c06f738db9f0d9f1b78c8b729b62b27f8`, which
contains the accepted RW3 merged candidate at
`b57b1d7eb19406d73a8fe8ca16948b62a9746f3a`. The implementation candidate is
not accepted until its single implementation pull request passes exact-head
clean-checkout CI, merges, and this receipt is updated in the required closure
pull request with the full merge commit and merge date.

The candidate installs optional per-repository maintainer ownership, bounded
fleet scheduling, deterministic automatic updates, finite budgets and
reservations, terminal token and monetary accounting, a structurally disabled
production synthesis boundary, accounting reconciliation, authoritative
opt-out, and graph-derived recovery. Different repositories can progress in
parallel, but one repository has at most one current maintainer owner and one
current-source transition. Phase 5 remains unauthorized while this receipt is
merge-pending.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted RW3 prerequisite | `b57b1d7eb19406d73a8fe8ca16948b62a9746f3a` |
| Phase 4 shared-main baseline | `28cc2c8c06f738db9f0d9f1b78c8b729b62b27f8` |
| Section 4.1 | `3a54ddf59536b05a2363ea101ff2a193883df6a1` - generation profiles, prices, budgets, reservations, and usage accounting |
| Section 4.2 | `8b1f0444ffc31fe83d2bcd7cfa021f2713a44df8` - maintainer profiles, one-owner coordination, graph leases, and runtime status |
| Section 4.3 | `edb82a182728ce9c02ec412e2dbc5e9dfdba7c81` - authenticated triggers, bounded scheduling, coalescing, and automatic deterministic updates |
| Section 4.4 | `043bcb61d06495bd81e02335a911881ea37822e2` - disabled synthesis invocation and accounting reconciliation |
| Section 4.5 | `67c70a74a44906b2cc1d94454c72d3da4211594a` - authoritative cancellation, scheduler fencing, and graph-derived recovery |
| Section 4.6 | Merge-pending candidate commit containing this receipt |
| Merged candidate | Pending implementation pull request, clean-checkout CI, and merge |

The shared-main baseline intentionally includes independent parallel-session
work merged after RW3. RW3 remains the repository-wiki authorization
prerequisite, and no runtime queue, mailbox, timer, process identity, or
workspace state is used as durable wiki truth.

## Governing Document Pins

| Contract | Candidate SHA-256 |
| --- | --- |
| ADR 0005 | `f337c4d6906f503c599bd8918d94d3356e9e5b81cc4125e93913687fb9f1a92e` |
| ADR 0006 | `c5ad6007b433214ba2a6a9119ef278f91d540d78408d070071e7591634cd28f1` |
| ADR 0007 | `c1b28b110b8e3bd586fd2365bb4d58c145c340973ea6d0f3c4739a3a5f2570e4` |
| Research deep dive | `91932a84774da9ef916c44895ee70a81cfb78b7b13dc7dd9dd5c319a43d0088f` |
| Governance baseline | `e7de65ac5eb50fd40bedb741e2919154df9997030357a4a2b3e146fc37a48475` |
| Graph and edition contract | `69d18609ae321b9583e76053110814850804df8c10ea758d60c7b4f0693c584b` |
| Compilation and update protocol | `91a455537a50fe894f8c84ccffbb8f96143b484847e4f390d2c828cfafc78f0d` |
| Enrollment, budget, and accounting | `796d9f913db481f9173aa0d5b5c7c0983a8421cfef58eb1638e01aabf29ca4fa` |
| Mix project and dependency catalog | `b309e869709e8fdc5b480002f7a8ff5ecb922eb038e4d15e979582a56281736d` |
| Maintainer runtime | `afa75952bf645ea0533df2d203aa053c24a6c0af83985587d31912a2bc348561` |
| Product and qualification | `473ec19f0670c07da516f487e0ec3270f5c413138321f8c432609382f029bcef` |

## Runtime, Budget, Accounting, And Fixture Pins

| Contract | Revision and candidate source SHA-256 |
| --- | --- |
| Generation catalog | `wiki-generation-catalog/1.0.0`; deterministic selectable keys only; source `e73222484dd1c0fc787c675352c7ba2d44ad6e7f51338183d8c2d614b1b3310e` |
| Price profile | immutable integer microunit pricing with checked ceiling arithmetic; source `aad0b6c9d84463c552b14b4e65803ef4f377d140228fdce031d3f8faf5840df4` |
| Budget | repository, tenant, actor, profile, period, currency, and seven finite dimensions; source `2f9d995be9f119e04f8f7a9f5b5ae990bedbec29bd0266d8afd76b153a19b006` |
| Reservation | exact attempt, invocation, source, enrollment, profile, provider/model, price, prompt, expiry, and idempotency identity; source `2153f1c436f2d41e2a9115a27b6331a43b00af6464ea4b07a3c14c382eecbd51` |
| Usage and cost | terminal deterministic/measured states with reserved, measured, charged, refunded, and unknown cost; source `a9f9cb66fb059b08cd05c31273be9102977e1c5ab49f7fcb083ae271c52d4f86` |
| Maintainer profile | `wiki-maintainer/1.0.0`; one current repository transition, four previews, 64 pending, three retries, 30s lease, 10s heartbeat; source `b104627edbbc12f8acb8b677f48878ce935974db1618d1de3cf9a698b846a93e` |
| Maintainer lease | monotonic generation plus profile, enrollment, cancellation, holder, heartbeat, expiry, and fencing token; source `bec6f9ced76a7a98b3d30a7e028f51e5f3db9dde87639e9077a17c329beb35c4` |
| Scheduler and automatic update | bounded fleet source `d88b7802e5a3ef3ec47e457fe368d5a13149c1f0d9911b6fbef6485e032d9032`; exact zero-token pipeline source `cd62dbb51d3ee223649625f81957ce05051914a9e0c07652910737f0d332d937` |
| Synthesis request and boundary | closed request source `084ec765fbf10d73779d742b532d7f97c3c9ccb3757afeadd7bea548e99f678d`; empty-production-catalog boundary source `868bc8858809fa38bf3da87c06746917f652c770dca391f0bf93ab97a623cb63` |
| Accounting reconciliation | exact late-use identity, retained unknown liability, bounded alerts and rollups; source `82db53834e63b305c3de8fb1e28a44ac4598f9c32659b67346bee6fcc8ca3eed` |
| Cancellation and shutdown | cancellation plan source `5d95bfbf1612139fddbc6ec312bcd7a1e8f9ca6fd5e6eeedb122c56100723399`; commit-before-signal source `d16683a3f2dccbdebd2b48551dddced445e4e0e73c3d5be81b68d564776d8417` |
| Recovery | graph plan source `cb53755e2ce7e781ce29461d8dd104f80c25910554d8b140524a0ef4199d54a7`; bounded parallel startup coordinator source `208cac2cf64414645bab0af0f75d2beb55dfbf872c56f31bf07f09323fa3aa19` |
| Semantic command and reviewed-query revision | `2.11.0`; reviewed query aggregate digest `ca8f93e1afb5373be2ab48316f414f1e31c73989838b1156a3e077349054bd0c`; catalog source `0d7246c64429fd84906c4f8a580f04dc581f060efae3f11726d9ec4e4769ba5a`; query source `3216f60c1b9c62f231cc5c8a41254a945a4429321790418134bd872808931465` |
| Phase 4 integration fixture | source `89c03cbf23f160428917f4897ec6d5404a4503b1e816d086dc0d4c8a0669edf9` |

## Parallel Ownership And Automatic-Update Evidence

- Automatic enrollment starts one disposable maintainer under a canonical
  tenant/repository Registry key. Concurrent session starts serialize through
  the coordinator; one lease is committed and duplicate callers observe the
  existing owner. Different repositories retain independent workers and can
  run concurrently.
- Leases bind the exact profile digest, enrollment revision, cancellation
  generation, monotonic generation, holder, heartbeat, expiry, and fencing
  token. Takeover is admitted only after expiry, and old owners fail current
  fence checks.
- The scheduler stores at most 64 pending triggers and eight active
  repositories by default, enforces per-tenant capacity, coalesces the latest
  compatible source while retaining every causal IRI, and revalidates against
  graph/source state immediately before dispatch. Mailboxes, timers, and
  process queues remain disposable.
- Automatic updates use the accepted edition compiler, lint, renderer,
  review/accounting, and activation boundaries. A deterministic attempt is
  rejected if any token or model cost is nonzero, while attributable local
  work remains recorded.

## Reservation And Accounting Evidence

- Every future token-bearing invocation requires an atomic worst-case
  reservation against committed usage plus live reservations. Checked integer
  arithmetic, explicit ceiling, price effective intervals, exact currency,
  revision/fence guards, and idempotent duplicate handling prevent silent
  overflow or concurrent overspend.
- Terminal accounting distinguishes rejected/failed before effect,
  failed-after-effect, success, cancellation, timeout, usage pending, and usage
  unknown. Effect-free work releases liability; consumed or unknown work
  retains it. Duplicate or late observations cannot double charge or erase a
  prior liability.
- Deterministic manual and automatic paths always record zero input, output,
  cached, and reasoning tokens and zero reserved, measured, charged, refunded,
  and unknown model cost. Local duration and input-byte observations remain
  attributable.
- Reviewed runtime queries expose bounded pending accounting, exact cost
  records, maintainer state, and graph-derived recovery status. Repository,
  tenant, actor, profile, trigger, edition, period, token class, and currency
  rollups are disposable projections rather than a second accounting store.

## Disabled Synthesis Evidence

- Production exposes no hosted adapter and no enabled provider/model price
  profile. Production invocation returns `unavailable` before invocation
  commit, adapter call, network activity, or token-bearing effect.
- The controller-owned request shape fixes source facts, retrieval context,
  prompt digest, output schema, token ceilings, reservation/invocation
  identity, source fence, and redaction. Callers cannot choose an endpoint,
  credential, module, prompt, tokenizer, price, tool, or fallback.
- Fake adapters exercise missing synthesis opt-in, disabled profile, missing
  price, stale reservation, provider failure, malformed output, usage drift,
  and late response. Invocation commits before adapter dispatch; every
  observation remains activation-ineligible until deterministic lint,
  provenance checks, review, and current-source qualification complete.

## Opt-Out And Recovery Evidence

- Shutdown validates an exact Off enrollment successor and cancellation
  generation, commits that semantic transition first, and only then stops
  admission, terminally cancels pending triggers, requests active-effect
  cancellation, revokes leases, reconciles accounting, applies retention, and
  stops the owner. A failed or stale commit sends no process signal.
- Scheduler disable removes pending/active work, writes bounded terminal
  cancellation evidence, rejects late completion, and admits re-enrollment
  only at a strictly newer enrollment revision. Old enrollment, lease,
  reservation, attempt, preview, callback, activation, recovery, and source
  results fail the exact current-result predicate.
- Unconsumed reservations release; invoked, consumed, usage-pending, and
  usage-unknown liabilities remain. Deterministic cancellation records zero
  model usage. Accounting/audit evidence is always preserved, while retained
  readability and product navigation are governed independently from future
  generation.
- Startup recovery scans bounded automatic enrollments in parallel across
  repositories, acquires only absent/expired leases, derives necessity from
  current source, edition, staleness, terminal attempts, triggers, and
  activation evidence, and recovers each resource only under its original
  fence. Missing store, harness, artifact, profile, accounting, or worker
  readiness yields explicit degraded status and no recovery effect.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| RW4 profile, budget, reservation, usage, maintainer, scheduler, synthesis, reconciliation, cancellation, recovery, and integration suites | Passed locally; repository-wiki suite 122 tests, 0 failures before final precommit |
| Parallel-session and failure matrix | Passed; same-repository owner races, unrelated repository concurrency, trigger coalescing/supersession, checked budget limits, zero-token enforcement, fake synthesis failures, disable/late-result races, and degraded recovery |
| RW1-RW3 regression coverage | Passed through the complete repository-wiki suite, including real writer lifecycle, graph recovery, deterministic dependency/guide/product compilation, preview isolation, qualification, and activation races |
| Architecture checks | Passed; zero findings |
| Compile with warnings as errors | Passed |
| Dialyzer | Passed; 178 existing warnings skipped by policy, zero unignored errors, and zero unused filters |
| Repository-wide `mix precommit` | Passed; 1,126 tests, 0 failures in 591.1 seconds; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | Pending implementation pull request |

Before the clean full result, one run completed with a pre-existing
command-pipeline temporary-directory teardown collision; that exact test
passed immediately in isolation. A second run aborted in the native storage
allocator before ExUnit reported an assertion result. The final full run above
completed cleanly. Exact-head clean-checkout CI remains required and is not
weakened by the local reruns.

## Known Limits And Disabled Posture

- Hosted synthesis remains structurally disabled. Fake test adapters prove the
  boundary contract but are not evidence that a production provider, model,
  price, tokenizer, credential, region, or billing observation is ready.
- Automatic V1 maintenance is deterministic-only. It updates compiled wiki
  projections but has no authority to mutate repository source, authored
  guides, ADRs, specifications, branches, pull requests, approvals, or merges.
- Scheduler and worker state is disposable. Production persistence adapters
  must execute the semantic commands and reviewed graph queries pinned here;
  local queue state is never recovery truth.
- This receipt remains merge-pending until exact-head clean-checkout CI, merge,
  full merge SHA, merge date, and closure checklist pins are recorded.

## Gate RW4

Status: **merge-pending**

RW4 remains open. Phase 5 is unauthorized until the implementation candidate
passes exact-head clean-checkout CI, merges, and this receipt is accepted at
the exact merged candidate in the required closure pull request.

RW4 reopens regardless of checklist state if an unconfigured, Off, Manual, or
ineligible repository starts an automatic maintainer; more than one current
owner or current-source transition exists for one repository; unrelated
repositories cannot make bounded parallel progress; any mailbox, timer,
cursor, cache, process, or workspace becomes durable truth; triggers,
reservations, retries, previews, or recovery work become unbounded; concurrent
attempts can overspend a budget; price, token, currency, rounding, overflow,
reservation, invocation, usage, refund, unknown liability, rollup, or alert
evidence becomes incomplete, mutable, cross-scope, double counted, or erasable;
any deterministic path records a model call, nonzero model token, or model
cost; production enables a hosted synthesis profile, price, adapter, endpoint,
credential, or fallback without a new accepted gate; synthesis reaches an
invocation or network/token effect without separate repository opt-in, an
enabled closed profile and price, worker readiness, exact source/policy fences,
and a current sufficient reservation; caller data selects executable behavior
or privileged request fields; invocation is not committed before effect;
malformed or drifted output can qualify or activate; disable signals any
process before the new semantic fence commits, admits later work, loses
incurred accounting/audit evidence, revives retained artifacts as current, or
accepts any old enrollment, lease, reservation, attempt, preview, callback,
activation, recovery, or source result; re-enrollment does not create a newer
generation; recovery trusts process state, acquires a live lease, resumes under
a drifted original fence, or hides a degraded dependency; any RW1, RW2, or RW3
invariant reopens; any governing ADR or specification digest changes without
reevaluation; or ontology verification, architecture checks, Dialyzer,
precommit, or clean-checkout CI fails at the exact merged Phase 4 candidate.
