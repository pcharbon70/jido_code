# Hypermedia UI Validation And Release Evidence Contract

- Status: Accepted architecture contract; evidence execution remains gated by
  each owning milestone
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode architecture, release, quality, security, accessibility,
  product, web, operations, identity, Knowledge, Factory, and documentation
  maintainers
- Machine contract:
  [`phase_a3_evidence_contract.json`](../../priv/architecture/hypermedia_ui/phase_a3_evidence_contract.json)

## Purpose And Evidence Posture

This contract defines the reproducible proof required for Milestones B through
H. A mock, screenshot, passing status badge, unchecked prose claim, or result
from a different dependency/profile/candidate cannot replace evidence for the
exact qualified seam. Architecture-only evidence proves contract consistency,
not runtime availability.

Every gate evaluates one immutable candidate and records limitations and
reopening conditions. Failed or missing mandatory evidence keeps the gate open;
a reviewer cannot waive a zero-tolerance invariant by relabeling the result.

## Evidence Classes

The machine contract defines thirteen mandatory classes:

- unit: deterministic isolated semantics and fail-closed edge cases;
- integration: real application boundaries and durable protocol composition;
- browser: supported engines, native fallback, focus, navigation, several
  tabs, reconnect, and rendered outcomes;
- accessibility: keyboard, screen reader/assistive technology, zoom/reflow,
  forced colors, reduced motion, RTL, semantics, and announcements;
- security: hostile input, identity/scope/classification, CSRF/CSP, revocation,
  concealment, approval, export, incident, and supply-chain cases;
- usability: representative human tasks, comprehension, recovery, interruption,
  parallel resumption, and current-capability honesty;
- load: bounded connections, queues, patches, queries, tables, expansions,
  concurrency, resource use, and backpressure;
- fault: drop, duplicate, reorder, disconnect, crash, restart, outage,
  ambiguity, stale fence, partial deploy, and cleanup;
- real-adapter: the exact external dependency, identity, store, command,
  filesystem, network, provider, or runtime seam selected for release;
- install: pristine build/config/bootstrap/start and local immutable assets;
- upgrade: supported predecessor, migration order, compatibility, rebuild, and
  current projection verification;
- rollback: last qualified route/dependency/asset/config artifact, in-flight
  work, open streams, protocol readers, and authoritative-state preservation;
  and
- observation: the declared post-deploy window, SLOs, incidents, regressions,
  capability truth, consumer inventory, and removal readiness.

Each class has a named owner and independent reviewer class. Required real
seams cannot be satisfied by a fake. A deterministic fake remains useful for
failure coverage but is labeled supplemental.

## Immutable Candidate And Environment Identity

Every evidence manifest records the full Git commit and tree, PR, merge state,
toolchain, dependency/lock, source/archive, asset, configuration, browser,
assistive-technology, proxy, fixture/corpus, schema/ontology/query/command, and
adapter/profile digests that affect the result. SHA-256 is the default artifact
digest; Git objects retain their native full object identity as well.

Clocks, identifiers, random seeds, order, locale, timezone, test accounts,
repositories, revisions, graph state, policy revisions, session generations,
and network/fault schedules are fixed or captured. Production-time and random
adapters may be exercised only when their exact observations and uncertainty
are retained. Secret values, credentials, prompts, private reasoning, and raw
sensitive content never enter an evidence artifact.

The manifest records exact commands, exit results, counts, durations,
artifact references and digests, reviewers, limitations, failures, waivers
that do not cross zero-tolerance rules, retention class, and every reopening
condition. Screenshots and recordings are supporting artifacts only; semantic
assertions and machine results remain primary.

## Required Real Seams

Release qualification must include the exact selected TripleStore/native
backend, identity/authenticator and revocation adapter, isolated filesystem and
workspace behavior, semantic command/receipt path, network/provider adapter,
supported browsers, assistive technology, TLS/reverse proxy, and install/
upgrade/rollback environment. In-memory, fake, or simulated coverage cannot
replace them.

The owning milestone may use mocks before a real seam is selected, but its
receipt must say `contract_only` or `unavailable`. Real-adapter evidence from a
different version, configuration, deployment/authentication class, provider,
browser, proxy, repository corpus, or candidate does not transfer.

## Review And Retention

The evidence-class owner prepares results; the named independent reviewer
validates manifests, failures, limitations, and applicability. Security and
privacy require security review, accessibility requires an accessibility
reviewer, usability requires a product/research reviewer, runtime/fault/load
requires operations, and install/upgrade/rollback requires release/operations.
The author alone cannot satisfy an independent review requirement.

Receipts, manifests, digest indexes, reviewer decisions, and reopening
conditions remain in the repository for its lifetime. Release, security,
accessibility, real-adapter, install, upgrade, rollback, and observation
artifacts remain available for the supported release plus its rollback horizon
and at least one year. Bounded raw CI/browser/proxy traces remain for 90 days
unless an incident/legal hold requires longer; their durable manifest and
digest remain. Prohibited sensitive material is not retained at all.

## Receipt State Machine And Closure

An implementation PR publishes a `merge-pending` receipt with the exact
section commits, candidate commit, evidence digests, CI status, limits, and all
reopening conditions. It must not guess a merge commit or check closure boxes.
After clean-checkout CI passes and the implementation PR merges, a closure
change records the full merge-commit SHA and merge date and transitions the
receipt to `accepted-at-merged-candidate`.

The closure transition is coherent only when it also changes the phase plan
front matter from `proposed` to `completed` and checks exactly the phase-level
checkbox, final `Phase N Integration Tests` section checkbox, phase-receipt
task checkbox, and `Pin the merged candidate commit` subtask. In HUI-A3 these
are 3, 3.4, 3.4.2, and 3.4.2.3. Mixed state fails closed. Completed wording or
checked boxes never substitutes for the exact merged candidate.

The closure change preserves every reopening condition verbatim. A gate
reopens whenever any listed invariant fails, regardless of receipt state or
checkboxes.

## Acceptance And Reopening

This evidence contract reopens if a mandatory class or real seam disappears;
identity or digest coverage narrows; clocks/IDs/fixtures become uncontrolled;
evidence transfers across an incompatible qualification unit; a mock,
screenshot, badge, or prose claim replaces machine/real proof; reviewer
independence weakens; retention loses durable provenance; a receipt accepts an
unmerged or different candidate; closure state is mixed; reopening conditions
are changed or deleted; or clean-checkout CI fails at the exact candidate.
