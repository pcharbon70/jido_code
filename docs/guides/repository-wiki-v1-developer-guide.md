# Repository Wiki Deterministic V1 Developer Guide

Repository Wiki is compiled knowledge backed by immutable per-edition graphs.
It is not a Markdown database, mutable browser cache, generic graph console,
or an agent-maintained authority plane. The TripleStore remains the only
application-owned durable store; worktrees, processes, queues, search indexes,
render caches, and preview artifacts are disposable.

## Compilation Contract

The deterministic pipeline admits an exact repository/source/enrollment
tuple, inventories bounded source and documentation, parses `mix.exs` without
evaluation, parses `mix.lock` without term decoding, reconciles dependency
evidence, discovers and safely renders authored guides, assembles canonical
pages, appends an exact edition, lints the closed graph, records explicit zero
model usage, and requests a separate reviewed activation.

Every stage carries repository, tenant, source revision, source fence,
enrollment revision, compiler/profile digest, attempt, lease, cancellation,
and expected graph revisions as applicable. A stale or competing tuple returns
stale/conflict evidence; it cannot silently continue on newer inputs.

## Adding Project Knowledge

- Put user, developer, contributor, operator, security, upgrade, release, and
  reference guides in the conventional root files, `docs`, or `guides` roots.
- Keep ADRs, architecture specifications, research, and implementation plans
  in their governed documentation areas. Accepted status comes from the
  existing review/governance boundary, not filename alone.
- Declare direct dependencies in `mix.exs` and commit `mix.lock`. The wiki
  retains both declaration and resolution provenance, all supported parents,
  and explicit gaps for dynamic, private, missing, or unsupported data.
- Do not add scripts, hooks, raw HTML, credentials, generated source dumps, or
  wiki instructions intended to control an agent. Repository text is quoted
  and attributable data only.

Generated wiki prose is never committed back as if repository-authored.
Documentation improvements follow the normal coding, review, verification,
publication, and merge workflow.

## Agent Context

The context source exposes only current, authorized, source-fenced fragments
from closed page classes. Direct accepted task/source constraints rank above
wiki material. Selection is bounded by one shared context budget, deduplicated
by source/digest relationships, and records page/edition/source provenance
without placing full page bodies in launch metadata or diagnostics.

Each compiled context is immutable for one actor, tenant, repository, task,
session, attempt, source, edition, and profile tuple. Preview context is not a
V1 mode. Activation, source drift, visibility change, cancellation, archive,
or profile change makes an old assembly stale rather than mixing editions.

## Qualification And Release

Release admission consumes a signed immutable corpus, expected graph/page/
usage oracles, component profiles, frozen clock, thresholds, security report,
quality report, and self-hosted `jido_code` pilot. Admission requires:

- all representative and adversarial scenarios and security invariants;
- zero critical and high findings and only documented bounded residual risk;
- complete dependency/page/provenance/link/lint/render dimensions;
- identical canonical graph/page digests across repeated clean-checkout,
  randomized-enumeration, restart, and supported-runtime runs;
- passing discoverability, navigation, tracing, dependency, gap, and bounded
  search tasks;
- no source, preview, session, repository, or tenant mixing; and
- inventory, parsing, graph, rendering, search, concurrency, storage, and
  recovery measurements under signed ceilings.

Evaluator output cannot waive a failed invariant. Changing ontology,
GraphRegistry, semantic/wiki protocol, compiler, parser, sandbox, metadata,
lint, renderer, corpus, oracle, clock, threshold, or pilot digest requires a
new qualification and release decision.

## V1 Catalog And Rollback

The V1 catalog contains only `manual_deterministic` and
`automatic_deterministic`; both require explicit per-repository enrollment.
The default remains Off. Provider, model, price, prompt, and production
synthesis-adapter catalogs are empty.

Rollback first blocks new work, then drains or fences maintainers. It preserves
the current-edition pointer, separately authorized retained reads, immutable
usage/accounting, and audit history. Rebuilding disposable projections cannot
repair or replace authoritative graph state.

Run `mix precommit` for changes. Repository-wiki-specific incidents and repair
procedures are in the [V1 operator runbook](../operations/repository-wiki-v1-runbook.md).

