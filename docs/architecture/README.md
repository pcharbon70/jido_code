# Architecture

This directory contains the accepted implementation boundaries for JidoCode.
The documents distinguish architectural authority from research and delivery
planning:

1. Accepted ADRs under [`docs/adr`](../adr/) define binding decisions.
2. Architecture documents in this directory define the current evidence and
   module boundaries that implement those decisions.
3. [`docs/research`](../research/) records analysis and recommendations.
4. [`docs/planning`](../planning/) sequences implementation work but does not
   override an accepted ADR or tested backend constraint.

Current consolidated view:
[Current coding factory architecture, agent flows, and gap analysis](./current-coding-factory-architecture-and-agent-flows.md).

## Phase 1 Baseline

- [Current-state inventory](./current-state-inventory.md)
- [Module and plane boundaries](./module-boundaries.md)
- [Backend compatibility contract](./backend-compatibility.md)
- [Failure, health, and telemetry contract](./failure-health-and-telemetry.md)
- [Architecture guardrails](./architecture-guardrails.md)
- [Phase 1 architecture and compatibility receipt](./phase-01-receipt.md)
- [ADR 0001: Graph-only source of truth](../adr/0001-graph-only-source-of-truth.md)
- [ADR 0002: TripleStore backend contract](../adr/0002-triple-store-backend-contract.md)

The Phase 1 baseline starts at commit
`54cda0fd34cc687f0c1be6322513a790d3a9c37e`, immediately after the graph-native
implementation plan was merged.

## Phase 2 Substrate

- [Authoritative store lifecycle](./store-lifecycle.md)
- [Atomic writes and revisions](./atomic-writes-and-revisions.md)
- [Backup, restore, export, and integrity](./backup-restore-and-integrity.md)
- [Knowledge store operations runbook](../operations/knowledge-store-runbook.md)
- [Phase 2 durable substrate receipt](./phase-02-receipt.md)

## Phase 3 Semantic Contract

- [Factory ontology contract](./factory-ontology.md)
- [Graph identity and topology](./graph-identity-and-topology.md)
- [Semantic validation and evolution](./semantic-validation-and-evolution.md)
- [Claims, time, transitions, and inference](./claims-time-transitions-and-inference.md)
- [Phase 3 semantic contract receipt](./phase-03-receipt.md)

## Phase 4 Controlled Mutation

- [Semantic command contract](./semantic-command-contract.md)
- [Governed command pipeline](./governed-command-pipeline.md)
- [Authority, bootstrap, and audit](./authority-bootstrap-and-audit.md)
- [Change delivery and command recovery](./change-delivery-and-command-recovery.md)
- [Phase 4 controlled mutation receipt](./phase-04-receipt.md)

## Phase 5 Bounded Reads

- [Reviewed query catalog and execution boundary](./reviewed-query-catalog.md)
- [Query consistency and temporal state](./query-consistency-and-temporal-state.md)
- [Bounded projections, cache, and subscriptions](./bounded-projections-cache-and-subscriptions.md)
- [Derived graphs and read diagnostics](./derived-graphs-and-read-diagnostics.md)
- [Phase 5 bounded interpretation receipt](./phase-05-receipt.md)

## Phase 6 Repository Knowledge

- [Source analysis boundary](./source-analysis.md)
- [Phase 6 repository knowledge receipt](./phase-06-receipt.md)

## Phase 7 Factory Control Loop

- [Factory control loop](./factory-control-loop.md)
- [Phase 7 factory control loop receipt](./phase-07-receipt.md)

## Phase 8 Governed Execution

- [Execution runtime boundary](./execution-runtime-boundary.md)
- [Execution attempt lifecycle](./execution-attempt-lifecycle.md)
- [Governed execution effects and artifacts](./execution-effects-provenance.md)
- [Execution provenance and recovery](./execution-provenance-and-recovery.md)
- [Phase 8 governed execution receipt](./phase-08-receipt.md)

## Phase 9 Evidence And Learning

- [Verification and evidence boundary](./verification-evidence-boundary.md)
- [Governed decision outcomes](./governed-decision-outcomes.md)
- [Governed knowledge memory](./governed-knowledge-memory.md)
- [Bounded reasoning and cross-graph learning](./bounded-reasoning-and-learning.md)
- [Phase 9 accepted outcome and learning receipt](./phase-09-receipt.md)

## Phase 10 Product Acceptance

- [Product surface and island contract](./product-surface-and-island-contract.md)
- [Product security, privacy, and threat model](./product-security-privacy-and-threat-model.md)
- [Fleet capacity, retention, and observability](../operations/fleet-capacity-retention-and-observability.md)
- [Install, upgrade, and rollback](../operations/install-upgrade-and-rollback.md)
- [Disaster recovery](../operations/disaster-recovery.md)
- [Operator handbook](../operations/operator-handbook.md)
- [Graph-native contributor fitness checks](../contributing/graph-native-fitness-checks.md)
- [Phase 10 architecture audit](./phase-10-architecture-audit.md)
- [Phase 10 product and release acceptance receipt](./phase-10-receipt.md)

## Approved Delegated Coding Agent Remediation

These approved specifications define the work required to make
developer-facing JidoHarness coding CLIs first-class JidoCode agents under
accepted ADRs 0003 and 0004. They do not change the current release posture
until their gated implementation merges.

- [ADR 0003: First-class delegated coding agents](../adr/0003-first-class-delegated-coding-agents.md)
- [ADR 0004: Delegated-agent credentials and isolation](../adr/0004-delegated-agent-credentials-and-isolation.md)
- [Delegated coding agent profile and catalog specification](./delegated-agent-profile-catalog.md)
- [Delegated coding agent runtime protocol specification](./delegated-agent-runtime-protocol.md)
- [Delegated coding agent product and qualification specification](./delegated-agent-product-and-qualification.md)
- [Delegated coding agent governance baseline](./delegated-agent-governance-baseline.md)
- [Delegated coding agent Phase 1 semantic contract receipt](./delegated-agent-phase-01-receipt.md)
- [Protected Codex delegated runtime](./delegated-agent-codex-runtime.md)
- [Delegated coding agent Phase 2 protected runtime receipt](./delegated-agent-phase-02-receipt.md)
- [Delegated coding agent Phase 3 local containment receipt](./delegated-agent-phase-03-receipt.md)
- [Delegated agent developer-local containment](./delegated-agent-local-containment.md)

## Approved Repository Wiki Architecture

These accepted decisions and approved specifications let each enrolled
codebase opt into a
repository-scoped, editioned wiki without replacing Git or the accepted graph
authority boundaries. Their gated implementation remains disabled until the
corresponding phase receipts are accepted at merged candidates.

- [Repository wiki research](../research/11-repository-wikis-as-compiled-knowledge-projections.md)
- [ADR 0005: Repository wikis as compiled knowledge projections](../adr/0005-repository-wikis-as-compiled-knowledge-projections.md)
- [ADR 0006: Per-repository wiki maintainer agents](../adr/0006-per-repository-wiki-maintainer-agents.md)
- [ADR 0007: Repository wiki enrollment and cost governance](../adr/0007-repository-wiki-enrollment-and-cost-governance.md)
- [Repository wiki graph and edition contract](./repository-wiki-graph-and-edition-contract.md)
- [Repository wiki compilation and update protocol](./repository-wiki-compilation-and-update-protocol.md)
- [Repository wiki Mix project and dependency catalog](./repository-wiki-mix-project-and-dependency-catalog.md)
- [Repository wiki maintainer runtime](./repository-wiki-maintainer-runtime.md)
- [Repository wiki enrollment, budget, and accounting](./repository-wiki-enrollment-budget-and-accounting.md)
- [Repository wiki product and qualification](./repository-wiki-product-and-qualification.md)
- [Repository wikis implementation plan](../planning/repository-wikis/README.md)
- [Repository wiki governance baseline](./repository-wiki-governance-baseline.md)

## Secure Hypermedia Control Plane UI Program

These decisions and specifications translate the secure hypermedia UI research
into eight milestone plans containing thirty-seven implementation phases. HUI-A1
pins current authority. ADR 0009 and its identity/authorization contract are
accepted as architecture authority through HUI-A2 while their runtime and
release capabilities remain gated. The remaining proposed decisions do not
become binding until accepted or narrowed through the normal merged-candidate
receipt process.

- [Secure hypermedia control plane UI research](../research/12-secure-hypermedia-coding-factory-ui.md)
- [HUI-A1 current-state authority baseline](./hypermedia-ui-current-state-authority-baseline.md)
- [HUI-A1 runtime and authority inventory](./hypermedia-ui-runtime-and-authority-inventory.md)
- [HUI-A1 vocabulary and supersession matrix](./hypermedia-ui-vocabulary-and-supersession.md)
- [HUI-A1 accepted Phase 1 receipt](./hypermedia-ui-milestone-a-phase-01-receipt.md)
- [HUI-A2 identity and assurance manifest](../../priv/architecture/hypermedia_ui/phase_a2_identity_and_assurance.json)
- [HUI-A2 operation authorization matrix](./hypermedia-ui-operation-authorization-matrix.md)
- [HUI-A2 approval and live revocation authority](./hypermedia-ui-approval-and-live-revocation-authority.md)
- [ADR 0008: Server-rendered HEEx and Datastar product runtime](../adr/0008-server-rendered-heex-and-datastar-product-runtime.md)
- [ADR 0009: Human identity, scoped authorization, and separation of duty](../adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md)
- [ADR 0010: ShadcnUI as the product component primitive layer](../adr/0010-shadcnui-as-product-component-primitive-layer.md)
- [ADR 0011: Attention-oriented control plane and knowledge lenses](../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)
- [Hypermedia product governance baseline](./hypermedia-product-governance-baseline.md)
- [Human identity, scope, and authorization contract](./human-identity-scope-and-authorization-contract.md)
- [ShadcnUI adoption and component contract](./shadcn-ui-adoption-and-component-contract.md)
- [Datastar and Dstar dependency and consumer qualification](./datastar-dstar-dependency-and-consumer-qualification.md)
- [Secure product shell and information architecture](./secure-product-shell-and-information-architecture.md)
- [Datastar request, signal, fragment, and stream contract](./datastar-request-signal-fragment-and-stream-contract.md)
- [Agent attempt workspace and command contract](./agent-attempt-workspace-and-command-contract.md)
- [Graph lens and visualization contract](./graph-lens-and-visualization-contract.md)
- [Hypermedia UI security, privacy, and threat model](./ui-security-privacy-and-threat-model.md)
- [Incident control plane contract](./incident-control-plane-contract.md)
- [UI accessibility, usability, and release qualification](./ui-accessibility-usability-and-release-qualification.md)
- [Hypermedia runtime migration and rollback](./hypermedia-runtime-migration-and-rollback.md)
- [Secure hypermedia control plane UI milestone-plan portfolio](../planning/secure-hypermedia-control-plane-ui/README.md)
