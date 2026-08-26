---
id: plan.jido_code_delegated_coding_agents_phase_01
parent_plan: plan.jido_code_delegated_coding_agents
status: approved
intent: feature
---

# Delegated Coding Agents Phase 1 - Semantic Contract, Profiles, And Agent Catalog

This phase baselines the approved delegated-agent decisions and introduces the
exact semantic identities, lifecycle, commands, and queries needed to select a
delegated agent without granting graph authority to runtime code.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Establish the durable contract for delegated coding agents.

  This phase proves DCG1 by making adapter releases, profiles, readiness,
  offerings, and selections graph-authorized, scoped, versioned, and
  reconstructable.

  - [x] 1.1 Section - Baseline the approved delegated-agent architecture and DGA1 boundary.

    This section pins the accepted ADRs and approved specifications as the
    implementation baseline.

    - [x] 1.1.1 Task {#dca-p01-governance} [repo: jido_code] - Pin and reconcile the delegated-agent decisions.

      This task makes the Codex-first, JidoCode-owned protected launch policy
      and developer-local scope normative.

      - [x] 1.1.1.1 Subtask - Pin accepted ADRs 0003 and 0004, their consequences, alternatives, and reopening conditions as governing inputs.
      - [x] 1.1.1.2 Subtask - Pin the approved profile, runtime, and product specification revisions and record their canonical digests.
      - [x] 1.1.1.3 Subtask - Record that JidoHarness and Codex are the intended execution route while the current prompt-in-argv built-in adapter remains blocked.
      - [x] 1.1.1.4 Subtask - Limit DGA1 to foreground `developer_local` execution against `jido_code`; keep DGA2, other providers, managed fleet, publication, and merge out of scope.
      - [x] 1.1.1.5 Subtask - Reconcile terminology with the accepted harness and managed-coding contracts and update architecture indexes.

  - [x] 1.2 Section - Extend the ontology and semantic command line.

    This section gives profiles, adapter releases, readiness, and runtime
    selection durable, versioned meanings.

    - [x] 1.2.1 Task {#dca-p01-ontology} [repo: jido_code] [after: {#dca-p01-governance}] - Publish ontology and SHACL revision `1.4.0`.

      This task defines the delegated-agent resources and validates their
      closed-world invariants.

      - [x] 1.2.1.1 Subtask - Define `DelegatedAdapterRelease` with provider, CLI compatibility, JidoHarness revision, executable-registry key, prompt protocol, session protocol, capability support, and evidence digest.
      - [x] 1.2.1.2 Subtask - Define `DelegatedAgentProfile` with runtime class, deployment, repository/task/language envelope, access profile, capability, sandbox, network, candidate, verifier, budgets, rollout, and exact adapter release.
      - [x] 1.2.1.3 Subtask - Define expiring `DelegatedAgentReadiness` observations tied to the exact profile, adapter, CLI, credential generation, worker, network, and verifier revisions.
      - [x] 1.2.1.4 Subtask - Use canonical `developer_local` vocabulary while retaining read compatibility for legacy `developer_local_cli` values only at the adapter boundary.
      - [x] 1.2.1.5 Subtask - Place releases and profiles in existing policy/catalog graph families and attempt observations in existing run graphs without adding a durable store.

    - [x] 1.2.2 Task {#dca-p01-command-protocol} [repo: jido_code] [after: {#dca-p01-ontology}] - Publish semantic command and query protocol `2.9.0`.

      This task makes every delegated profile mutation and catalog projection
      pass through reviewed semantic interfaces.

      - [x] 1.2.2.1 Subtask - Add `RegisterDelegatedAdapterRelease`, `RegisterDelegatedAgentProfile`, `TransitionDelegatedAgentProfile`, and `RecordDelegatedAgentReadiness` with authorization, preconditions, idempotency, provenance, and redaction.
      - [x] 1.2.2.2 Subtask - Add `SelectableAgentOfferingsByScope`, `DelegatedAgentProfileDetail`, `DelegatedAgentReadinessByProfile`, and `DelegatedAgentProfileHistory` with bounded parameters and result shapes.
      - [x] 1.2.2.3 Subtask - Reject unknown runtime classes, providers, executable keys, releases, deployment classes, capabilities, and lifecycle transitions.
      - [x] 1.2.2.4 Subtask - Preserve read compatibility with protocol `2.8.0` and ontology `1.3.0` without allowing old records to imply delegated eligibility.

  - [ ] 1.3 Section - Implement exact catalog projection and resolution.

    This section turns durable profiles into scoped product offerings without
    persisting or trusting the projection.

    - [ ] 1.3.1 Task {#dca-p01-catalog} [repo: jido_code] [after: {#dca-p01-command-protocol}] - Implement the unified native and delegated agent catalog.

      This task returns only offerings currently authorized for the requesting
      actor, repository, task, capability, rollout, and time.

      - [ ] 1.3.1.1 Subtask - Define disposable `AgentOffering` values with opaque reference, display label, runtime class, provider, deployment, billing, readiness age, capability summary, rollout, and limitations.
      - [ ] 1.3.1.2 Subtask - Derive offerings at query time from exact current graph revisions and never persist them as authorization.
      - [ ] 1.3.1.3 Subtask - Include existing native profiles and the disabled Codex profile in one projection while clearly distinguishing availability and runtime class.
      - [ ] 1.3.1.4 Subtask - Prevent cross-actor, cross-tenant, cross-repository, expired, revoked, stale-readiness, and unsupported-task disclosure.

    - [ ] 1.3.2 Task {#dca-p01-resolution} [repo: jido_code] [after: {#dca-p01-catalog}] - Bind opaque selections to exact managed-coding admission.

      This task makes selection deterministic and prevents provider, runtime,
      authentication, or billing fallback.

      - [ ] 1.3.2.1 Subtask - Resolve the opaque offering reference server-side to exact profile and adapter digests under the current authorization context.
      - [ ] 1.3.2.2 Subtask - Commit profile, runtime, adapter, access, deployment, capability, readiness, attempt, lease, fence, and invocation-before-effect identities before process creation.
      - [ ] 1.3.2.3 Subtask - Return bounded admitted, duplicate, stale, unauthorized, incompatible, unavailable, and rejected outcomes.
      - [ ] 1.3.2.4 Subtask - Invalidate the offering after profile, adapter, readiness, credential-generation, policy, or source-snapshot drift.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves delegated-agent authority is fully semantic,
    scoped, exact, and backward compatible.

    - [ ] 1.4.1 Task {#dca-p01-integration} [repo: jido_code] [after: {#dca-p01-resolution}] - Execute the semantic and catalog integration matrix.

      This task closes DCG1 only when no disposable projection or
      caller-controlled value can become runtime authority.

      - [ ] 1.4.1.1 Subtask - Exercise registration, transition, readiness, expiry, revocation, duplicate, malformed, unauthorized, stale, and concurrent command cases against the real store.
      - [ ] 1.4.1.2 Subtask - Prove catalog isolation across actors, tenants, repositories, task classes, languages, capabilities, rollout states, time, and readiness generations.
      - [ ] 1.4.1.3 Subtask - Prove exact opaque selection, no fallback, legacy read compatibility, and deterministic graph-only reconstruction.
      - [ ] 1.4.1.4 Subtask - Run ontology verification, architecture checks, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [ ] 1.4.2 Task {#dca-p01-phase-receipt} [repo: jido_code] [after: {#dca-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records DCG1 evidence in
      `docs/architecture/delegated-agent-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Record ADR, specification, ontology, protocol, query, profile, projection, and fixture revisions and digests.
      - [ ] 1.4.2.2 Subtask - Keep DCG1 open if selection can bypass current graph authorization, disclose another scope, or fall back to another runtime tuple.
      - [ ] 1.4.2.3 Subtask - Attach architecture, store, compatibility, precommit, Dialyzer, and clean-checkout evidence.
      - [ ] 1.4.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, integration, receipt, and pinning checkboxes before authorizing Phase 2.
