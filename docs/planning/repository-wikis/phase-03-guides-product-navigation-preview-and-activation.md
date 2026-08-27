---
id: plan.jido_code_repository_wikis_phase_03
parent_plan: plan.jido_code_repository_wikis
status: approved
intent: feature
---

# Repository Wikis Phase 3 - Guides, Product Navigation, Preview, And Activation

This phase makes the deterministic wiki useful to developers and users. It
discovers and safely renders repository guides, classifies updates, exposes
reviewed navigation and search, isolates session previews, and activates only
an authorized, linted edition at the current repository source fence.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Deliver the reviewed deterministic wiki product and activation workflow.

  This phase proves RW3 by making guides, freshness, reads, previews, review,
  activation, and product navigation safe under parallel coding sessions.

  - [x] 3.1 Section - Discover and render user and developer guides safely.

    This section treats accepted repository documentation as source material,
    never as executable or trusted application markup.

    - [x] 3.1.1 Task {#rwi-p03-guide-discovery} [repo: jido_code] [after: {#rwi-p02-phase-receipt}] - Implement deterministic guide discovery and classification.

      This task finds configured and conventional guides within the registered
      repository root and assigns stable identities and audiences.

      - [x] 3.1.1.1 Subtask - Discover `README`, contribution, installation, deployment, operations, troubleshooting, API, usage, upgrade, security, architecture, and configured guide roots under fixed file/count/byte limits.
      - [x] 3.1.1.2 Subtask - Classify pages as user, developer, operator, contributor, reference, architecture, policy, or unknown using deterministic path/front-matter rules.
      - [x] 3.1.1.3 Subtask - Preserve source-relative path, revision, digest, media type, title evidence, audience evidence, order, freshness, and any ambiguous classification.
      - [x] 3.1.1.4 Subtask - Reject traversal, outside-root symlinks, device files, binaries, oversized inputs, unsupported encodings, and repository-selected parser extensions.
      - [x] 3.1.1.5 Subtask - Detect renames, additions, deletions, duplicates, title collisions, and moved anchors deterministically without relying on process-local history.

    - [x] 3.1.2 Task {#rwi-p03-guide-rendering} [repo: jido_code] [after: {#rwi-p03-guide-discovery}] - Extend `wiki-renderer/1.0.0` with safe guide rendering.

      This task renders useful documentation without admitting scripts, unsafe
      HTML, credential leaks, or privileged application navigation.

      - [x] 3.1.2.1 Subtask - Parse the supported Markdown subset under bounded depth, nodes, link count, code-block size, table size, and total output limits.
      - [x] 3.1.2.2 Subtask - Escape or remove raw HTML, scripts, event handlers, styles, embeds, forms, iframes, data URLs, dangerous schemes, and unsupported extensions.
      - [x] 3.1.2.3 Subtask - Rewrite relative guide, source, and image references through reviewed repository routes; preserve unresolved and external destinations with explicit status.
      - [x] 3.1.2.4 Subtask - Generate stable heading anchors, table-of-contents entries, source links, audience labels, freshness labels, and provenance panels.
      - [x] 3.1.2.5 Subtask - Scan rendered and source content for known credential forms and high-risk secrets, block unsafe activation, and retain only redacted diagnostics.

  - [x] 3.2 Section - Compile full deterministic editions and classify source updates.

    This section joins inventory, Mix/dependency knowledge, guides, and
    accepted architecture into one reproducible edition.

    - [x] 3.2.1 Task {#rwi-p03-full-compiler} [repo: jido_code] [after: {#rwi-p03-guide-rendering}] - Complete `wiki-deterministic-elixir/1.0.0` edition compilation.

      This task produces the entire navigable page graph with stable routes,
      backlinks, coverage, and provenance.

      - [x] 3.2.1.1 Subtask - Compile Overview, Getting Started, User Guides, Developer Guides, Architecture, Source Map, Project, Dependencies, Operations, Provenance, Freshness, and Known Gaps collections.
      - [x] 3.2.1.2 Subtask - Generate stable slugs, hierarchy, navigation order, cross-links, backlinks, audience labels, source links, and section summaries from deterministic inputs.
      - [x] 3.2.1.3 Subtask - Represent source conflicts, missing inputs, stale metadata, unresolved Mix facts, broken links, and unsupported guide content as visible bounded gaps.
      - [x] 3.2.1.4 Subtask - Compute edition content, page graph, navigation, source coverage, and render digests so identical admitted inputs produce byte-stable results.
      - [x] 3.2.1.5 Subtask - Attach an explicit zero-token usage record and all compiler, parser, renderer, resolver, metadata, policy, and source-profile identities.

    - [x] 3.2.2 Task {#rwi-p03-update-classifier} [repo: jido_code] [after: {#rwi-p03-full-compiler}] - Implement deterministic update classification and staleness.

      This task decides whether an accepted repository change requires no
      action, a page rebuild, a full rebuild, or explicit degraded status.

      - [x] 3.2.2.1 Subtask - Classify source, manifest, lock, guide, accepted-document, policy, compiler, renderer, metadata, and graph-contract changes from immutable before/after digests.
      - [x] 3.2.2.2 Subtask - Map classifications to `no_change`, `metadata_refresh`, `targeted_rebuild`, `full_rebuild`, `stale_only`, or `unsupported` with deterministic reasons.
      - [x] 3.2.2.3 Subtask - Record change trigger, causal revisions, affected page identities, requested profile, priority, and coalescing identity without trusting session-local diffs.
      - [x] 3.2.2.4 Subtask - Mark the current edition stale when authoritative source or accepted compiler policy advances, while keeping the previous edition readable under configured policy.
      - [x] 3.2.2.5 Subtask - Fence classifications and scheduled work to exact enrollment, source, compiler, and policy revisions so later changes force reclassification.

  - [x] 3.3 Section - Expose reviewed wiki reads, search, and repository navigation.

    This section gives people a coherent wiki product without exposing raw
    graph access or introducing another authorization model.

    - [x] 3.3.1 Task {#rwi-p03-reviewed-reads} [repo: jido_code] [after: {#rwi-p03-update-classifier}] - Implement bounded current-edition reads and deterministic search.

      This task serves only an authorized current or explicitly selected
      preview edition through semantic query gateways.

      - [x] 3.3.1.1 Subtask - Add reviewed queries for navigation tree, page by stable slug, backlinks, source references, dependency lookup, guide collections, edition status, and known gaps.
      - [x] 3.3.1.2 Subtask - Build disposable per-edition search indexes from accepted page fields with deterministic tokenization, bounded query syntax, ranking, limits, and snippets.
      - [x] 3.3.1.3 Subtask - Authorize every read by actor, tenant, repository, enrollment visibility, edition or preview scope, and retained-read policy.
      - [x] 3.3.1.4 Subtask - Reject raw SPARQL, graph IRIs, arbitrary predicates, cross-edition joins, unbounded search, hidden previews, and stale opaque references.
      - [x] 3.3.1.5 Subtask - Rebuild search and navigation projections from graph state after restart and prove neither projection is durable authority.

    - [x] 3.3.2 Task {#rwi-p03-product} [repo: jido_code] [after: {#rwi-p03-reviewed-reads}] - Add repository wiki navigation, status, and settings to the authenticated product.

      This task gives users one repository-scoped entry point for current
      knowledge, enrollment, freshness, history, and generation controls.

      - [x] 3.3.2.1 Subtask - Add a Wiki destination to the existing repository navigation only when the current actor has retained-read permission and the repository policy permits visibility.
      - [x] 3.3.2.2 Subtask - Add Overview, Guides, Architecture, Project, Dependencies, Source, Search, History, and Known Gaps views using the same reviewed query gateway.
      - [x] 3.3.2.3 Subtask - Display current source revision, edition revision, freshness, compiler profile, generation mode, zero-token usage, degraded coverage, and last successful update.
      - [x] 3.3.2.4 Subtask - Add authorized settings for Off, Manual, and Automatic deterministic enrollment, retained reads, retention, and deterministic regeneration with explicit cost posture.
      - [x] 3.3.2.5 Subtask - Provide accessible loading, empty, disabled, stale, failed, rebuilding, preview, and current states with stable DOM identifiers and responsive navigation.

  - [x] 3.4 Section - Isolate previews, review editions, and serialize activation.

    This section lets multiple coding sessions prepare wiki candidates without
    letting a preview or stale session replace the repository's current wiki.

    - [x] 3.4.1 Task {#rwi-p03-previews} [repo: jido_code] [after: {#rwi-p03-product}] - Implement session-scoped preview editions.

      This task binds every preview to one actor, repository, source snapshot,
      session, generation attempt, and expiration policy.

      - [x] 3.4.1.1 Subtask - Create opaque preview references bound to actor, tenant, repository, session, source revision, compiler profile, attempt, and expiration.
      - [x] 3.4.1.2 Subtask - Store preview graph facts in the repository wiki family with explicit noncurrent state and isolate disposable render/search caches by preview identity.
      - [x] 3.4.1.3 Subtask - Permit only authorized session participants and reviewers to read a preview; prevent navigation, search, logs, and cache keys from disclosing another preview.
      - [x] 3.4.1.4 Subtask - Expire, invalidate, or retain previews according to policy after source drift, session closure, rejection, enrollment disable, or time limit.
      - [x] 3.4.1.5 Subtask - Ensure previews never become agent context, product current state, or activation candidates without an explicit reviewed transition.

    - [x] 3.4.2 Task {#rwi-p03-activation} [repo: jido_code] [after: {#rwi-p03-previews}] - Implement review, qualification, and current-edition activation.

      This task makes current-edition replacement a single graph-authorized,
      compare-and-swap transition after deterministic qualification.

      - [x] 3.4.2.1 Subtask - Record reviewer decision, lint profile/result, render profile/result, source coverage, blocking warnings, policy revision, and review provenance.
      - [x] 3.4.2.2 Subtask - Require finalized immutable content, passing blocking lint/render checks, current enrollment, allowed profile, current source fence, and exact expected current-edition revision.
      - [x] 3.4.2.3 Subtask - Atomically supersede the old current edition and activate the new edition; return stable stale, competing, disabled, unqualified, duplicate, and unauthorized outcomes.
      - [x] 3.4.2.4 Subtask - Reject late activation after source, enrollment, policy, compiler, reviewer authority, or current-edition drift while retaining attributable candidate history.
      - [x] 3.4.2.5 Subtask - Invalidate and rebuild disposable navigation/search caches only after the activation commit is accepted.

    - [x] 3.4.3 Task {#rwi-p03-history-retention} [repo: jido_code] [after: {#rwi-p03-activation}] - Expose bounded edition history and enforce preview/current retention.

      This task lets readers understand changes and provenance without keeping
      every disposable artifact forever.

      - [x] 3.4.3.1 Subtask - Add reviewed history and comparison queries over stable page, source, dependency, coverage, compiler, trigger, usage, and review facts.
      - [x] 3.4.3.2 Subtask - Enforce separate retention for current, superseded, rejected, invalid, expired preview, render artifact, source snapshot, and audit records.
      - [x] 3.4.3.3 Subtask - Delete or compact only policy-authorized disposable artifacts while keeping immutable lineage, activation, usage, and audit evidence.
      - [x] 3.4.3.4 Subtask - Prove retained history remains repository-scoped and cannot restore a stale edition to current status without a new qualified activation.

  - [ ] 3.5 Section - Phase 3 Integration Tests.

    This final section proves the deterministic wiki is useful, safely
    rendered, reviewed, and correct under competing session previews.

    - [ ] 3.5.1 Task {#rwi-p03-integration} [repo: jido_code] [after: {#rwi-p03-history-retention}] - Execute the RW3 guides, product, preview, and activation matrix.

      This task closes RW3 only when users see a coherent current wiki and no
      preview, unsafe guide, or stale writer can become current.

      - [x] 3.5.1.1 Subtask - Exercise guide discovery, audience classification, renames, duplicates, hostile Markdown/HTML, unsafe links, secret-like content, Unicode, broken anchors, and rendering bounds.
      - [x] 3.5.1.2 Subtask - Exercise deterministic full compilation, targeted/full update classification, no-op changes, staleness, metadata refresh, compiler drift, and byte-stable replay.
      - [x] 3.5.1.3 Subtask - Exercise product authorization, disabled/empty/stale/failure states, search bounds, navigation, source/dependency routes, history, and accessibility using LiveView selectors.
      - [x] 3.5.1.4 Subtask - Race parallel same-repository previews, independent repositories, duplicate review, source drift, opt-out, expiry, activation compare-and-swap, and late results.
      - [x] 3.5.1.5 Subtask - Prove one current edition, preview isolation, safe cache invalidation, zero-token evidence, retained audit lineage, and graph-only projection rebuild.
      - [ ] 3.5.1.6 Subtask - Rerun RW1-RW2 and applicable product/security suites, then run architecture checks, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [ ] 3.5.2 Task {#rwi-p03-phase-receipt} [repo: jido_code] [after: {#rwi-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records RW3 evidence in
      `docs/architecture/repository-wiki-phase-03-receipt.md`.

      - [x] 3.5.2.1 Subtask - Record guide, renderer, compiler, classifier, query, search, product, preview, lint, activation, retention, and fixture revisions and digests.
      - [x] 3.5.2.2 Subtask - Keep RW3 open if unsafe repository markup executes, hidden previews leak, a preview enters agent/current reads, or activation succeeds after any required fence drifts.
      - [ ] 3.5.2.3 Subtask - Preserve every gate reopening condition and attach guide safety, deterministic replay, product, concurrency, activation, retention, precommit, Dialyzer, and clean-checkout evidence.
      - [ ] 3.5.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, final Phase 3 Integration Tests section, receipt task, and pinning checkboxes before authorizing Phase 4.
