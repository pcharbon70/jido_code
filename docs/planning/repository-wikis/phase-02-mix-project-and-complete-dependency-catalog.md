---
id: plan.jido_code_repository_wikis_phase_02
parent_plan: plan.jido_code_repository_wikis
status: approved
intent: feature
---

# Repository Wikis Phase 2 - Mix Project And Complete Dependency Catalog

This phase compiles trustworthy Elixir project identity and a complete resolved
dependency catalog from `mix.exs`, `mix.lock`, bounded sandbox introspection,
and cached Hex metadata. It distinguishes extracted, observed, verified,
missing, and unresolved facts instead of presenting guesses as repository
truth.

Back to plan: [README](./README.md)

- [x] 2 Phase - Compile Mix project identity and the complete dependency closure.

  This phase proves RW2 by combining safe static extraction, fixed sandbox
  escalation, lock resolution, closed Req metadata lookup, provenance, and
  deterministic dependency pages.

  - [x] 2.1 Section - Extract project and lock facts without executing repository code.

    This section makes ordinary Mix inventory deterministic and safe for
    untrusted or malformed repositories.

    - [x] 2.1.1 Task {#rwi-p02-static-mix} [repo: jido_code] [after: {#rwi-p01-phase-receipt}] - Implement `mix-static/1.0.0` project extraction.

      This task parses the project definition as data and emits facts only
      when the accepted syntax proves their values.

      - [x] 2.1.1.1 Subtask - Parse bounded `mix.exs` source into an AST without loading, compiling, macro-expanding, or evaluating repository modules.
      - [x] 2.1.1.2 Subtask - Extract literal application name, version, Elixir requirement, application settings, aliases, source paths, preferred CLI environment, and dependency declarations.
      - [x] 2.1.1.3 Subtask - Preserve dependency requirement, options, declaration location, directness, environment scopes, optionality, override, runtime, path, git, branch, tag, ref, and sparse values.
      - [x] 2.1.1.4 Subtask - Classify functions, macros, imports, conditionals, concatenation, environment reads, and other dynamic expressions as unresolved static facts with source locations.
      - [x] 2.1.1.5 Subtask - Produce canonical, deterministically ordered extraction output with parser profile, source digest, diagnostics, coverage, and zero-token usage.

    - [x] 2.1.2 Task {#rwi-p02-lock} [repo: jido_code] [after: {#rwi-p02-static-mix}] - Implement bounded `mix.lock` parsing and integrity evidence.

      This task reads resolved lock entries without converting arbitrary input
      into atoms or executable terms.

      - [x] 2.1.2.1 Subtask - Parse the supported literal lock format under fixed byte, node, depth, string, tuple, and collection bounds without evaluating arbitrary Elixir.
      - [x] 2.1.2.2 Subtask - Extract Hex, git, path, and supported SCM identities, resolved versions or revisions, checksums, managers, dependency edges, repository names, and source options.
      - [x] 2.1.2.3 Subtask - Preserve unknown or future lock shapes as explicit unsupported entries with source digest and bounded diagnostics instead of dropping them.
      - [x] 2.1.2.4 Subtask - Verify lock source digest, parser profile, checksum syntax, duplicate keys, conflicting identities, and deterministic canonical ordering.
      - [x] 2.1.2.5 Subtask - Reject atom exhaustion, term decoding, code loading, path traversal, remote lookup, and any repository-controlled parser extension.

  - [x] 2.2 Section - Escalate unresolved Mix facts through one fixed sandbox profile.

    This section permits bounded observation only when static extraction is
    insufficient and current enrollment explicitly allows the profile.

    - [x] 2.2.1 Task {#rwi-p02-mix-sandbox} [repo: jido_code] [after: {#rwi-p02-lock}] - Implement `mix-sandbox/1.0.0` introspection.

      This task runs a controller-owned introspector through the existing
      harness while denying repository-selected launch behavior.

      - [x] 2.2.1.1 Subtask - Register one immutable executable, argument, environment, filesystem, timeout, CPU, memory, output, and process-count profile for Mix introspection.
      - [x] 2.2.1.2 Subtask - Mount an immutable source snapshot and disposable build/cache directories; deny credentials, user configuration, project-local tools, hooks, shells, and unrelated host paths.
      - [x] 2.2.1.3 Subtask - Disable network access and dependency fetching; require dependencies and toolchain components to resolve only from controller-approved immutable inputs.
      - [x] 2.2.1.4 Subtask - Return a bounded controller-defined schema for observed project and dependency facts, diagnostics, profile digest, source digest, exit status, truncation, and resource usage.
      - [x] 2.2.1.5 Subtask - Admit sandbox escalation only for unresolved required facts, label all results `observed`, and retain static conflicts rather than silently replacing them.

    - [x] 2.2.2 Task {#rwi-p02-mix-reconciliation} [repo: jido_code] [after: {#rwi-p02-mix-sandbox}] - Reconcile declared, locked, observed, and accepted project facts.

      This task creates one provenance-bearing project model without
      flattening disagreements between sources.

      - [x] 2.2.2.1 Subtask - Define precedence and coexistence rules for literal declarations, lock entries, sandbox observations, accepted graph facts, and missing inputs.
      - [x] 2.2.2.2 Subtask - Record every value with source kind, source location, revision, extractor or observer profile, confidence, freshness, and conflict state.
      - [x] 2.2.2.3 Subtask - Mark dynamic, incomplete, conflicting, stale, unsupported, and unavailable facts as explicit coverage gaps surfaced by lint and product reads.
      - [x] 2.2.2.4 Subtask - Fence reconciliation to exact source, toolchain, parser, sandbox, and policy revisions so late observations cannot enter a newer edition.

  - [x] 2.3 Section - Resolve the complete dependency graph and special source classes.

    This section ensures the wiki represents the full resolved closure rather
    than only the direct dependencies visible in `mix.exs`.

    - [x] 2.3.1 Task {#rwi-p02-dependency-resolver} [repo: jido_code] [after: {#rwi-p02-mix-reconciliation}] - Build the complete dependency resolver.

      This task correlates declarations, lock entries, and resolved edges into
      stable dependency identities and paths.

      - [x] 2.3.1.1 Subtask - Create stable dependency resources for every direct and transitive node with package or source identity, selected version/revision, managers, scopes, optionality, and provenance.
      - [x] 2.3.1.2 Subtask - Build directed dependency edges from lock evidence, retain all parents, compute roots and bounded paths, and detect cycles without recursive explosion.
      - [x] 2.3.1.3 Subtask - Distinguish declared-only, locked-only, resolved, missing-lock, orphaned-lock, conflicting, unsupported, and unverifiable dependencies.
      - [x] 2.3.1.4 Subtask - Verify every resolved lock node is represented exactly once in the catalog and every supported edge terminates in a represented node.
      - [x] 2.3.1.5 Subtask - Emit deterministic counts, completeness evidence, graph digest, maximum-depth observations, and bounded gap summaries.

    - [x] 2.3.2 Task {#rwi-p02-special-dependencies} [repo: jido_code] [after: {#rwi-p02-dependency-resolver}] - Handle path, git, optional, override, and mixed-manager dependencies.

      This task gives non-Hex dependencies truthful pages and links without
      assuming registry metadata or unsafe local reachability.

      - [x] 2.3.2.1 Subtask - Normalize git URLs and immutable revisions for display while redacting credentials, embedded tokens, unsafe schemes, and private endpoint details.
      - [x] 2.3.2.2 Subtask - Resolve path dependencies only inside registered repository/workspace envelopes and record outside-root or missing paths as unavailable.
      - [x] 2.3.2.3 Subtask - Preserve optional, override, runtime, environment, manager, umbrella, sparse, branch, tag, ref, and subdirectory semantics in nodes and edges.
      - [x] 2.3.2.4 Subtask - Avoid external links for private, ambiguous, moving, unsupported, or unverified sources and surface the reason in the dependency page.

  - [x] 2.4 Section - Enrich public dependencies through bounded Req metadata lookup.

    This section adds useful general package information while keeping remote
    metadata observational, cached, attributable, and non-authoritative.

    - [x] 2.4.1 Task {#rwi-p02-hex-metadata} [repo: jido_code] [after: {#rwi-p02-special-dependencies}] - Implement `hex-req/1.0.0` metadata acquisition.

      This task uses the existing Req client and closed endpoint registry to
      fetch bounded metadata for eligible public Hex packages.

      - [x] 2.4.1.1 Subtask - Register exact HTTPS origins, routes, request headers, redirects, TLS policy, timeouts, response limits, retry policy, concurrency, and cache behavior.
      - [x] 2.4.1.2 Subtask - Fetch package and exact release metadata with Req; capture request profile, endpoint identity, status, validators, retrieval time, body digest, and parse diagnostics.
      - [x] 2.4.1.3 Subtask - Parse bounded summary, licenses, maintainers, links, retirement, release date, requirements, and checksum fields without interpreting remote HTML or executable content.
      - [x] 2.4.1.4 Subtask - Implement immutable fixture replay and positive/negative cache entries with TTL, stale-if-error display, rate-limit handling, and no live-network dependency in ordinary CI.
      - [x] 2.4.1.5 Subtask - Label remote data as observed metadata, preserve unavailable/stale states, and prevent it from overriding project or lock truth.

    - [x] 2.4.2 Task {#rwi-p02-dependency-links} [repo: jido_code] [after: {#rwi-p02-hex-metadata}] - Produce safe verified dependency links.

      This task exposes useful package, documentation, source, and license
      destinations only after deterministic validation.

      - [x] 2.4.2.1 Subtask - Generate Hex package/release and HexDocs version links from verified public package identity and resolved version.
      - [x] 2.4.2.2 Subtask - Validate remote-provided source, homepage, changelog, and license links against scheme, length, control-character, credential, and display-text policy.
      - [x] 2.4.2.3 Subtask - Record link kind, origin, verification state, retrieval time, and provenance; render unverified values as text rather than clickable destinations.
      - [x] 2.4.2.4 Subtask - Prevent link redirects, Unicode lookalikes, encoded credentials, or repository content from creating privileged or application-internal navigation.

  - [x] 2.5 Section - Compile and qualify deterministic Mix and dependency pages.

    This section turns reconciled facts into stable wiki navigation with
    completeness and provenance visible to readers.

    - [x] 2.5.1 Task {#rwi-p02-dependency-pages} [repo: jido_code] [after: {#rwi-p02-dependency-links}] - Extend the deterministic compiler with project and dependency pages.

      This task publishes project identity, dependency summaries, and one
      detail page per resolved or explicitly unresolved dependency.

      - [x] 2.5.1.1 Subtask - Compile Project, Runtime Requirements, Dependency Overview, Direct Dependencies, Transitive Dependencies, Dependency Gaps, and metadata freshness pages.
      - [x] 2.5.1.2 Subtask - Compile stable per-dependency pages with general information, declared/locked/observed facts, incoming/outgoing edges, paths from roots, scopes, provenance, and safe links.
      - [x] 2.5.1.3 Subtask - Show complete node/edge counts, unsupported entries, metadata availability, source conflicts, and coverage warnings without hiding degraded results.
      - [x] 2.5.1.4 Subtask - Keep page ordering, anchors, slugs, link selection, tables, and text deterministic across identical inputs.
      - [x] 2.5.1.5 Subtask - Emit explicit zero model-token usage and exact parser, sandbox, resolver, metadata-fixture, compiler, and source digests for the edition.

    - [x] 2.5.2 Task {#rwi-p02-dependency-lint} [repo: jido_code] [after: {#rwi-p02-dependency-pages}] - Extend `wiki-lint/1.0.0` for Mix and dependency completeness.

      This task blocks activation when supported dependency truth is omitted,
      misrepresented, untraceable, or linked unsafely.

      - [x] 2.5.2.1 Subtask - Require project-source provenance and a catalog node for every supported lock entry and declaration.
      - [x] 2.5.2.2 Subtask - Require all supported dependency edges, stable identities, unique pages, bounded paths, and explicit classifications for unresolved inputs.
      - [x] 2.5.2.3 Subtask - Reject unsafe links, missing source labels, silent static/sandbox conflicts, remote metadata represented as authoritative, and nondeterministic output.
      - [x] 2.5.2.4 Subtask - Produce machine-readable blocking errors, nonblocking warnings, coverage metrics, and a lint-profile digest attached to the edition.

  - [x] 2.6 Section - Phase 2 Integration Tests.

    This final section proves Mix and dependency knowledge is complete,
    bounded, deterministic, safe, and honest about uncertainty.

    - [x] 2.6.1 Task {#rwi-p02-integration} [repo: jido_code] [after: {#rwi-p02-dependency-lint}] - Execute the RW2 extraction, resolution, metadata, and rendering matrix.

      This task closes RW2 only when all supported lock nodes and edges appear
      in the wiki and no extraction path grants repository code authority.

      - [x] 2.6.1.1 Subtask - Exercise literal, dynamic, malformed, hostile, oversized, Unicode, umbrella, missing-lock, future-lock, and changing-source Mix fixtures.
      - [x] 2.6.1.2 Subtask - Exercise sandbox admission, denial, limits, network isolation, credential isolation, timeout, truncation, crash, source drift, and conflicting observations through the real harness seam.
      - [x] 2.6.1.3 Subtask - Exercise direct, transitive, cyclic, optional, override, path, git, mixed-manager, missing, orphaned, private, and unsupported dependency graphs.
      - [x] 2.6.1.4 Subtask - Exercise Req success, redirect, TLS failure, timeout, rate limit, malformed JSON, oversized bodies, cache revalidation, stale fallback, unsafe links, and fixture replay.
      - [x] 2.6.1.5 Subtask - Prove deterministic editions, exact lock closure, zero-token evidence, safe links, graph/source fencing, and no cross-repository cache disclosure.
      - [x] 2.6.1.6 Subtask - Rerun RW1 and applicable harness/security suites, then run architecture checks, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [x] 2.6.2 Task {#rwi-p02-phase-receipt} [repo: jido_code] [after: {#rwi-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records RW2 evidence in
      `docs/architecture/repository-wiki-phase-02-receipt.md`.

      - [x] 2.6.2.1 Subtask - Record parser, lock, sandbox, resolver, Req, cache, compiler, lint, fixture, source, and protocol revisions and digests.
      - [x] 2.6.2.2 Subtask - Keep RW2 open if repository code escapes the fixed sandbox, any supported lock node or edge is omitted, metadata overrides source truth, or an unsafe/unverified link becomes clickable.
      - [x] 2.6.2.3 Subtask - Preserve every gate reopening condition and attach extraction, containment, completeness, metadata, rendering, precommit, Dialyzer, and clean-checkout evidence.
      - [x] 2.6.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, final Phase 2 Integration Tests section, receipt task, and pinning checkboxes before authorizing Phase 3.
