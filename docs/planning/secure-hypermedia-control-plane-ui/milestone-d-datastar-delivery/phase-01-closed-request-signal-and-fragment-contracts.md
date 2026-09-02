---
id: plan.jido_code_hypermedia_ui_milestone_d_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_d
status: proposed
intent: feature
---

# Milestone D Phase 1 - Closed Request, Signal, And Fragment Contracts

This phase enhances bounded reads and native forms with explicit Datastar
request schemas and coherent HEEx fragments; it adds no automatic stream yet.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Implement secure request intent and stable authorized fragment rendering.

  This phase closes HUI-D1 by making every enhanced request independently
  validated, authorized, CSP/CSRF-safe, and equivalent to a native workflow.

  - [ ] 1.1 Section - Define and implement per-page signal schemas.

    This section admits only bounded presentation/request intent and rejects
    browser attempts to provide identity, grants, resources, or revisions.

    - [ ] 1.1.1 Task {#huid-p01-signals} [repo: jido_code] [after: {#huic-p05-phase-receipt}] - Implement closed signal namespaces and parsers.

      This task gives each route/action its own typed allowed subset, limits,
      normalization, defaults, and safe reset behavior.

      - [ ] 1.1.1.1 Subtask - Define global/local namespaces and allowlisted filter/sort/search/cursor/page/view/overlay/pause-visual-update keys by route/action.
      - [ ] 1.1.1.2 Subtask - Enforce key count, nesting depth, scalar/list length, UTF-8, aggregate bytes, enum/range, duplicate-key, unknown-key, and normalization limits.
      - [ ] 1.1.1.3 Subtask - Reject principal/session/tenant/project/resource/graph/grant/delegation/assurance/revision/fence/profile/idempotency/command fields and scope-reset unsafe state.
      - [ ] 1.1.1.4 Subtask - Add typed safe diagnostics and property/fuzz fixtures without reflecting secrets, raw protected values, or parser internals.

  - [ ] 1.2 Section - Implement explicit enhanced request handlers.

    This section maps each request class to one ordinary controller boundary,
    trusted authority decision, reviewed query, and native equivalent.

    - [ ] 1.2.1 Task {#huid-p01-requests} [repo: jido_code] [after: {#huid-p01-signals}] - Implement filter, search, sort, pagination, and view handlers.

      This task prevents generic/catch-all hypermedia dispatch and preserves
      HTTP method, cache, privacy, and error semantics.

      - [ ] 1.2.1.1 Subtask - Add explicit routes/actions for each admitted read intent and map them to the same bounded view-model/query functions as native pages.
      - [ ] 1.2.1.2 Subtask - Reconstruct current trusted authority and canonical resource scope server-side; authorize before query and after field shaping.
      - [ ] 1.2.1.3 Subtask - Enforce GET safety, non-GET CSRF header/body, Origin/Fetch Metadata, same-origin content types, no-store/referrer/log policy, and rate limits.
      - [ ] 1.2.1.4 Subtask - Return safe native full-page fallback or explicit fragment/error response without hidden rows, optimistic state, or transport-specific truth.

  - [ ] 1.3 Section - Implement stable coherent fragment boundaries.

    This section updates the smallest complete authorized projection while
    preserving focus, navigation, overlays, and projection-state integrity.

    - [ ] 1.3.1 Task {#huid-p01-fragments} [repo: jido_code] [after: {#huid-p01-requests}] - Implement HEEx fragment renderers and patch metadata.

      This task renders fragments from the same typed view models as full pages
      and never accepts raw HTML or browser-authored state.

      - [ ] 1.3.1.1 Subtask - Register stable roots for attention, health, fleet, project summary/attempts/wiki/cost, attempt header/summary, session/account, and errors.
      - [ ] 1.3.1.2 Subtask - Render data, projection state, revision, freshness, provenance, truncation, readiness, redaction, and accessible status atomically per root.
      - [ ] 1.3.1.3 Subtask - Preserve focused form/input selection, open native dialog/disclosure, navigation, scroll/reading position, selected row/view, and explicit post-request focus.
      - [ ] 1.3.1.4 Subtask - Enforce HEEx escaping/sanitization, static Datastar expressions, HTTP CSP nonce mode, bounded patch bytes/root count, and no Dstar Scripts.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves signal/request/fragment behavior is bounded,
    authorized, native-equivalent, accessible, and safe under hostile input.

    - [ ] 1.4.1 Task {#huid-p01-integration} [repo: jido_code] [after: {#huid-p01-fragments}] - Execute the HUI-D1 request and fragment matrix.

      This task tests every schema/action/root and its native fallback in real
      browsers with production CSP/assets.

      - [ ] 1.4.1.1 Subtask - Exercise valid/default/unknown/duplicate/malformed/oversized/deep signal values, forbidden authority keys, scope switching, pagination/filter/search, and rate bounds.
      - [ ] 1.4.1.2 Subtask - Exercise CSRF/Origin/Fetch Metadata/content-type/method/CSP/injection/cache/referrer/log cases and exact authorization/redaction for each handler.
      - [ ] 1.4.1.3 Subtask - Exercise every fragment/projection state, unavailable/concealed row clearing, focus/selection/dialog/disclosure/scroll preservation, patch limit, and native full-page fallback.
      - [ ] 1.4.1.4 Subtask - Run parser/property/controller/browser/accessibility/security/architecture suites, `mix precommit`, and clean-checkout CI.

    - [ ] 1.4.2 Task {#huid-p01-phase-receipt} [repo: jido_code] [after: {#huid-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-D1 evidence in
      `docs/architecture/hypermedia-ui-milestone-d-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Keep HUI-D1 merge-pending on open/authority-bearing signals, generic handlers, CSRF/CSP bypass, unbounded patches, incoherent state, hidden-row retention, focus loss, or broken native parity.
      - [ ] 1.4.2.2 Subtask - Record schema/route/root/limit/CSP/browser evidence, failures, limitations, and all reopening conditions.
      - [ ] 1.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
