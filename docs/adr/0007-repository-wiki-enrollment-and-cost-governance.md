# ADR 0007: Repository Wiki Enrollment And Cost Governance

- Status: Accepted
- Date: 2026-08-26
- Owners: JidoCode product, Factory, runtime, and billing maintainers
- Decision scope: Wiki opt-out, generation modes, token accounting, monetary
  attribution, and budget enforcement
- Depends on:
  [ADR 0005](./0005-repository-wikis-as-compiled-knowledge-projections.md) and
  [ADR 0006](./0006-per-repository-wiki-maintainer-agents.md)
- Research:
  [Repository wikis as compiled knowledge projections](../research/11-repository-wikis-as-compiled-knowledge-projections.md)
- Specification:
  [Repository wiki enrollment, budget, and accounting](../architecture/repository-wiki-enrollment-budget-and-accounting.md)

## Context

Repository wiki compilation can consume source-analysis, sandbox, metadata,
storage, and model resources. Synthesized explanations additionally consume
provider tokens and can create direct monetary cost. Automatic maintenance
multiplies this exposure across repositories, source changes, releases, and
parallel coding-session previews.

No repository owner should incur wiki-generation cost merely because the
repository is enrolled in the coding factory. A single “wiki enabled” flag is
also insufficient: some owners may want deterministic project, dependency,
and authored-guide pages without any model use; some may want only explicit
manual refreshes; and others may accept automatic synthesis within a budget.

Existing runtime budgets mention tokens and cost but do not by themselves
define enrollment consent, pricing identity, aggregate reservation under
parallel sessions, provider usage provenance, edition-level attribution, or
what happens when usage cannot be measured.

## Decision

Wiki creation and maintenance are explicitly configured per repository. The
absence of a current authorized configuration is equivalent to `disabled`.
Repository enrollment does not automatically create a wiki, invoke a model,
or incur wiki-generation token cost.

JidoCode will introduce immutable `WikiGenerationProfile` and
`WikiPricingProfile` resources in the Factory catalog. Repository control
selects an exact generation profile revision through a governed transition.
Prompts, repository files, coding agents, maintainers, environment variables,
and browser-supplied fields cannot select or expand that profile.

### Independent Configuration Dimensions

The generation profile separates:

1. `maintenanceMode`:
   - `disabled` — no current, release, recovery, or preview compilation starts;
   - `manual` — compilation starts only from an authorized explicit request;
   - `automatic` — graph reconciliation may schedule admitted work.
2. `generationMode`:
   - `deterministic_only` — model synthesis is prohibited and model token use
     must remain zero;
   - `synthesis_allowed` — exact page/risk classes may use the selected model
     profile within budgets.
3. `previewMode`:
   - `disabled` — coding sessions cannot request candidate wiki previews;
   - `allowed` — separately authorized session/candidate previews may run
     within their own and aggregate budgets.
4. existing-edition presentation and retention posture, which is independent
   of permission to create new editions.

`maintenanceMode=disabled` dominates every other field. It prevents new work,
requests cancellation of in-flight work before further external effects, and
rejects late results through current fences. Costs already incurred by an
effect remain recorded. Disabling generation does not silently delete or
conceal prior editions; read visibility and retention change only through
their separate governed policies.

`deterministic_only` is a first-class useful mode, not a degraded synthesis
failure. Its project overview, complete Mix dependency catalog, authored guide
navigation, deterministic source pages, citations, gaps, and live panels may
compile without any model call. It may still consume compute, storage,
sandbox, and metadata-provider resources; the product must not label it
“free” unless all relevant cost classes are known to be free.

### Consent And Safe Defaults

On upgrade and for a newly enrolled repository, automatic wiki generation is
off until an authorized actor selects a profile. Enabling synthesis requires
an explicit product confirmation showing the generation mode, maintenance
mode, preview posture, selected model/provider, pricing observation,
per-edition maximum, aggregate budget windows, and which usage dimensions may
be estimated or unavailable.

A product or deployment may offer a deterministic-only recommended profile,
but it cannot silently select it or synthesis on behalf of a repository. There
is no fallback from disabled or deterministic-only to synthesis, from manual
to automatic, or from an unavailable exact model/pricing profile to another
provider.

### Usage And Cost Accounting

Every model invocation used for wiki generation is attributable to exactly
one repository, compilation request, maintenance attempt, edition purpose,
page/section set, and, for previews, coding session/attempt and candidate.

The graph records an immutable bounded usage observation containing:

- invocation, reservation, result, repository, attempt, edition, profile,
  provider, model, and pricing-profile identities;
- input, cached-input, output, reasoning, and total token counts where the
  provider exposes them;
- source and confidence for each usage value: provider-reported, gateway-
  measured, tokenizer-estimated, unavailable, or contradicted;
- integer monetary amounts in the pricing profile's currency and smallest
  declared accounting unit, never floating-point values;
- estimated maximum, final calculated charge, pricing revision and effective
  time, observation time, and reconciliation state;
- cancellation, timeout, retry, cache, partial-result, and ambiguity posture;
  and
- explicit unavailable or disputed dimensions.

Raw prompts, source bodies, generated prose, hidden reasoning, credentials,
provider session IDs, and reusable billing material are not cost records.

The gateway records invocation before effect and terminal or ambiguous usage
afterward. Provider-reported counts are retained as observations, not assumed
complete. JidoCode never fabricates exact tokens or monetary cost when a
provider omits required data.

### Budget Reservation And Enforcement

Before every model call, an atomic semantic reservation checks and reserves
the call's worst-case admitted token and monetary exposure against all
applicable ceilings:

- invocation;
- page/section batch;
- maintenance attempt;
- edition;
- candidate preview/session;
- repository rolling/day/month windows;
- tenant rolling/day/month windows; and
- fleet/provider/model windows.

Parallel repository sessions share the repository and tenant aggregates.
Opening additional sessions never creates additional budget. Reservation
identity, expected revisions, lease, and fence prevent races and double spend.
Unused reservation is released only after an attributable usage result. When
usage remains ambiguous or unavailable, the full reserved maximum remains
charged against the budget until governed reconciliation.

Budget exhaustion stops additional synthesis before the next effect. Policy
may close a deterministic edition with explicit synthesis gaps, keep the
edition incomplete, or await a future budget window. It cannot exceed a hard
ceiling, borrow silently from another repository, switch providers, hide the
gap, or use an untracked model invocation.

### Edition And Fleet Rollups

Reviewed queries calculate bounded rollups from immutable invocation records;
a mutable counter, telemetry backend, invoice, local runtime accumulator, or
provider dashboard is not authoritative. Rollups distinguish current-source,
release, recovery, and session-preview costs and group by exact profile,
provider/model, repository, tenant, time window, and outcome.

Every closed edition reports deterministic/model invocation counts, input,
cached-input, output, reasoning, and total tokens, calculated cost, reserved-
but-unreconciled exposure, and unavailable/contradicted dimensions. An edition
with no model effects explicitly reports zero model calls and zero model
tokens; absence of usage records is not used as proof of zero.

Provider invoice reconciliation may add a separately observed adjustment. It
does not rewrite original usage observations or page provenance.

## Consequences

### Positive

- repository owners can opt out completely without losing access to the rest
  of the coding factory;
- deterministic-only wikis provide useful documentation with a provable zero
  model-token posture;
- synthesis cost is consented, bounded, attributable, and visible per edition
  and repository;
- parallel sessions cannot multiply or race past repository budgets;
- disabling generation is fast and does not require deleting historical wiki
  state; and
- pricing and usage uncertainty remains explicit rather than producing false
  cost precision.

### Costs And Constraints

- catalog, control, command, query, budget-reservation, projection, and audit
  contracts require additive versions;
- exact pricing profiles need maintenance as provider/model rates change;
- provider token dimensions differ and cannot always be normalized perfectly;
- worst-case reservation can temporarily reduce concurrency;
- cost reconciliation and rolling windows add graph/query and operator work;
  and
- deterministic-only compilation may still have infrastructure cost even
  though its model-token cost is zero.

## Alternatives Rejected

- **Automatically enable wikis for every enrolled repository:** this creates
  unconsented compute and model cost.
- **Use one boolean:** it cannot distinguish manual, automatic,
  deterministic-only, synthesis, preview, presentation, and retention needs.
- **Track only total provider spend:** this cannot attribute cost to a
  repository, edition, page, session preview, retry, or profile.
- **Trust telemetry or the provider dashboard as durable accounting:** neither
  is the graph-owned semantic record or sufficient for recovery and audit.
- **Estimate all missing tokens as exact:** this creates false precision and
  can under-enforce budgets.
- **Check budgets after generation:** parallel calls can overspend before
  results arrive.
- **Give every session its own repository budget:** session fan-out would
  multiply the owner's authorized exposure.
- **Delete the wiki on opt-out:** stopping future cost and erasing existing
  content are separate decisions with different authority and recovery needs.

## Compatibility And Rollback

Repositories without a selected generation profile remain valid and disabled.
Existing closed editions retain their identity and authorized read posture.
Startup refuses automatic maintenance when the selected generation, pricing,
budget, query, or accounting revision is unsupported.

Rollback selects an earlier still-authorized profile revision only through a
governed control transition. It cannot resume an expired price, enlarge a
budget, reinterpret prior cost, or reactivate model synthesis implicitly.

## Acceptance Conditions

This ADR may move to `Accepted` only when:

1. repository enrollment alone produces no wiki compilation, model call, or
   wiki token cost;
2. disabled, manual, and automatic maintenance plus deterministic-only,
   synthesis-allowed, preview-disabled, and preview-allowed modes fail closed
   with no fallback;
3. deterministic-only conformance proves zero model invocations and zero model
   tokens while retaining explicit non-model resource posture;
4. every synthesis invocation has invocation-before-effect, reservation,
   usage provenance, pricing identity, repository/edition attribution, and a
   terminal or ambiguous accounting outcome;
5. hard invocation, attempt, edition, preview/session, repository, tenant, and
   fleet budgets cannot be overspent under parallel races, retries,
   cancellation, restart, or late results;
6. unknown, missing, contradicted, and invoice-adjusted usage remains explicit
   and never appears as fabricated exact cost;
7. product confirmation and reporting expose predicted maximum, actual,
   reserved, reconciled, and unavailable usage without leaking content or
   hidden repository/session identities;
8. opt-out stops new effects promptly, rejects late effects, retains incurred
   accounting, and leaves edition presentation/retention to separate policy;
9. multi-repository and parallel same-repository-session tests prove budget
   aggregation, fairness, attribution, authorization, and zero cost leakage;
   and
10. the implementation pull request passes clean-checkout CI, merges, and its
    full merge commit is pinned in an accepted receipt without weakening any
    prior gate reopening condition.

Until these conditions pass, wiki synthesis and automatic maintenance remain
disabled in production.
