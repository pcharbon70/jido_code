---
id: plan.jido_code_hypermedia_ui_milestone_f_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_f
status: proposed
intent: feature
---

# Milestone F Phase 1 - Reviewed Lens Catalog And Query Envelopes

This phase creates the closed lens registry and public query/view-model
envelopes that every later graph page must use.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Register every enabled graph domain behind bounded product questions.

  This phase closes HUI-F1 by making absence from the registry mean no product
  route, query, join, detail, stream, or export.

  - [ ] 1.1 Section - Freeze graph-family and lens coverage.

    This section maps durable graph topology into user questions and owners
    without exposing graph IRIs as the product mental model.

    - [ ] 1.1.1 Task {#huif-p01-catalog} [repo: jido_code] [after: {#huie-p06-phase-receipt}] - Implement the reviewed lens registry.

      This task records the approved ten-lens taxonomy and all seventeen graph
      families with sensitivity/readiness posture.

      - [ ] 1.1.1.1 Subtask - Register repository health, source, project domain, work/execution, evidence/review, cost, dependency/wiki, memory, security/audit, and dataset/derived-diagnostic lenses.
      - [ ] 1.1.1.2 Subtask - Map each graph family to owner, human question, route, audience, sensitivity/classification, authoritative source, readiness, and allowed cross-family references.
      - [ ] 1.1.1.3 Subtask - Mark disabled/unconfigured/contract-only graph families explicitly and prohibit a route merely because a named graph exists.
      - [ ] 1.1.1.4 Subtask - Define registry versioning, additive/breaking changes, review/sign-off, deprecation, telemetry, and compatibility with live subscriptions.

  - [ ] 1.2 Section - Define and implement per-lens query envelopes.

    This section closes the input, authorization, join, result, state, and
    resource limits for each named product question.

    - [ ] 1.2.1 Task {#huif-p01-envelopes} [repo: jido_code] [after: {#huif-p01-catalog}] - Implement typed lens request and result contracts.

      This task ensures browser filters and opaque refs cannot select arbitrary
      graphs, predicates, paths, queries, or fields.

      - [ ] 1.2.1.1 Subtask - Define allowed resource/scope/filter/sort/search/page/time/view inputs and reject graph/query/predicate/path/depth/field lists outside the registry.
      - [ ] 1.2.1.2 Subtask - Define prepared query/version, allowed graph joins, field schemas, row/page/depth/node/edge/time/byte limits, cancellation, timeout, and deterministic ordering.
      - [ ] 1.2.1.3 Subtask - Define exact graph/field/resource authorization before query, after shaping, on pagination/detail/export, and after live refresh/revocation.
      - [ ] 1.2.1.4 Subtask - Define provenance, source/evaluated revision, freshness, completeness, contradiction, partial/truncated, concealment, unavailable, unconfigured, error, and retry outcomes.

    - [ ] 1.2.2 Task {#huif-p01-queries} [repo: jido_code] [after: {#huif-p01-envelopes}] - Implement public bounded lens query adapters.

      This task keeps product web code above Product/Factory APIs and returns
      typed view models rather than raw triples or storage handles.

      - [ ] 1.2.2.1 Subtask - Implement prepared reviewed query calls and typed view-model builders for the initial registered questions using trusted current authority/scope.
      - [ ] 1.2.2.2 Subtask - Normalize human labels, typed values, opaque resource refs, provenance, graph/lens revision, bounds, and safe diagnostic codes.
      - [ ] 1.2.2.3 Subtask - Enforce cache isolation by principal/session generation/scope/grants/lens/query version and no protected shared/browser/proxy caching.
      - [ ] 1.2.2.4 Subtask - Reject raw SPARQL, arbitrary traversal, Knowledge internal structs, unrestricted joins, caller-selected graphs, raw IRIs, and hidden post-filtering.

  - [ ] 1.3 Section - Install lens architecture and inference guardrails.

    This section detects registry bypass, unsafe joins, unbounded queries, and
    side channels before domain pages are implemented.

    - [ ] 1.3.1 Task {#huif-p01-guardrails} [repo: jido_code] [after: {#huif-p01-queries}] - Add query/lens traceability and negative fixtures.

      This task makes reviewed lens ownership and limit coverage executable.

      - [ ] 1.3.1.1 Subtask - Verify each route/controller/view model/subscription/export maps to one registered lens/query/version/owner and every graph family maps to a lens or unavailable posture.
      - [ ] 1.3.1.2 Subtask - Detect raw query strings, Knowledge/internal imports, dynamic predicate/graph/path construction, unauthorized joins, missing bounds/cancellation, and post-query redaction.
      - [ ] 1.3.1.3 Subtask - Add cross-tenant/project/repository/attempt/interaction/preview/graph inference fixtures for counts, facets, errors, timing, pagination, caches, provenance, and links.
      - [ ] 1.3.1.4 Subtask - Require exact exception owner/scope/reason/expiry/evidence and prohibit exceptions that expose unrestricted query capability.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves the registry and query envelopes are complete,
    bounded, authorized, deterministic, and resistant to inference.

    - [ ] 1.4.1 Task {#huif-p01-integration} [repo: jido_code] [after: {#huif-p01-guardrails}] - Execute the HUI-F1 registry, query, and isolation matrix.

      This task uses real graph fixtures across all registered/disabled families
      and hostile request/query conditions.

      - [ ] 1.4.1.1 Subtask - Exercise every lens/family/query/version/input/field/join/state and all row/page/depth/node/edge/time/byte/timeout/cancellation bounds.
      - [ ] 1.4.1.2 Subtask - Exercise unknown/dynamic graph/query/predicate/path, raw SPARQL/internal imports, hostile labels, cross-scope refs, totals/facets/timing/cache inference, and revocation.
      - [ ] 1.4.1.3 Subtask - Verify disabled/unconfigured/contract-only families are honest, no route exists outside the registry, and all output has safe provenance/freshness/truncation.
      - [ ] 1.4.1.4 Subtask - Run real-store/query/property/security/architecture suites, `mix precommit`, and clean-checkout CI.

    - [ ] 1.4.2 Task {#huif-p01-phase-receipt} [repo: jido_code] [after: {#huif-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-F1 evidence in
      `docs/architecture/hypermedia-ui-milestone-f-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Keep HUI-F1 merge-pending on uncovered enabled graph, registry bypass, raw query/traversal, unbounded input/result, unsafe join, cross-scope inference, or missing provenance/state.
      - [ ] 1.4.2.2 Subtask - Record registry/query/view-model/limit/fixture evidence, failures, limitations, and all reopening conditions.
      - [ ] 1.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
