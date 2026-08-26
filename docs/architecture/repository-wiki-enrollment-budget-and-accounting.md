# Repository Wiki Enrollment, Budget, And Accounting Specification

- Status: Approved and normative under accepted ADR 0007
- Specification version: `0.1.0`
- Owners: JidoCode product, Factory, runtime, knowledge, and billing maintainers
- Decision: [ADR 0007](../adr/0007-repository-wiki-enrollment-and-cost-governance.md)
- Wiki contracts:
  [graph and edition](./repository-wiki-graph-and-edition-contract.md),
  [compilation and update](./repository-wiki-compilation-and-update-protocol.md),
  and [maintainer runtime](./repository-wiki-maintainer-runtime.md)

## Purpose And Boundary

This specification defines repository-level wiki enrollment, opt-out,
generation modes, usage metering, monetary attribution, budget reservation,
parallel-session aggregation, product consent, reporting, and reconciliation.

It governs wiki-generation cost. It does not replace provider invoices,
general infrastructure accounting, model-access governance, or the accepted
execution/evidence boundaries. Token accounting proves what JidoCode observed
or estimated under an exact profile; it is not a claim about hidden provider
computation.

## Safety Invariants

1. Repository enrollment never implies wiki enrollment.
2. Missing, disabled, expired, incompatible, unauthorized, or ambiguous wiki
   configuration permits no new compilation effect.
3. Model synthesis is independently opt-in and cannot be inferred from wiki
   presentation or an existing edition.
4. No model call starts without an admitted invocation and worst-case budget
   reservation.
5. Every model call ends with attributable terminal or ambiguous accounting.
6. Parallel sessions share repository/tenant/fleet ceilings and cannot mint
   new budget.
7. `deterministic_only` makes model calls structurally unavailable rather than
   relying on a prompt instruction.
8. Usage, pricing, cost, and uncertainty are immutable observations; rollups
   are reviewed projections.
9. Disabling creation and deleting or concealing existing editions are
   independent governed actions.
10. No accounting record contains prompts, source bodies, generated page
    bodies, credentials, or hidden reasoning.

## Resource Model And Placement

This specification does not require another named-graph family.

| Resource | Placement | Mutability and purpose |
| --- | --- | --- |
| `WikiGenerationProfile` | `factory_catalog` | Immutable/superseded generation, maintenance, preview, model, pricing, and budget envelope |
| `WikiPricingProfile` | `factory_catalog` | Immutable/superseded rates, currency, token dimensions, provider/model scope, and effective interval |
| `RepositoryWikiConfiguration` | `repository_control` | Append/supersede selection of one exact generation profile for one repository |
| `WikiBudgetAccount` | `repository_control` with exact catalog-policy link | Stable account identity and exact repository/tenant/fleet scopes |
| `WikiBudgetReservation` | `repository_control` | Immutable reservation, adjustment, release, expiry, and reconciliation lineage |
| `WikiModelUsageObservation` | exact wiki maintenance `run_attempt` graph before closure | Immutable invocation-level provider/gateway/estimated usage and cost observation |
| `WikiCostAdjustment` | `repository_control` | Immutable provider invoice or operator reconciliation without rewriting usage |

An implementation plan MUST allocate exact ontology, shape, graph-link,
retention, command, query, and startup-compatibility revisions. Ordinary wiki
edition commands cannot register profiles, select configuration, enlarge
budgets, alter pricing, or reconcile cost.

## Wiki Generation Profile

`WikiGenerationProfile` is immutable and signed. Material changes create a
successor. Required fields are:

| Field | Contract |
| --- | --- |
| identity/revision/digests | Deterministic identity, positive revision, full material digest, signer, and signature |
| owner and bindings | Exact tenant/repository/actor/capability scope; no repository wildcard in the initial profile |
| `maintenanceMode` | `disabled`, `manual`, or `automatic` |
| `generationMode` | `deterministic_only` or `synthesis_allowed` |
| `previewMode` | `disabled` or `allowed` |
| maintainer/compiler profiles | Exact compatible wiki maintainer, compiler, Mix, query, lint, and renderer revisions |
| synthesis scope | Closed page, section, risk, and edition-purpose classes; empty for deterministic-only |
| model access/profile | Exact identity when synthesis is allowed; forbidden otherwise |
| pricing profile | Exact current compatible identity when synthesis is allowed; forbidden otherwise |
| budget policy | Exact token/call/money ceilings and windows defined below |
| unknown-usage posture | `deny`, or `reserve_maximum_until_reconciled`; no `treat_as_zero` |
| existing-edition posture | `retain_readable`, `conceal`, or separately selected presentation policy identity |
| retention policy | Exact usage, reservation, adjustment, and edition retention classes |
| state/rollout/validity | Disabled/enabled/revoked/superseded, rollout stage, approval, effective and expiry times |

The closed compatibility rules require:

- `disabled` to prohibit every creation and preview capability regardless of
  other fields;
- `deterministic_only` to have no model, pricing, synthesis tool, prompt, or
  positive model-token budget identity;
- `synthesis_allowed` to pin compatible model access, pricing, token schema,
  budget, maintainer, and synthesis policy;
- `manual` to reject coordinator-discovered automatic work while permitting an
  explicitly authorized request;
- `previewMode=allowed` to remain subject to maintenance and generation modes,
  session authorization, and aggregate budgets; and
- every selected referenced resource to be present, enabled, signed, current,
  unexpired, and compatible at admission and before each model effect.

There is no best-match or fallback resolution.

## Repository Configuration Lifecycle

The repository-control lifecycle is:

```text
unconfigured/disabled -> manual_deterministic -> automatic_deterministic
          |                        |
          +-> manual_synthesis ----+-> automatic_synthesis
          ^                                      |
          +---------------- disable <------------+
```

The diagram represents combinations of independent fields, not new mutable
enum values. Every transition records accountable actor, authorization,
reason, expected dataset/control revisions, prior and successor profile,
effective time, idempotency, provenance, audit, and bounded receipt.

Repository enrollment creates no implicit configuration. Product onboarding
may present choices but selection requires explicit confirmation. A deployment
default cannot override a repository-level opt-out.

### Disable Order

When a repository transitions to disabled:

1. commit the configuration transition;
2. prevent new compilation and reservation admission;
3. request cancellation for current-source and preview attempts;
4. revoke outstanding model/effect permits and advance fences as required;
5. stop deterministic work before the next governed effect where possible;
6. adopt any already-returned usage/cost under the old invocation identity;
7. keep unresolved reservations charged until terminal reconciliation; and
8. apply the separately selected read/retention posture to existing editions.

The transition does not promise that an already dispatched provider request
incurs zero cost. It promises that every incurred or ambiguous exposure stays
visible and no further authorized effect begins.

## Budget Policy

Every synthesis-enabled profile defines finite positive ceilings. No
dimension is unlimited by omission.

### Dimensions

- provider calls;
- input tokens;
- cached-input tokens when separately reported;
- output tokens;
- reasoning tokens when separately reported;
- total provider-billed tokens under the pricing profile's formula;
- monetary exposure in an ISO 4217 currency and integer accounting unit;
- retries and ambiguous reservations;
- optional generated-section and page counts; and
- optional model wall time as a protective nonbilling limit.

If a provider combines dimensions, the pricing profile defines the exact
mapping without inventing unavailable sub-counts. Currency conversion is not
performed in the initial contract; profiles with different currencies are
reported separately.

### Scopes And Windows

Ceilings may apply simultaneously to:

- one invocation;
- one section/page batch;
- one compilation attempt;
- one edition;
- one session/candidate preview;
- one repository;
- one tenant; and
- fleet/provider/model capacity.

Repository, tenant, and fleet ceilings include calendar-day, calendar-month,
and/or rolling-window identities. Calendar windows pin timezone and boundary
rules in the policy; UTC is the initial recommended profile. A daylight-saving
or clock change cannot reinterpret a closed window.

A reservation is charged to the exact windows evaluated at its trusted
invocation time. Crossing a boundary while the provider call runs does not
move exposure into a fresh window or release the prior one. Retry after the
boundary is a new invocation evaluated against both remaining outstanding
exposure and its own current windows.

The effective ceiling is the strictest applicable remaining amount in every
dimension. An absent aggregate scope is allowed only when a higher-level
Factory policy supplies a finite ceiling and the signed compatibility rule
proves the join.

## Pricing Profile

`WikiPricingProfile` records:

- provider, exact model/model-class, access/billing mode, and region when
  material;
- currency and integer monetary unit, such as millionths of the currency unit;
- effective start/end and observation/source identity;
- per-token or per-token-block rates for admitted input, cached input, output,
  reasoning, and other provider-billed dimensions;
- minimum charge, rounding, tier, batch, cache, and discount behavior when
  supported;
- tax/credit/contract-discount inclusion posture;
- provider-reported usage field mapping and tokenizer estimator revision;
- maximum age and refresh policy;
- signer, approval, state, supersession, digest, and source citation; and
- explicit unsupported/unavailable dimensions.

Monetary calculation uses integer arithmetic with declared rounding. Float
storage or calculation is forbidden. A profile cannot claim invoice-final
cost when taxes, credits, tiers, or contract adjustments are excluded.

Pricing may be observed from an authorized provider source or entered through
a governed operator process. Repository text, model output, public search
results, and arbitrary URLs cannot change rates.

## Admission Estimate

Before enabling synthesis or approving a manual synthesis request, the product
shows a bounded estimate containing:

- exact repository and generation-profile presentation identity;
- maintenance, generation, and preview modes;
- provider/model and pricing observation/effective time;
- maximum calls and tokens by admitted dimension;
- maximum monetary exposure for the requested attempt/edition;
- remaining repository and tenant window budgets;
- whether counts or price components may be estimated, excluded, stale, or
  unavailable;
- deterministic-only alternative; and
- cancellation and already-dispatched-cost limitations.

This is a maximum admitted exposure, not a promise of actual spend or wiki
quality. Confirmation binds the exact profile/pricing/budget digests and
current revisions. A stale confirmation is rejected rather than silently
recalculated after submission.

## Reservation Protocol

Before a model invocation, the model gateway receives a controller-computed
maximum envelope. A semantic command equivalent to `ReserveWikiModelBudget`
atomically:

1. authorizes repository, tenant, actor/delegation, attempt, lease, fence,
   edition purpose, and session/candidate scope;
2. verifies selected generation/model/pricing profiles and current time;
3. loads committed usage plus outstanding reservations for every applicable
   scope/window;
4. proves the requested worst-case amount fits every dimension;
5. creates one immutable reservation with finite expiry and invocation
   identity; and
6. commits the model invocation-before-effect record.

Only then may the gateway call the model. Provider concurrency happens after
the serialized reservation, preventing parallel overspend.

A reservation has states observed through immutable transitions:

```text
reserved -> consumed
        |-> partially_consumed_and_released
        |-> released_without_effect
        |-> ambiguous_held -> reconciled
        |-> expired_held -> reconciled
```

Expiry does not free exposure if the effect may have occurred. Release
requires proof that no effect occurred or an attributable terminal usage
observation. Identical replay returns the existing reservation/receipt;
divergent reuse conflicts.

## Usage Observation

One `WikiModelUsageObservation` binds exactly one invocation and records:

| Group | Required values |
| --- | --- |
| Attribution | repository, tenant, configuration, request, attempt, edition/purpose, page/sections, session/candidate when preview, lease/fence |
| Runtime | provider, model, access profile, synthesis profile, pricing profile, gateway effect and result identity |
| Status | succeeded, partial, cancelled-before-effect, cancelled-after-effect, failed, timed-out, or ambiguous |
| Counts | input, cached input, output, reasoning, total/billed tokens as supported, plus source per dimension |
| Money | estimated maximum, calculated observed charge, currency/unit, rounding, excluded components, and confidence |
| Time | invocation, provider observation, result, adoption, and pricing-effective times |
| Reconciliation | reservation consumed/released/held amounts, discrepancy, adjustment lineage, and finality class |
| Privacy | content classification and explicit proof that no prompt/page/source body is stored |

Allowed usage sources are:

- `provider_reported`;
- `gateway_measured` under a pinned exact tokenizer/protocol;
- `tokenizer_estimated` under a pinned estimator;
- `unavailable`; and
- `contradicted` when sources disagree outside policy tolerance.

The observation retains separate values when sources disagree. A reviewed
policy selects which value is used for provisional budget charging; it never
rewrites the observations into false agreement.

Retries are distinct invocation/reservation/usage resources. Cache hits are
charged according to the exact provider pricing profile and are not assumed
free. Streaming fragments are not independently counted unless the provider
contract bills them separately.

## Edition Accounting

Before closure, a wiki edition's accounting manifest proves:

- deterministic pipeline invocation/resource posture;
- number of admitted, dispatched, successful, failed, cancelled, ambiguous,
  and cached model calls;
- tokens by dimension and source;
- calculated observed cost and estimated/excluded components;
- outstanding reserved maximum and reconciliation posture;
- usage grouped by page/section class without content;
- preview session/candidate attribution when applicable;
- exact generation, model, pricing, and budget profiles; and
- zero-model proof for deterministic-only editions.

Blocking accounting lint includes an unregistered model call, missing
invocation-before-effect, missing reservation, mismatched repository/session,
unattributed usage, pricing-profile mismatch, integer overflow, negative
amount, impossible token total, unauthorized budget scope, or falsely claimed
zero-model posture.

Policy may allow closure with outstanding ambiguous cost if it remains fully
reserved and prominently reported. Activation policy may be stricter.

## Parallel Session Accounting

Candidate previews have per-session sublimits but draw from the same
repository and tenant accounts. The reservation transaction evaluates all
levels at once. Consequently:

- two sessions racing for the last repository tokens admit at most the calls
  whose combined maximum fits;
- opening or restarting a session does not reset any aggregate window;
- rebases and successor candidates remain attributable to the same or an
  explicitly new session/candidate budget identity without losing repository
  rollup;
- session cancellation cannot release a sibling's reservation;
- preview cost cannot be attributed to current-source maintenance or another
  session; and
- current-source work may have a protected budget reserve/priority so preview
  fan-out cannot prevent required freshness, when the signed policy says so.

Budget query candidates are authorized before repository or session matching.
Aggregate product views cannot reveal another private session through counts
or reserved exposure.

## Non-Model Resource Accounting

The initial required exact accounting concerns model invocations, tokens, and
calculated provider cost. The same edition report also states whether these
non-model dimensions are measured, estimated, unpriced, or out of scope:

- deterministic CPU/memory/time;
- sandbox runtime;
- metadata-provider calls;
- graph storage and retained artifacts; and
- network/provider infrastructure.

`deterministic_only` means zero model calls/tokens, not necessarily zero total
operating cost. The product uses the phrase “zero model-token generation”
unless a broader cost profile proves a stronger claim.

## Reporting Projections

Reviewed queries MUST include bounded equivalents of:

- `RepositoryWikiConfigurationSummary`;
- `RepositoryWikiConfigurationHistory`;
- `WikiGenerationEstimate`;
- `WikiBudgetRemainingByScope`;
- `WikiEditionUsageAndCost`;
- `WikiRepositoryUsageByWindow`;
- `WikiTenantUsageByWindow`;
- `WikiPreviewUsageByAuthorizedSession`;
- `WikiOutstandingCostReservations`; and
- privileged `WikiUsageReconciliationDetail`.

Product projections distinguish:

- model calls and tokens actually observed;
- provider-reported versus measured/estimated/unavailable counts;
- calculated charge versus admitted maximum;
- consumed versus outstanding reserved exposure;
- current/release/recovery/preview purposes;
- deterministic-only zero-model proof;
- budget remaining and next window boundary; and
- price observation/finality limitations.

No ordinary projection exposes raw graph names, provider billing account,
credential reference, prompt/page/source content, hidden session identity,
provider request/session ID, invoice detail outside scope, or another
repository's spend.

## Semantic Commands

Implementation planning MUST introduce versioned semantic intents equivalent
to:

- `RegisterWikiPricingProfile`;
- `RegisterWikiGenerationProfile`;
- `ConfigureRepositoryWiki`;
- `DisableRepositoryWiki`;
- `ReserveWikiModelBudget`;
- `RecordWikiModelUsage`;
- `ReleaseWikiBudgetReservation`;
- `MarkWikiUsageAmbiguous`; and
- privileged `ReconcileWikiCostAdjustment`.

All commands carry exact registry/version, expected dataset/graph revisions,
principal, actor/delegation, tenant/repository/session scope as applicable,
idempotency, correlation/causation, trusted time, reason, ontology/shapes,
profile digests, authorization, validation, provenance, audit, and bounded
receipts. Browser/model/repository fields never choose command or graph names.

## Failure And Recovery

- Missing/incompatible configuration: no work is admitted.
- Missing/stale pricing: synthesis is denied; deterministic work may proceed
  only if the selected profile permits it independently.
- Budget exhausted: no next model call; emit explicit deterministic/synthesis
  gap or wait according to policy.
- Provider omits usage: mark unavailable and retain maximum reservation.
- Provider/gateway counts conflict: retain both, charge the conservative
  policy value, and require reconciliation when configured.
- Timeout or process loss after dispatch: hold reservation as ambiguous and
  reconcile by invocation identity before any retry.
- Store/writer unavailable: no reservation means no model dispatch; apply
  bounded backpressure/cancellation rather than a local queue.
- Configuration disabled during a call: reject new effects, accept attributable
  late usage for accounting only, and prevent page/activation mutation through
  the current fence.
- Restore: recompute reservation/usage/window rollups from immutable graph
  records and verify edition accounting manifests.

No recovery path trusts telemetry, ETS, a process counter, local file, model
session, provider dashboard, or reconstructed prompt as authoritative.

## Retention And Export

Usage and reservation provenance required to explain retained edition cost
follows at least the edition's accounting retention. Repository/tenant rollup
records and adjustments follow finance/audit policy. Erasure or retention
changes preserve legally/operationally required non-content accounting while
removing content-bearing references according to classification policy.

Authorized exports are bounded, content-free accounting data with exact
profile/pricing identity, currency/unit, time windows, token sources, and
uncertainty. CSV/JSON files are provider-owned exports or user downloads, not
the durable ledger.

## Product Requirements

The repository wiki settings surface provides:

- explicit `Off`, `Manual`, and `Automatic` maintenance choices;
- explicit `Deterministic only` and `Allow cited synthesis` generation
  choices;
- separate candidate-preview permission;
- current selected profile, approval, expiry, and limitations;
- predicted per-run maximum and remaining repository/tenant budgets before
  confirmation;
- actual and reserved usage by edition and current window;
- deterministic-only zero-model-token label;
- disable control explaining retained editions and in-flight cost; and
- cost/accounting unavailable, ambiguous, or stale states.

The settings form uses opaque profile references and server-owned values for
scope, command, revisions, pricing, budgets, and actor. The confirmation is
invalidated when any material digest or remaining budget changes.

## Conformance Requirements

Tests MUST prove:

1. repository enrollment and missing configuration cause zero wiki work and
   zero model calls;
2. all mode combinations, transitions, signature/expiry/revocation checks,
   and no-fallback behavior;
3. deterministic-only execution has structurally no model gateway capability
   and produces explicit zero model-call/token accounting;
4. exact integer pricing and rounding fixtures for every admitted provider
   token schema, cache behavior, minimum, tier, and unavailable dimension;
5. invocation-before-effect and reservation-before-dispatch under duplicate,
   replay, conflict, retry, timeout, cancellation, and restart;
6. atomic hard-budget enforcement under high parallel concurrency across
   sessions, repositories, tenants, providers, and windows;
7. missing, estimated, contradicted, ambiguous, adjusted, and reconciled usage
   never becomes fabricated exact cost or releases exposure unsafely;
8. edition/page/session/repository/tenant/fleet attribution and rollup equality
   after backup, restore, retention, and profile supersession;
9. opt-out prevents new effects, rejects late semantic output, retains incurred
   cost, and does not silently delete or expose editions; and
10. product, query, cache, telemetry, export, and adversarial tests show zero
    source/prompt/secret, cross-repository, cross-tenant, or cross-session cost
    disclosure.
