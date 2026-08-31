---
id: plan.jido_code_secure_hypermedia_control_plane_ui_phase_01
parent_plan: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
---

# Secure Hypermedia Control Plane UI Phase 1 — Architectural Authority And Governance

This phase implements Milestone A and closes HUI1 by accepting the governing
decisions, pinning the current baseline, resolving vocabulary and authority,
inventorying every migration owner, and adding fitness checks before any new UI
dependency or route is introduced.

Back to plan: [README](./README.md)

- [ ] 1 Phase — Establish the accepted authority and migration baseline.

  This phase makes the target architecture implementable without weakening
  graph, projection, command, security, recovery, or current-readiness truth.

  - [ ] 1.1 Section — Accept and pin the hypermedia UI decisions.

    This section turns the research recommendations into reviewed governing
    inputs and pins the exact merged baseline from which implementation starts.

    - [ ] 1.1.1 Task {#hui-p01-governance} [repo: jido_code] — Review and accept or narrow ADRs 0008–0011 and their specifications.

      This task resolves every proposed decision, consequence, alternative,
      compatibility boundary, and acceptance condition before code changes.

      - [ ] 1.1.1.1 Subtask — Review ADR 0008's controller/HEEx/Datastar runtime, qualified Phoenix.Component dependency, explicit handlers, and LiveView product-runtime prohibition.
      - [ ] 1.1.1.2 Subtask — Review ADR 0009's named human identity, exact capability mapping, step-up, revocation, and separation-of-duty model.
      - [ ] 1.1.1.3 Subtask — Review ADR 0010's ShadcnUI provenance, facade, asset, theme, semantic, and accessibility decision.
      - [ ] 1.1.1.4 Subtask — Review ADR 0011's attention, project/repository alias, attempt workspace, interaction-session distinction, graph lenses, and control posture.
      - [ ] 1.1.1.5 Subtask — Record accepted/narrowed statuses, owners, dates, specification versions, and every preserved gate-reopening condition.

    - [ ] 1.1.2 Task {#hui-p01-baseline} [repo: jido_code] [after: {#hui-p01-governance}] — Pin the implementation baseline and governing digests.

      This task creates reproducible provenance for the architecture and
      prevents concurrent documentation or dependency drift.

      - [ ] 1.1.2.1 Subtask — Require PR #99 or an equivalent milestone-naming change to be merged and sync a clean `origin/main` baseline.
      - [ ] 1.1.2.2 Subtask — Record the full baseline SHA, merge date, ontology/SHACL/GraphRegistry/command/query/product/runtime/wiki versions, and current release posture.
      - [ ] 1.1.2.3 Subtask — Record SHA-256 digests for research, ADRs, specifications, plan README, and all phase files.
      - [ ] 1.1.2.4 Subtask — Reconcile this work with open parallel plans and assign version/file ownership so phases do not race shared contracts.

  - [ ] 1.2 Section — Reconcile vocabulary, authority, current readiness, and supersession.

    This section prevents the new product from conflating durable identities or
    presenting implemented contracts as production-operable services.

    - [ ] 1.2.1 Task {#hui-p01-vocabulary} [repo: jido_code] [after: {#hui-p01-baseline}] — Publish the closed product identity and route vocabulary.

      This task fixes the relationship among repository-backed Project,
      attempt workspace, `InteractionSession`, candidate, browser session,
      provider thread, runtime, and process.

      - [ ] 1.2.1.1 Subtask — Define Project as a V1 presentation alias for one conceptual repository and reject an implicit multi-repository project resource.
      - [ ] 1.2.1.2 Subtask — Define attempt-workspace route identity and the reviewed mapping/cardinality to distinct interaction sessions.
      - [ ] 1.2.1.3 Subtask — Publish safe human labels and opaque-ref rules without exposing internal graph IRIs or treating refs as grants.
      - [ ] 1.2.1.4 Subtask — Reconcile execution, verification, decision, draft publication, source application/re-observation, knowledge adoption, wiki activation, and satisfaction terms.

    - [ ] 1.2.2 Task {#hui-p01-inventory} [repo: jido_code] [after: {#hui-p01-vocabulary}] — Inventory current product owners and readiness truth.

      This task identifies every route, module, dependency, asset, test,
      operation, document, and unconfigured adapter that affects migration.

      - [ ] 1.2.2.1 Subtask — Inventory LiveViews, router/live-session, socket, auth hooks, LiveVue/Vue, SaladUI, Vite, LiveDashboard, assets, components, and tests.
      - [ ] 1.2.2.2 Subtask — Inventory current Product projections/gateways, graph capabilities, current single-operator identity, and field/classification gaps.
      - [ ] 1.2.2.3 Subtask — Record scheduler/service/loaders, delegated rollout, publication, wiki gateways, provider/runtime, identity, and live-delivery posture as ready, disabled, unconfigured, evaluation, or contract-only.
      - [ ] 1.2.2.4 Subtask — Assign route/asset/dependency/document rollback owner and last qualified artifact for every inventory entry.

    - [ ] 1.2.3 Task {#hui-p01-supersession} [repo: jido_code] [after: {#hui-p01-inventory}] — Publish the contract preservation and supersession matrix.

      This task explicitly supersedes only presentation ownership while
      retaining accepted authority and reopening conditions.

      - [ ] 1.2.3.1 Subtask — Map graph-only, reviewed query, semantic command, projection-state, subscription/recovery, security, wiki, and operations invariants to the new stack.
      - [ ] 1.2.3.2 Subtask — Identify exact LiveView/LiveVue normative clauses that ADR 0008 supersedes and their replacement specification clauses.
      - [ ] 1.2.3.3 Subtask — Update architecture and ADR indexes with proposed/accepted status and prevent mixed current route ownership.

  - [ ] 1.3 Section — Enforce the architecture boundary before implementation.

    This section adds automated drift detection and a skeleton evidence model
    for all later phases.

    - [ ] 1.3.1 Task {#hui-p01-fitness} [repo: jido_code] [after: {#hui-p01-supersession}] — Extend architecture fitness checks for the target boundary.

      This task makes prohibited runtime, graph, dispatch, asset, dependency,
      and browser-authority patterns fail deterministically.

      - [ ] 1.3.1.1 Subtask — Add fixtures/checks for prohibited product LiveView routes/modules/events/streams and LiveVue islands while allowing qualified Phoenix.Component use.
      - [ ] 1.3.1.2 Subtask — Add fixtures/checks for raw web graph/query access, caller-selected graphs/modules/events, Dstar Scripts, external assets, and unpinned dependencies.
      - [ ] 1.3.1.3 Subtask — Add fixtures/checks for browser-derived actor/scope/role/capability/query/command/profile/fence/revision authority.
      - [ ] 1.3.1.4 Subtask — Add documentation drift checks for conflicting current route owners, stale terminology, and missing proposed/accepted status.

    - [ ] 1.3.2 Task {#hui-p01-evidence} [repo: jido_code] [after: {#hui-p01-fitness}] — Create the HUI1 gate and receipt schema.

      This task defines evidence fields and reopening conditions without
      prematurely claiming an accepted implementation.

      - [ ] 1.3.2.1 Subtask — Create `hypermedia-ui-phase-01-receipt.md` in merge-pending state with Candidate Provenance and Gate HUI1 sections.
      - [ ] 1.3.2.2 Subtask — Record governing digests, inventory revisions, fitness fixtures, commands, clean-checkout status, owners, and unresolved blockers.
      - [ ] 1.3.2.3 Subtask — Preserve every HUI1 reopening condition and the existing accepted-contract reopening conditions verbatim or by canonical link.

  - [ ] 1.4 Section — Phase 1 Integration Tests.

    This final section proves the architecture is internally consistent,
    reproducible, honest about current readiness, and protected from drift.

    - [ ] 1.4.1 Task {#hui-p01-integration} [repo: jido_code] [after: {#hui-p01-evidence}] — Execute the HUI1 governance and architecture matrix.

      This task closes implementation evidence only when every governing input,
      identity, owner, supersession, and prohibited boundary is accounted for.

      - [ ] 1.4.1.1 Subtask — Validate all ADR/spec/plan links, statuses, milestone/phase mapping, identifiers, anchors, dependencies, and digests.
      - [ ] 1.4.1.2 Subtask — Run permitted/prohibited architecture fixtures and prove current code remains unchanged except documented governance checks.
      - [ ] 1.4.1.3 Subtask — Review current readiness and confirm no UI/release claim exceeds configured adapters and accepted gates.
      - [ ] 1.4.1.4 Subtask — Run documentation lint/link checks, architecture checks, Dialyzer where configured, `mix precommit`, and clean-checkout CI.

    - [ ] 1.4.2 Task {#hui-p01-phase-receipt} [repo: jido_code] [after: {#hui-p01-integration}] — Publish and pin the Phase 1 receipt.

      This task records Gate HUI1 evidence and authorizes Phase 2 only after the
      implementation candidate merges cleanly.

      - [ ] 1.4.2.1 Subtask — Keep HUI1 merge-pending if any decision, inventory owner, vocabulary, current-readiness blocker, supersession, fitness rule, or reopening condition is unresolved.
      - [ ] 1.4.2.2 Subtask — Record the full implementation merge SHA and date and change HUI1 to accepted-at-merged-candidate without weakening reopening conditions.
      - [ ] 1.4.2.3 Subtask — Pin the merged candidate commit and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
