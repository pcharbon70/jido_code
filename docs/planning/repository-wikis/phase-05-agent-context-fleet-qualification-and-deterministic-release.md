---
id: plan.jido_code_repository_wikis_phase_05
parent_plan: plan.jido_code_repository_wikis
status: approved
intent: feature
---

# Repository Wikis Phase 5 - Agent Context, Fleet Qualification, And Deterministic Release

This phase integrates accepted wiki knowledge into bounded agent context,
qualifies parallel multi-repository operation, completes operations and cost
reporting, and releases the deterministic `jido_code` pilot. Model-backed wiki
synthesis remains unavailable after release.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Qualify and release deterministic repository wikis across the coding factory.

  This phase proves RW5 by showing reviewed wiki knowledge improves product and
  agent workflows without becoming authority, leaking across sessions, or
  weakening fleet safety, recovery, cost, and opt-out guarantees.

  - [x] 5.1 Section - Add reviewed wiki knowledge to bounded agent context.

    This section makes current wiki pages available as attributable context
    candidates while preserving the existing context assembler's authority and
    budgets.

    - [x] 5.1.1 Task {#rwi-p05-context-source} [repo: jido_code] [after: {#rwi-p04-phase-receipt}] - Implement the repository-wiki context source.

      This task exposes only current, authorized, source-fenced page fragments
      through the existing reviewed knowledge/context interfaces.

      - [x] 5.1.1.1 Subtask - Register a closed wiki context-source profile with eligible page kinds, freshness requirements, confidence threshold, fragment limits, byte/token estimates, ranking features, and source labels.
      - [x] 5.1.1.2 Subtask - Query current-edition Overview, Architecture, Project, Dependencies, Guides, Source, and Known Gaps fragments by exact actor, tenant, repository, task, source revision, and enrollment visibility.
      - [x] 5.1.1.3 Subtask - Attach edition, page, source, compiler, freshness, confidence, dependency, guide, and known-gap provenance to every candidate fragment.
      - [x] 5.1.1.4 Subtask - Reject previews, superseded/invalid editions, stale opaque references, hidden reads, cross-repository content, unsupported page classes, and fragments over profile bounds.
      - [x] 5.1.1.5 Subtask - Keep wiki candidates advisory: they cannot create graph facts, policies, commands, credentials, runtime selections, checks, publication decisions, or merge authority.

    - [x] 5.1.2 Task {#rwi-p05-context-assembly} [repo: jido_code] [after: {#rwi-p05-context-source}] - Integrate wiki candidates into deterministic context assembly.

      This task combines wiki and existing memory/source candidates under one
      budget, deduplication, ranking, and provenance policy.

      - [x] 5.1.2.1 Subtask - Deduplicate wiki fragments against accepted source, architecture, memory, and task facts by source/digest relationships rather than display text alone.
      - [x] 5.1.2.2 Subtask - Rank current repository-specific wiki candidates below direct accepted task/source constraints and above only profile-approved lower-confidence summaries.
      - [x] 5.1.2.3 Subtask - Allocate bounded context bytes/tokens by page class, preserve known gaps and contradictory source evidence, and emit deterministic omission reasons.
      - [x] 5.1.2.4 Subtask - Record selected wiki edition/page/source identities in compiled-context provenance while keeping full page bodies out of launch metadata and diagnostics.
      - [x] 5.1.2.5 Subtask - Invalidate assembled context when current edition, source fence, enrollment visibility, task authorization, compiler profile, or context-source profile changes.

    - [x] 5.1.3 Task {#rwi-p05-session-isolation} [repo: jido_code] [after: {#rwi-p05-context-assembly}] - Prove context isolation across parallel coding sessions.

      This task ensures session-specific previews and concurrent repository
      updates never contaminate another agent's compiled context.

      - [x] 5.1.3.1 Subtask - Bind context queries to the managed-coding attempt's exact repository, accepted source snapshot, actor, tenant, session, task, and current wiki edition.
      - [x] 5.1.3.2 Subtask - Prevent session preview content from entering ordinary current-edition context; introduce no preview-context mode in V1.
      - [x] 5.1.3.3 Subtask - Race context assembly with wiki activation, disable, source drift, repository deletion/archive policy, and session cancellation; return stale/retry rather than mixed editions.
      - [x] 5.1.3.4 Subtask - Prove caches, search indexes, fragment identifiers, logs, and telemetry cannot disclose another actor, tenant, repository, session, or preview.

  - [x] 5.2 Section - Complete fleet operations, observability, and cost reporting.

    This section gives operators bounded evidence for wiki freshness, failures,
    resource usage, reservations, and costs without exposing repository content
    or credentials.

    - [x] 5.2.1 Task {#rwi-p05-cost-product} [repo: jido_code] [after: {#rwi-p05-session-isolation}] - Add repository wiki usage, budget, and cost views.

      This task makes the cost of documentation generation visible even when
      the deterministic result is exactly zero model tokens.

      - [x] 5.2.1.1 Subtask - Display repository and period totals for attempts, deterministic local work, input/output/cached/reasoning tokens, reserved liability, measured cost, unknown liability, and currency.
      - [x] 5.2.1.2 Subtask - Break down usage by trigger, manual/automatic mode, generation profile, edition, actor, status, and source revision through reviewed bounded projections.
      - [x] 5.2.1.3 Subtask - Show budget limit, remaining amount, live reservations, expiration, profile availability, and why synthesis is unavailable in V1 without exposing provider credentials or internal prompts.
      - [x] 5.2.1.4 Subtask - Export audit-safe machine-readable evidence through an existing authorized operations surface only if one exists; add no new public API solely for V1 wiki release.
      - [x] 5.2.1.5 Subtask - Add accessibility, empty, partial, usage-pending, usage-unknown, multicurrency, and zero-token display tests using stable DOM identifiers.

    - [x] 5.2.2 Task {#rwi-p05-operations} [repo: jido_code] [after: {#rwi-p05-cost-product}] - Add fleet health, alerts, runbooks, backup, and disaster-recovery evidence.

      This task makes multi-repository wiki maintenance operable without
      treating ephemeral process state as the source of truth.

      - [x] 5.2.2.1 Subtask - Publish reviewed fleet summaries for enrollment states, current/stale ages, maintainer/lease health, queue pressure, compilation outcomes, coverage, reservations, usage terminality, and storage retention.
      - [x] 5.2.2.2 Subtask - Add alerts for stale current editions, repeated deterministic failure, abandoned editions, expired leases, stuck reservations, usage-pending/unknown, restore drift, and cross-scope invariant violations.
      - [x] 5.2.2.3 Subtask - Write runbooks for enrollment, manual regeneration, automatic maintenance, stale recovery, disable/teardown, reservation reconciliation, graph repair, backup/restore, and V1 synthesis-unavailable incidents.
      - [x] 5.2.2.4 Subtask - Execute backup and restore across multiple repository wiki graphs, rebuild disposable projections, restart eligible maintainers, and verify current/source/accounting fences.
      - [x] 5.2.2.5 Subtask - Bound telemetry labels and redact paths, source bodies, prompts, credentials, provider payloads, private dependency endpoints, and high-cardinality repository-controlled values.

  - [x] 5.3 Section - Qualify security, determinism, usefulness, and fleet isolation.

    This section evaluates the complete system against a signed corpus rather
    than treating happy-path rendering as release evidence.

    - [x] 5.3.1 Task {#rwi-p05-qualification-corpus} [repo: jido_code] [after: {#rwi-p05-operations}] - Build the signed repository-wiki qualification corpus and evaluator.

      This task covers representative and adversarial repositories, changes,
      documentation, dependencies, sessions, budgets, and recovery events.

      - [x] 5.3.1.1 Subtask - Create immutable fixtures for simple, umbrella, dynamic Mix, complete/incomplete lock, Hex, git, path, private, optional, cyclic, malformed, oversized, Unicode, and hostile repositories.
      - [x] 5.3.1.2 Subtask - Create guide fixtures for user/developer/operator content, renames, broken links, raw HTML, scripts, unsafe schemes, secret-like values, huge documents, and anchor collisions.
      - [x] 5.3.1.3 Subtask - Create concurrency fixtures for many repositories, competing same-repository sessions, previews, source churn, activation races, maintainer takeover, opt-out, retries, and late results.
      - [x] 5.3.1.4 Subtask - Create accounting fixtures for zero-token attempts, reservations, exact/partial/missing usage, price changes, currency/rounding, duplicate callbacks, crash recovery, and unknown liability.
      - [x] 5.3.1.5 Subtask - Sign corpus, evaluator, expected graph/page/usage outputs, component profiles, clocks, and release thresholds with immutable digests.

    - [x] 5.3.2 Task {#rwi-p05-security-evaluation} [repo: jido_code] [after: {#rwi-p05-qualification-corpus}] - Execute the security and authority evaluation.

      This task attempts to turn repository, guide, dependency, remote, graph,
      preview, and process inputs into unauthorized authority or disclosure.

      - [x] 5.3.2.1 Subtask - Test path traversal, symlink escape, parser bombs, atom exhaustion, code execution, Mix hooks, credential access, network escape, endpoint injection, unsafe redirects, and content injection.
      - [x] 5.3.2.2 Subtask - Test graph IRI injection, raw query bypass, cross-tenant/repository joins, preview disclosure, cache collisions, stale opaque references, forged source fences, and multiple-current attempts.
      - [x] 5.3.2.3 Subtask - Test budget bypass, reservation races, profile/price substitution, usage suppression, duplicate charging, arithmetic overflow, late provider results, and disable-after-invocation behavior.
      - [x] 5.3.2.4 Subtask - Test wiki-to-agent prompt injection and authority confusion; prove retrieved text remains quoted, attributable context and cannot select commands, tools, policies, credentials, runtimes, or merges.
      - [x] 5.3.2.5 Subtask - Require zero critical/high findings, documented bounded residual risks, and signed evidence for every non-negotiable invariant before release admission.

    - [x] 5.3.3 Task {#rwi-p05-quality-evaluation} [repo: jido_code] [after: {#rwi-p05-security-evaluation}] - Execute deterministic completeness, usefulness, and regression evaluation.

      This task proves the wiki contains what the specifications promise and
      remains reproducible across clean machines and process restarts.

      - [x] 5.3.3.1 Subtask - Require exact supported dependency-node/edge coverage, required project fields or visible gaps, guide/source provenance, safe links, page reachability, and lint/render success.
      - [x] 5.3.3.2 Subtask - Compile the corpus repeatedly across clean checkouts, randomized input enumeration, restarts, and supported runtime environments; require identical canonical graph/page digests.
      - [x] 5.3.3.3 Subtask - Evaluate representative user and developer retrieval tasks for page discoverability, navigation, source tracing, dependency explanation, known-gap visibility, and bounded search quality.
      - [x] 5.3.3.4 Subtask - Prove current-edition reads and agent context never mix source revisions or previews under concurrent activation and source churn.
      - [x] 5.3.3.5 Subtask - Establish signed performance and resource ceilings for inventory, parsing, graph statements, rendering, search, maintainer concurrency, storage, and recovery.

  - [ ] 5.4 Section - Pilot `jido_code` and prepare deterministic V1 release.

    This section enrolls the first repository deliberately, validates its
    actual wiki, and publishes only the profiles proven by the qualification
    corpus.

    - [ ] 5.4.1 Task {#rwi-p05-pilot} [repo: jido_code] [after: {#rwi-p05-quality-evaluation}] - Run the `jido_code` deterministic repository-wiki pilot.

      This task compiles and reviews the factory's own knowledge as the first
      production-shaped repository edition.

      - [ ] 5.4.1.1 Subtask - Record explicit authorized enrollment for `jido_code`, initially manual deterministic, with retained reads, retention, zero synthesis permission, and current policy revisions.
      - [ ] 5.4.1.2 Subtask - Compile repository overview, source inventory, accepted ADR/spec/plan architecture, full Mix project identity, complete dependency catalog, and all configured user/developer/operator guides.
      - [ ] 5.4.1.3 Subtask - Review source provenance, dependency closure, links, guide safety, known gaps, freshness, zero-token usage, navigation, search, and context candidates against the actual repository revision.
      - [ ] 5.4.1.4 Subtask - Exercise a controlled source change and parallel preview race, then activate exactly one current edition through the source-fenced review transition.
      - [ ] 5.4.1.5 Subtask - Optionally transition the pilot to automatic deterministic maintenance only after manual evidence passes; verify disable returns it to process-free, cost-free operation.

    - [ ] 5.4.2 Task {#rwi-p05-release} [repo: jido_code] [after: {#rwi-p05-pilot}] - Publish the deterministic V1 profile catalog and rollout decision.

      This task releases only the closed component tuples proven by signed
      pilot and corpus evidence.

      - [ ] 5.4.2.1 Subtask - Pin ontology `1.5.0`, GraphRegistry `2.5.0`, semantic protocol `2.10.0`, wiki protocol `1.0.0`, and exact compiler/parser/sandbox/metadata/lint/renderer digests.
      - [ ] 5.4.2.2 Subtask - Enable manual and automatic deterministic profiles as policy-authorized offerings while preserving per-repository default Off and explicit enrollment.
      - [ ] 5.4.2.3 Subtask - Keep all hosted synthesis providers, models, prices, and production adapters disabled and document the evidence required for a separate future enablement decision.
      - [ ] 5.4.2.4 Subtask - Publish operator/user/developer documentation, limitations, supported repository envelope, cost semantics, privacy behavior, retention, opt-out, rollback, and gate reopening conditions.
      - [ ] 5.4.2.5 Subtask - Record rollback profiles that stop new work and maintainers without corrupting current editions, retained reads, usage, accounting, or audit history.

  - [ ] 5.5 Section - Phase 5 Integration Tests.

    This final section proves deterministic repository wikis are safe and
    useful across the coding factory and ready for controlled opt-in release.

    - [ ] 5.5.1 Task {#rwi-p05-integration} [repo: jido_code] [after: {#rwi-p05-release}] - Execute the RW5 context, fleet, pilot, and release matrix.

      This task closes RW5 only when signed evidence proves every prior gate,
      V1 has no token-bearing provider path, and the pilot is reproducible from
      its pinned source baseline.

      - [ ] 5.5.1.1 Subtask - Exercise wiki context selection, ranking, deduplication, budgets, provenance, staleness, activation races, opt-out, prompt injection, and cross-session/repository isolation.
      - [ ] 5.5.1.2 Subtask - Exercise cost product views, zero-token reporting, pending/unknown liability, fleet summaries, alerts, runbooks, telemetry redaction, backup, restore, and maintainer restart.
      - [ ] 5.5.1.3 Subtask - Run the signed security, completeness, determinism, usefulness, concurrency, performance, retention, recovery, and accounting corpus in a clean checkout.
      - [ ] 5.5.1.4 Subtask - Rebuild the `jido_code` pilot from its pinned source and profile digests, compare canonical outputs, and verify its complete dependencies and guide coverage.
      - [ ] 5.5.1.5 Subtask - Prove all repositories remain Off unless explicitly enrolled, disabled repositories create no work or model cost, and no hosted synthesis profile can be selected or invoked.
      - [ ] 5.5.1.6 Subtask - Rerun RW1-RW4 and applicable factory, harness, memory, managed-coding, delegated-agent, architecture, security, Dialyzer, `mix precommit`, and clean-checkout CI gates.

    - [ ] 5.5.2 Task {#rwi-p05-phase-receipt} [repo: jido_code] [after: {#rwi-p05-integration}] - Publish and pin the Phase 5 receipt.

      This task records RW5 evidence in
      `docs/architecture/repository-wiki-phase-05-receipt.md`.

      - [ ] 5.5.2.1 Subtask - Record context, product, operations, corpus, evaluator, security, quality, pilot, release, rollback, profile, and clean-checkout revisions and digests.
      - [ ] 5.5.2.2 Subtask - Keep RW5 open if wiki context gains authority, sessions or repositories leak, deterministic replay differs, required knowledge is missing, opt-out creates work/cost, or any hosted synthesis path is enabled.
      - [ ] 5.5.2.3 Subtask - Preserve every RW1-RW5 reopening condition and attach signed corpus, pilot, operations, recovery, cost, security, precommit, Dialyzer, and clean-checkout evidence.
      - [ ] 5.5.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, final Phase 5 Integration Tests section, receipt task, and pinning checkboxes before declaring the repository-wikis plan complete.
