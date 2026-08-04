---
id: plan.jido_code_graph_factory_phase_10
intent: release_gate_change
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 10 - Product Surfaces, Fleet Operations, And Release Acceptance

This phase cuts the repository-defined product/workbench surface over to
bounded graph projections and semantic commands, hardens route/resource/action
authorization, validates multi-repository fleet behavior, implements retention
and operational runbooks, and proves clean-install plus disaster-recovery
acceptance without any second durable source of truth.

Back to plan: [README](./README.md)

- [ ] 10 Phase - Deliver and accept the graph-backed managed repository factory as an operable product.

  This phase integrates every prior seam through LiveView and LiveVue, then
  validates security, accessibility, observability, performance, retention,
  backup/restore, upgrade, rollback, and fleet-wide end-to-end behavior at one
  release candidate.

  - [x] 10.1 Section - Integrate graph-backed product and workbench surfaces.

    This section maps the route and workbench contract owned by this repository
    onto bounded projections and semantic commands without importing the older
    implementation's route surface or exposing graph internals to the browser.

    - [x] 10.1.1 Task {#jcf-p10-surface-contracts} [repo: jido_code] [after: {#jcf-p09-phase-receipt}] - Ratify product surface and projection ownership.

      This task defines which current routes/workbench areas present factory,
      repository, work, execution, evidence, decision, and knowledge concepts
      and which LiveView owns each semantic session.

      - [x] 10.1.1.1 Subtask {#jcf-p10-10-1-1-1} - Inventory the current repository route/workbench specification and map each implemented route to an owning LiveView, actor scope, resource authorization rule, and projection contract.
      - [x] 10.1.1.2 Subtask {#jcf-p10-10-1-1-2} - Define navigation and handoff identities using verified routes and canonical graph resource IRIs without copying paths from `mikehostetler/jido_code`.
      - [x] 10.1.1.3 Subtask {#jcf-p10-10-1-1-3} - Assign LiveView ownership for route/session/scope/current selection and LiveVue ownership only for bounded local interaction state.
      - [x] 10.1.1.4 Subtask {#jcf-p10-10-1-1-4} - Define loading, empty, stale, incomplete, contradicted, truncated, unauthorized, unavailable, maintenance, and recovery presentation states for every projection.
      - [x] 10.1.1.5 Subtask {#jcf-p10-10-1-1-5} - Keep arbitrary graph browsing/query authoring outside ordinary product routes unless separately accepted and read-only bounded.

    - [x] 10.1.2 Task {#jcf-p10-liveview-projections} [repo: jido_code] [after: {#jcf-p10-surface-contracts}] - Implement LiveView-owned factory projections and semantic actions.

      This task replaces demo runtime assigns with graph-derived state and
      routes every durable user action through the command boundary.

      - [x] 10.1.2.1 Subtask {#jcf-p10-10-1-2-1} - Mount actor-authorized projections for factory posture, repository enrollment/observation/source freshness, goals/work, attempts, evidence/decisions, and accepted knowledge according to current surface ownership.
      - [x] 10.1.2.2 Subtask {#jcf-p10-10-1-2-2} - Use LiveView streams for rendered collections and track count/empty/freshness metadata in separate assigns.
      - [x] 10.1.2.3 Subtask {#jcf-p10-10-1-2-3} - Implement graph-backed forms with `to_form/2`, `<.form>`, `<.input>`, unique DOM IDs, validation previews, explicit confirmation where policy requires it, and idempotency keys.
      - [x] 10.1.2.4 Subtask {#jcf-p10-10-1-2-4} - Re-query bounded projections after relevant graph revisions, reconnect, route parameter changes, authorization changes, and missed notifications.
      - [x] 10.1.2.5 Subtask {#jcf-p10-10-1-2-5} - Render command receipts and conflicts as outcome-focused product feedback without raw RDF, SPARQL, backend errors, or concealed resource details.

    - [x] 10.1.3 Task {#jcf-p10-livevue-islands} [repo: jido_code] [after: {#jcf-p10-liveview-projections}] - Implement bounded LiveVue interaction islands over graph projections.

      This task uses Vue where interaction density benefits from client state
      while preserving LiveView and the graph as semantic/session authority.

      - [x] 10.1.3.1 Subtask {#jcf-p10-10-1-3-1} - Define explicit component props/events for work dependency visualization, execution timelines, evidence comparison, source neighborhoods, or other accepted islands.
      - [x] 10.1.3.2 Subtask {#jcf-p10-10-1-3-2} - Send bounded JSON-safe projection data with revision/freshness/truncation metadata and no raw RDF structs, secrets, complete dataset mirrors, or write capability.
      - [x] 10.1.3.3 Subtask {#jcf-p10-10-1-3-3} - Emit semantic interaction intents to owning LiveViews and reauthorize every command or cross-surface handoff server-side.
      - [x] 10.1.3.4 Subtask {#jcf-p10-10-1-3-4} - Reconcile props after LiveView updates/reconnect and discard stale client selection when source projection identity changes.
      - [x] 10.1.3.5 Subtask {#jcf-p10-10-1-3-5} - Keep theme, shell, SaladUI, shadcn-vue, Vite, and light/dark behavior consistent with the accepted interface system.

    - [x] 10.1.4 Task {#jcf-p10-product-workflows} [repo: jido_code] [after: {#jcf-p10-livevue-islands}] - Implement the end-user factory workflows across current surfaces.

      This task makes enrollment through accepted outcome navigable and
      explainable without creating a route-specific alternate domain model.

      - [x] 10.1.4.1 Subtask {#jcf-p10-10-1-4-1} - Support repository enrollment/retirement, locator/provider status, observation/source refresh, and recovery through semantic commands and projections.
      - [x] 10.1.4.2 Subtask {#jcf-p10-10-1-4-2} - Support desired outcome/policy/goal/plan review, eligibility/block explanation, lease/attempt supervision, cancellation, and retry.
      - [x] 10.1.4.3 Subtask {#jcf-p10-10-1-4-3} - Support artifact/patch inspection, verification/evidence review, decision/waiver/follow-up, post-change confirmation, and satisfaction history.
      - [x] 10.1.4.4 Subtask {#jcf-p10-10-1-4-4} - Support accepted knowledge inspection, provenance, contradiction, supersession, and relevant-context explanation.
      - [x] 10.1.4.5 Subtask {#jcf-p10-10-1-4-5} - Preserve deep-link, back/forward, reload, reconnect, responsive navigation, keyboard, focus, and screen-reader behavior under authorization and stale-data changes.
      - [x] 10.1.4.6 Subtask {#jcf-p10-10-1-4-6} - Support bounded human/agent interaction, clarification, steering, cancellation, and message-to-goal, evidence, or decision handoffs where required by the current surface contract.

  - [ ] 10.2 Section - Harden authentication, authorization, privacy, and query security.

    This section verifies browser, graph, command, runtime, provider, and
    administrative boundaries enforce least privilege without leaking resource
    existence, source content, prompts, artifacts, or secrets.

    - [ ] 10.2.1 Task {#jcf-p10-web-authority} [repo: jido_code] [after: {#jcf-p10-product-workflows}] - Implement authenticated route, resource, projection, and action authorization.

      This task keeps route admission and resource/action authority distinct
      while binding graph commands to the authenticated actor and current
      scope.

      - [ ] 10.2.1.1 Subtask {#jcf-p10-10-2-1-1} - Establish or integrate the accepted authentication/session boundary and map authenticated principals to graph actor/delegation context without persisting credentials.
      - [ ] 10.2.1.2 Subtask {#jcf-p10-10-2-1-2} - Enforce route admission in Plug/live-session boundaries and repeat resource/projection/action authorization in each owning LiveView.
      - [ ] 10.2.1.3 Subtask {#jcf-p10-10-2-1-3} - Reauthorize route parameters, presentation refs, query values, semantic events, command targets, and subscriptions on every relevant transition.
      - [ ] 10.2.1.4 Subtask {#jcf-p10-10-2-1-4} - Apply concealment-oriented not-found behavior for unknown, disabled, unauthorized, cross-scope, malformed, and revoked resources.
      - [ ] 10.2.1.5 Subtask {#jcf-p10-10-2-1-5} - Clear protected projections and runtime context on logout, revocation, tenant/scope change, or untrustworthy reconnect.

    - [ ] 10.2.2 Task {#jcf-p10-query-command-security} [repo: jido_code] [after: {#jcf-p10-web-authority}] - Audit query, command, and semantic-event attack surfaces.

      This task proves browser input cannot widen graph scope, execute raw
      SPARQL, select modules/atoms, forge authority, or bypass command
      validation.

      - [ ] 10.2.2.1 Subtask {#jcf-p10-10-2-2-1} - Fuzz route refs, form fields, semantic events, IRIs, literals, cursors, idempotency keys, graph/query names, transition refs, lease fences, and command versions.
      - [ ] 10.2.2.2 Subtask {#jcf-p10-10-2-2-2} - Test SPARQL injection, catalog bypass, graph enumeration, expensive query amplification, historical-read escalation, and derived-graph confusion.
      - [ ] 10.2.2.3 Subtask {#jcf-p10-10-2-2-3} - Test CSRF, session fixation, stale authorization, cross-repository command refs, delegation widening, replay, confused deputy, and concurrent revocation.
      - [ ] 10.2.2.4 Subtask {#jcf-p10-10-2-2-4} - Verify limits and stable safe errors for malformed/oversized inputs without reflecting sensitive values.

    - [ ] 10.2.3 Task {#jcf-p10-privacy-redaction} [repo: jido_code] [after: {#jcf-p10-query-command-security}] - Complete data-classification, privacy, and redaction enforcement.

      This task applies one explicit policy across graph literals, artifacts,
      prompts/context, provider payloads, UI, diagnostics, telemetry, backups,
      exports, and test fixtures.

      - [ ] 10.2.3.1 Subtask {#jcf-p10-10-2-3-1} - Classify public, internal, confidential, secret-reference, secret-value, source-body, prompt, tool-output, personal, and audit data and map allowed graph families/readers.
      - [ ] 10.2.3.2 Subtask {#jcf-p10-10-2-3-2} - Scan all durable and transient outputs for secret values, credentials, private URLs/paths, source bodies, prompt content, raw model/tool output, and personal data beyond policy.
      - [ ] 10.2.3.3 Subtask {#jcf-p10-10-2-3-3} - Implement bounded redaction receipts and fail closed when classification or sanitization cannot be completed.
      - [ ] 10.2.3.4 Subtask {#jcf-p10-10-2-3-4} - Verify backup/export/restore and legal-erasure processes preserve encryption/access and do not reintroduce erased sensitive statements through derived graphs or caches.

    - [ ] 10.2.4 Task {#jcf-p10-threat-model} [repo: jido_code] [after: {#jcf-p10-privacy-redaction}] - Complete the factory threat model and residual-risk review.

      This task records trust boundaries, abuse cases, mitigations, test proof,
      and accepted limitations for the release candidate.

      - [ ] 10.2.4.1 Subtask {#jcf-p10-10-2-4-1} - Model threats across browser/session, provider/webhook, Git/worktree, ontology/import, SPARQL, command writer, PubSub, Jido/model, tool/sandbox, artifact URI, backup/restore, and operator maintenance boundaries.
      - [ ] 10.2.4.2 Subtask {#jcf-p10-10-2-4-2} - Map each high-risk threat to preventative controls, detection, recovery, owning tests, and operator response.
      - [ ] 10.2.4.3 Subtask {#jcf-p10-10-2-4-3} - Record residual risks and block release on unresolved credential exposure, cross-scope access, arbitrary mutation/query, sandbox escape, or restore-integrity risk.
      - [ ] 10.2.4.4 Subtask {#jcf-p10-10-2-4-4} - Review dependencies, native components, licenses, advisories, and update/rollback procedures at exact release pins.

  - [ ] 10.3 Section - Implement fleet operations, retention, and observability.

    This section makes continuous multi-repository operation predictable and
    bounded while retaining the graph as the only durable coordination state.

    - [ ] 10.3.1 Task {#jcf-p10-fleet-coordination} [repo: jido_code] [after: {#jcf-p10-threat-model}] - Harden multi-repository reconciliation and scheduling.

      This task validates fair, bounded operation across cohorts, repositories,
      capabilities, risks, and external provider limits.

      - [ ] 10.3.1.1 Subtask {#jcf-p10-10-3-1-1} - Implement configurable global/cohort/repository/provider/capability concurrency, rate, budget, and risk limits from graph policy plus trusted runtime ceilings.
      - [ ] 10.3.1.2 Subtask {#jcf-p10-10-3-1-2} - Enforce deterministic fairness and starvation prevention while preserving priority and emergency policy.
      - [ ] 10.3.1.3 Subtask {#jcf-p10-10-3-1-3} - Coalesce observation/reconciliation storms, apply provider backpressure, and retain explainable deferred/blocked reasons.
      - [ ] 10.3.1.4 Subtask {#jcf-p10-10-3-1-4} - Rebuild all fleet coordinators from graph after restart and prove no local queue/snapshot is required.
      - [ ] 10.3.1.5 Subtask {#jcf-p10-10-3-1-5} - Bound cross-repository campaign queries and preserve per-repository authorization and failure isolation.

    - [ ] 10.3.2 Task {#jcf-p10-retention-compaction} [repo: jido_code] [after: {#jcf-p10-fleet-coordination}] - Implement graph retention, compaction, archival, and legal-erasure policy.

      This task controls dataset growth without silently severing the evidence
      and provenance required by accepted outcomes.

      - [ ] 10.3.2.1 Subtask {#jcf-p10-10-3-2-1} - Define retention classes for ontology, catalog/control, observations, source revisions, run attempts, evidence/decisions, memory, audit, derived graphs, command receipts, and validation reports.
      - [ ] 10.3.2.2 Subtask {#jcf-p10-10-3-2-2} - Compute reachability from active/retained decisions, knowledge, goals, policy, audits, and legal holds before archival or removal.
      - [ ] 10.3.2.3 Subtask {#jcf-p10-10-3-2-3} - Record authorized retention/compaction/erasure activity, exact affected graphs/resources, summaries, checksums, rationale, and validation results.
      - [ ] 10.3.2.4 Subtask {#jcf-p10-10-3-2-4} - Remove/rebuild affected derived graphs and caches and prevent restored backups from silently reactivating erased data.
      - [ ] 10.3.2.5 Subtask {#jcf-p10-10-3-2-5} - Keep ordinary domain commands unable to invoke destructive retention or repair behavior.

    - [ ] 10.3.3 Task {#jcf-p10-observability-slo} [repo: jido_code] [after: {#jcf-p10-retention-compaction}] - Implement end-to-end observability and service objectives.

      This task makes store, ingestion, reconciliation, scheduling, execution,
      evaluation, reasoning, projection, and UI health diagnosable without
      persisting telemetry as product truth.

      - [ ] 10.3.3.1 Subtask {#jcf-p10-10-3-3-1} - Define low-cardinality metrics for operation latency/outcomes, queue/admission pressure, graph growth, stale/incomplete state, leases, attempts, evidence decisions, reasoning, cache, PubSub lag, backup age, and UI projection errors.
      - [ ] 10.3.3.2 Subtask {#jcf-p10-10-3-3-2} - Add trace correlation from HTTP/LiveView intent through semantic command, graph commit, reconciliation, lease, attempt, tool, evidence, decision, and re-projection using safe opaque refs.
      - [ ] 10.3.3.3 Subtask {#jcf-p10-10-3-3-3} - Define readiness, availability, durability, recovery-point/recovery-time, freshness, and bounded-query objectives with actionable alerts.
      - [ ] 10.3.3.4 Subtask {#jcf-p10-10-3-3-4} - Ensure observability remains useful during store unavailability and excludes arbitrary IRIs, graph contents, source, prompts, and secrets.

    - [ ] 10.3.4 Task {#jcf-p10-capacity-performance} [repo: jido_code] [after: {#jcf-p10-observability-slo}] - Establish fleet capacity and performance limits.

      This task measures representative workloads and sets explicit supported
      bounds rather than assuming the embedded store scales indefinitely.

      - [ ] 10.3.4.1 Subtask {#jcf-p10-10-3-4-1} - Create representative small/medium/maximum-supported fixtures for repositories, snapshots, source symbols, observations, goals/tasks, runs, evidence, memory, audit, and derived graphs.
      - [ ] 10.3.4.2 Subtask {#jcf-p10-10-3-4-2} - Benchmark startup/recovery, ingestion, semantic writes, common/bounded graph queries, reconciliation, eligibility, reasoning, backup/restore, retention, and UI projections.
      - [ ] 10.3.4.3 Subtask {#jcf-p10-10-3-4-3} - Measure concurrent readers/writers, provider storms, scheduler fairness, long-running attempts, cache cold/warm behavior, RocksDB growth/compaction, and memory use.
      - [ ] 10.3.4.4 Subtask {#jcf-p10-10-3-4-4} - Set hard/soft limits, timeouts, pagination, backpressure, degraded behavior, and operator guidance from measured results.
      - [ ] 10.3.4.5 Subtask {#jcf-p10-10-3-4-5} - Fail boundedly beyond supported limits without partial writes, unbounded memory, scheduler starvation, or misleading current-state claims.

  - [ ] 10.4 Section - Complete deployment, migration, recovery, and operator readiness.

    This section makes clean install, upgrade, rollback, backup/restore,
    corruption response, and architectural compliance reproducible for the
    release candidate.

    - [ ] 10.4.1 Task {#jcf-p10-clean-install-upgrade} [repo: jido_code] [after: {#jcf-p10-capacity-performance}] - Implement clean-install and supported upgrade workflows.

      This task creates or upgrades a dataset only through versioned,
      verifiable operations with no hidden defaults or partial readiness.

      - [ ] 10.4.1.1 Subtask {#jcf-p10-10-4-1-1} - Document/install native dependencies, trusted store/backup paths, secret references, initial bootstrap, ontology load, integrity verification, and first operator login/enrollment.
      - [ ] 10.4.1.2 Subtask {#jcf-p10-10-4-1-2} - Apply application, ontology/shape, query, rule, backend schema, and graph migrations in an explicit compatible order under maintenance mode.
      - [ ] 10.4.1.3 Subtask {#jcf-p10-10-4-1-3} - Verify backups/checksums/free space before destructive migration and preserve a tested rollback target until post-upgrade acceptance.
      - [ ] 10.4.1.4 Subtask {#jcf-p10-10-4-1-4} - Block startup/readiness on missing, incompatible, interrupted, or failed migrations and expose safe remediation.

    - [ ] 10.4.2 Task {#jcf-p10-disaster-recovery} [repo: jido_code] [after: {#jcf-p10-clean-install-upgrade}] - Complete disaster-recovery and integrity-repair runbooks.

      This task restores authoritative operation from verified graph backups
      and external system state without relying on process snapshots or local
      worktrees.

      - [ ] 10.4.2.1 Subtask {#jcf-p10-10-4-2-1} - Define response for store unavailable/locked/corrupt, disk full, failed migration, lost backup, stale external artifact, orphan runtime, and inconsistent graph integrity.
      - [ ] 10.4.2.2 Subtask {#jcf-p10-10-4-2-2} - Restore a backup into an isolated target, validate checksums/schema/ontology/integrity, switch active lineage, reconcile external provider/runtime state, and resume admission.
      - [ ] 10.4.2.3 Subtask {#jcf-p10-10-4-2-3} - Rebuild derived graphs, caches, schedulers, reconcilers, subscriptions, and runtime workers from asserted graph state.
      - [ ] 10.4.2.4 Subtask {#jcf-p10-10-4-2-4} - Define when integrity repair is permitted, which history must remain immutable, and when operator escalation/fail-stop is mandatory.
      - [ ] 10.4.2.5 Subtask {#jcf-p10-10-4-2-5} - Measure and record achieved recovery point/time against the accepted objectives.

    - [ ] 10.4.3 Task {#jcf-p10-operator-docs} [repo: jido_code] [after: {#jcf-p10-disaster-recovery}] - Complete operator and contributor documentation.

      This task makes the graph-native boundaries and routine operations clear
      enough to maintain without reintroducing record-shaped shortcuts.

      - [ ] 10.4.3.1 Subtask {#jcf-p10-10-4-3-1} - Document architecture planes, ontology/graph topology, command/query boundaries, repository control loop, execution/evidence/decision flow, and UI projection model.
      - [ ] 10.4.3.2 Subtask {#jcf-p10-10-4-3-2} - Document enrollment, provider credentials, source refresh, blocked work, lease recovery, attempt cancellation, evidence review, decisions, knowledge supersession, and policy operations.
      - [ ] 10.4.3.3 Subtask {#jcf-p10-10-4-3-3} - Document backup/restore/export, integrity, migrations, retention/erasure, capacity, observability, alerts, incident response, and rollback.
      - [ ] 10.4.3.4 Subtask {#jcf-p10-10-4-3-4} - Add contributor fitness checks for new predicates, graph families, commands, queries, projections, adapters, persistence, and route surfaces.

    - [ ] 10.4.4 Task {#jcf-p10-final-architecture-audit} [repo: jido_code] [after: {#jcf-p10-operator-docs}] - Audit the release candidate for one-source-of-truth compliance.

      This task verifies the completed implementation did not acquire a second
      object model, persistence mechanism, or hidden authority while features
      were added.

      - [ ] 10.4.4.1 Subtask {#jcf-p10-10-4-4-1} - Scan dependencies, code, configuration, browser assets, runtime state, files, test support, and deployment manifests for alternate durable stores, queues, snapshots, caches, or prompt memory.
      - [ ] 10.4.4.2 Subtask {#jcf-p10-10-4-4-2} - Scan for entity CRUD stores/codecs, persisted aggregate structs, foreign-key-shaped joins, direct subject replacement, mutable status properties, and ontology terms mirroring modules.
      - [ ] 10.4.4.3 Subtask {#jcf-p10-10-4-4-3} - Scan for raw store handles/SPARQL outside knowledge modules, unbounded browser graphs, direct runtime acceptance, inference authority, and secret-value persistence.
      - [ ] 10.4.4.4 Subtask {#jcf-p10-10-4-4-4} - Trace representative durable user-visible facts back to one semantic command, graph commit, provenance/audit, and current transition/decision chain.
      - [ ] 10.4.4.5 Subtask {#jcf-p10-10-4-4-5} - Resolve every finding or record an explicit release-blocking disposition; no compatibility facade is accepted silently.

  - [ ] 10.5 Section - Phase 10 Integration Tests.

    This final section proves the complete managed repository factory through
    browser, API/provider, graph, reconciliation, execution, evidence,
    decision, learning, fleet, security, restart, and disaster-recovery paths
    at the exact release candidate.

    - [ ] 10.5.1 Task {#jcf-p10-product-e2e} [repo: jido_code] [after: {#jcf-p10-final-architecture-audit}] - Run the complete operator workflow through product surfaces.

      This task validates actual LiveView and LiveVue behavior against the
      authoritative graph and runtime seams rather than testing projections in
      isolation.

      - [ ] 10.5.1.1 Subtask {#jcf-p10-10-5-1-1} - Authenticate, enroll a repository, ingest provider/Git observations, publish source semantics, and inspect exact freshness/provenance in the current route/workbench surface.
      - [ ] 10.5.1.2 Subtask {#jcf-p10-10-5-1-2} - Assert desired state/policy, reconcile and explain work, adopt a plan, acquire a lease, execute tools in a sandbox, supervise/cancel/retry as applicable, and inspect provenance.
      - [ ] 10.5.1.3 Subtask {#jcf-p10-10-5-1-3} - Verify patch/outcome, review evidence, decide/apply through follow-up work, observe post-change state, satisfy the goal, adopt knowledge, and inspect the complete causal path.
      - [ ] 10.5.1.4 Subtask {#jcf-p10-10-5-1-4} - Exercise loading/empty/stale/incomplete/contradicted/truncated/unauthorized/unavailable/maintenance/recovery states, deep links, back/forward, reload, reconnect, and session revocation.
      - [ ] 10.5.1.5 Subtask {#jcf-p10-10-5-1-5} - Use LiveView element-ID/outcome tests plus desktop/mobile browser verification for layout, light/dark/system theme, keyboard, focus, accessibility, island updates, console errors, and overlapping/overflowing content.

    - [ ] 10.5.2 Task {#jcf-p10-fleet-resilience-integration} [repo: jido_code] [after: {#jcf-p10-product-e2e}] - Run multi-repository load, failure, and recovery acceptance.

      This task proves continuous factory operation remains fair, bounded, and
      recoverable under representative fleet scale and concurrent failures.

      - [ ] 10.5.2.1 Subtask {#jcf-p10-10-5-2-1} - Enroll the representative fleet, apply cohort policies, ingest observation storms, reconcile campaigns, schedule concurrent capabilities, and verify fairness/backpressure/isolation.
      - [ ] 10.5.2.2 Subtask {#jcf-p10-10-5-2-2} - Exercise provider rate limits/outages, graph query/write pressure, stale source analysis, conflicting policies, lease races, long attempts, tool/sandbox failure, reasoning staleness, and projection reconnect storms.
      - [ ] 10.5.2.3 Subtask {#jcf-p10-10-5-2-3} - Kill/restart all non-store OTP workers and prove the factory converges from graph without lost/duplicated work; then restart the full BEAM and repeat.
      - [ ] 10.5.2.4 Subtask {#jcf-p10-10-5-2-4} - Run performance/capacity baselines and verify hard limits fail boundedly with accepted health/telemetry/alert behavior.
      - [ ] 10.5.2.5 Subtask {#jcf-p10-10-5-2-5} - Apply retention/compaction and prove accepted evidence/decision/knowledge reachability plus derived/cache rebuild behavior.

    - [ ] 10.5.3 Task {#jcf-p10-security-recovery-integration} [repo: jido_code] [after: {#jcf-p10-fleet-resilience-integration}] - Run adversarial security and disaster-recovery acceptance.

      This task certifies the release candidate protects authority and data and
      can restore the graph-only system of record after loss.

      - [ ] 10.5.3.1 Subtask {#jcf-p10-10-5-3-1} - Run route/resource/action, CSRF/session, delegation, query/SPARQL, webhook/provider, Git/worktree, ontology/import, tool/sandbox, artifact, backup/restore, privacy, and redaction attack suites.
      - [ ] 10.5.3.2 Subtask {#jcf-p10-10-5-3-2} - Restore the accepted backup into a clean environment with empty caches/worktrees/runtime registries and only required external credentials, then reconstruct every durable product surface.
      - [ ] 10.5.3.3 Subtask {#jcf-p10-10-5-3-3} - Compare canonical dataset exports, graph revisions/lineage, active control state, pending/recoverable attempts, evidence/decisions, knowledge, and UI projections before/after restore.
      - [ ] 10.5.3.4 Subtask {#jcf-p10-10-5-3-4} - Reconcile external provider state after restore and verify stale callbacks, leases, and artifacts cannot cause duplicate or unauthorized effects.
      - [ ] 10.5.3.5 Subtask {#jcf-p10-10-5-3-5} - Exercise supported upgrade and rollback from the prior accepted dataset and application versions.

    - [ ] 10.5.4 Task {#jcf-p10-final-release-receipt} [repo: jido_code] [after: {#jcf-p10-security-recovery-integration}] - Publish the final release and graph-only architecture receipt.

      This task binds G9 and plan completion to exact default-branch product,
      graph, runtime, security, fleet, migration, and recovery evidence.

      - [ ] 10.5.4.1 Subtask {#jcf-p10-10-5-4-1} - Record application/dependency/backend/ontology/shape/query/rule/policy/runtime/tool/sandbox versions, fixture and dataset digests, configuration posture, and candidate commit.
      - [ ] 10.5.4.2 Subtask {#jcf-p10-10-5-4-2} - Attach full operator E2E, LiveView/browser/accessibility, fleet/load, failure/restart, security/privacy, retention, upgrade/rollback, backup/restore, and architecture-audit results.
      - [ ] 10.5.4.3 Subtask {#jcf-p10-10-5-4-3} - Run all phase suites, `mix precommit`, production asset build, clean install, and restored-environment smoke/browser verification at the merged candidate.
      - [ ] 10.5.4.4 Subtask {#jcf-p10-10-5-4-4} - Keep release blocked for any second durable store, unexplained accepted fact, unrecoverable process state, raw graph/UI bypass, security finding, failed objective, or prospective-only evidence.
      - [ ] 10.5.4.5 Subtask {#jcf-p10-10-5-4-5} - Pin the accepted release commit and publish the final completion disposition with all known limits and follow-up work.
