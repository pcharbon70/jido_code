# Repository Wiki Compilation And Update Protocol

- Status: Approved and normative under accepted ADRs 0005, 0006, and 0007
- Specification version: `0.1.0`
- Owners: JidoCode knowledge, source-analysis, and documentation maintainers
- Decisions:
  [ADR 0005](../adr/0005-repository-wikis-as-compiled-knowledge-projections.md),
  [ADR 0006](../adr/0006-per-repository-wiki-maintainer-agents.md), and
  [ADR 0007](../adr/0007-repository-wiki-enrollment-and-cost-governance.md)
- Graph contract: [Repository wiki graph and edition](./repository-wiki-graph-and-edition-contract.md)
- Dependency contract: [Repository wiki Mix project and dependency catalog](./repository-wiki-mix-project-and-dependency-catalog.md)
- Enrollment and cost contract: [Repository wiki enrollment, budget, and accounting](./repository-wiki-enrollment-budget-and-accounting.md)

## Purpose

This specification defines how exact repository and graph inputs become a
repository wiki edition, which changes trigger maintenance, when a private
preview may exist, when current presentation may advance, and how drift or
failure is recovered.

Compilation is a governed pipeline, not an unconstrained agent conversation.
Deterministic inventory and extraction happen first. Optional model synthesis
can explain admitted facts but cannot select authority, fabricate missing
documentation, change source, or activate output.

## Authority And Precedence

When inputs overlap or disagree, the compiler preserves the following
authority classes and precedence. A later class may explain an earlier class
but does not replace it.

1. **Exact Git snapshot** — source code, tests, repository-authored docs,
   `mix.exs`, and `mix.lock` at the admitted object.
2. **Deterministic source and build observations** — pinned parser, Mix
   introspection, provider, and metadata observations with exact provenance.
3. **Governed graph facts** — accepted repository control, work, execution,
   evidence, decision, and adopted-memory projections at pinned revisions.
4. **External reference observations** — allowlisted package, docs, source,
   issue, changelog, and advisory metadata with observation time and expiry.
5. **Synthesized explanation** — bounded cited prose under an exact model and
   prompt profile.
6. **Live panels** — current reviewed-query results evaluated when a page is
   viewed; never copied into durable prose as if current forever.

A conflict becomes an explicit contradiction or drift finding. The compiler
does not resolve it by source order, majority vote, model preference, or the
previous wiki's wording.

## Compilation Request

A `WikiCompilationRequest` is durable graph state. It binds:

- request, repository, wiki, actor, tenant, purpose, and priority class;
- originating coding session/attempt, candidate, audience, and session-local
  fence for preview mode, with explicit absence for current-source mode;
- exact target Git snapshot or candidate manifest;
- exact admitted graph input revisions and source-analysis profile;
- compiler, page schema, renderer, redaction, link, metadata, and lint
  profiles;
- optional maintainer and synthesis profile;
- exact repository wiki configuration, generation/pricing profiles, budget
  accounts/windows, and accounting policy;
- expected active edition and predecessor;
- requested page scope: `full`, `deterministic_refresh`, or a closed targeted
  class;
- finite file, byte, page, dependency, citation, segment, token, time,
  sandbox, metadata, and cost bounds;
- lease/fence requirements, idempotency identity, cause, and deadline; and
- private-preview or current-source visibility.

Current-source requests are coalescible only when their authority-bearing
inputs match. A request for a newer source snapshot may supersede an
unactivated ordinary compile. Candidate-preview requests are never
semantically coalesced across coding sessions, attempts, candidates, fences,
or audiences, even when their base revision matches. A required release
edition and every exact candidate preview remain separate.

## Compiler Stages

### 1. Admit And Freeze

The coordinator reauthorizes the request and freezes the input manifest at one
evaluated dataset revision. It rejects a missing repository, unauthorized
scope, unsupported toolchain, stale control head, revoked profile, expired
lease, nonpositive fence, incompatible contract, or unknown source identity
before repository content is opened.

It also rejects missing/disabled wiki configuration, an automatic request
under manual mode, a preview under preview-disabled mode, synthesis under
deterministic-only mode, stale pricing, or an incompatible budget/accounting
profile. Repository enrollment and an existing readable edition are not
creation authority.

### 2. Acquire Exact Source

The source adapter creates or reuses only an exact disposable checkout for the
admitted Git object. It verifies object and tree identity, repository scope,
symlink policy, file bounds, and dirty-state absence. Candidate mode uses the
immutable candidate manifest and never labels it current.

The checkout, cache, ASTs, build files, and rendered documents are disposable.
They are not durable wiki state.

### 3. Deterministic Inventory

The inventory pass classifies bounded paths without executing repository code.
It records:

- root project files and supported umbrella applications;
- source, test, configuration, asset, migration, and operations areas;
- authored README, guide, ADR, research, contributing, changelog, release,
  security, upgrade, and license documents;
- existing source-graph coverage and warnings;
- `mix.exs`, `mix.lock`, toolchain declarations, and dependency inputs;
- file/path/digest identities and omission reasons; and
- sensitive, generated, vendored, unsupported, symlinked, oversized, or
  unauthorized classifications.

Inventory output is deterministic under the same profile and tree. Missing
expected documentation creates a `WikiGap`; it never causes the compiler to
invent an authored guide.

### 4. Extract Project And Dependencies

The compiler applies the dedicated Mix contract. Static AST inspection is the
default and executes no repository expression. When the static result cannot
establish admitted fields, an authorized production sandbox may run the fixed
introspection operation under a pinned toolchain and denied network. The host
never evaluates an untrusted `mix.exs`.

All results retain static, locked, resolved, external-observation, unsupported,
or unavailable provenance.

### 5. Assemble Deterministic Pages

The compiler produces canonical page manifests and deterministic sections for
project overview, navigation, source areas, modules, tests, dependency index,
individual dependencies, guide index, ADR index, release/reference material,
known gaps, and about-this-wiki.

It retrieves authored guide content only through the exact bounded source-
content adapter or verified artifact boundary. It never rewrites that content
inside the generated section.

### 6. Build Citation-First Context

Before optional synthesis, the compiler selects a bounded context package per
section. It contains only:

- section purpose and closed output schema;
- exact cited facts and authorized excerpts;
- source class, revision, digest, and locator for every input;
- explicit contradictions, omissions, and uncertainty;
- allowed internal destinations and verified external links;
- word/token/citation limits and prohibited claim classes; and
- compiler/model/tool/profile identities.

Repository text, dependency metadata, prior wiki text, issues, and docs are
untrusted data. They cannot instruct the compiler, select a tool/model, relax
policy, request secrets, or alter output shape.

### 7. Optional Bounded Synthesis

Synthesis is allowed only for page kinds and risk classes enabled by the exact
profile. The model returns a closed structured value containing bounded prose,
claim-to-citation bindings, uncertainty, and proposed internal links. Unknown
fields, uncited factual claims, unsupported page kinds, raw HTML, scripts,
tool directives, or external URLs are rejected.

Before each model invocation, the gateway atomically reserves its admitted
maximum tokens and monetary exposure against invocation, attempt, edition,
preview/session, repository, tenant, and fleet budgets. Dispatch is forbidden
without a committed reservation and invocation-before-effect record. The
terminal or ambiguous result records attributable token/cost usage and holds
unreconciled exposure as defined by ADR 0007.

The compiler may retry a safe malformed model response within the fixed
attempt budget. It cannot convert a missing source into confident prose or use
model memory as a citation. When synthesis is unavailable or invalid, the
deterministic page and explicit gap remain usable.

### 8. Link, Redact, And Validate Pages

The compiler canonicalizes internal links, independently verifies allowed
external links, applies content classification and redaction, checks citations
against the frozen inputs, and computes page digests. It removes no authored
content silently; policy-blocked content is represented as concealed or
unavailable with a safe reason.

### 9. Publish Building Edition

The compiler starts and appends the exact edition through bounded semantic
commands. Each segment rechecks request, source, lease, fence, profile,
cancellation, graph revision, segment ordinal, and manifest digest.

### 10. Finalize And Lint

The finalizer proves the complete exact set and edition root. A fresh lint pass
checks the finalized graph rather than trusting generator-local state.
Blocking findings reject closure. Non-blocking findings remain page-visible
and affect completeness/freshness states.

### 11. Request Activation

For current mode, the compiler requests a separately evaluated repository-
control activation. For preview mode it records readiness only. The compiler
cannot turn its own generation success into activation authority.

### 12. Reconcile And Clean Up

After a terminal semantic receipt, disposable worktrees, sandboxes, provider
responses, and local render caches are destroyed or quarantined under policy.
The coordinator re-queries graph state and schedules any required successor,
review, or remediation. It never depends on a local completion flag.

## Change Classification And Update Stage

Every source/control wake-up is classified before compilation. The classifier
uses exact changed paths, graph transition types, compiler compatibility, and
prior page provenance. Unknown classification chooses `full`, not no-op.

| Change or stage | Required wiki action | Activation posture |
| --- | --- | --- |
| Repository enrollment | No wiki compilation until an authorized wiki configuration is selected | Default posture is disabled with zero wiki model calls |
| Wiki configured manual/deterministic | Compile only on explicit request; no model capability | May activate deterministic edition when complete and linted |
| Wiki configured automatic/deterministic | Reconcile deterministic baseline and later source changes | Automatic work has zero model calls/tokens |
| Wiki synthesis enabled | Admit only exact synthesis scope after consent, pricing, and budgets are current | Every model call requires reservation and accounting |
| Wiki disabled/opted out | Stop new work, cancel before further effects, retain incurred accounting | Existing edition read/retention follows separate policy |
| Default branch observed at a new Git object | Full or proven impact-targeted compile | Only the externally observed snapshot may become current |
| Source/module/test change | Rebuild affected generated pages, backlinks, overview, and whole-edition root | Activate complete successor |
| README or authored guide change | Re-index exact authored content, navigation, citations, backlinks, and drift | Activate complete successor |
| `mix.exs` change | Re-extract project metadata and full dependency semantics; rebuild affected guides/references | Full dependency lint required |
| `mix.lock` change | Re-resolve complete dependency graph and exact links | Full dependency lint required |
| ADR/research change | Re-index authored material and architecture navigation; preserve status | No acceptance implied |
| Accepted decision or adopted memory change | Refresh affected cited sections or live panel | Cannot reinterpret source or authorship |
| Work, attempt, health, or transient capacity change | No prose rebuild by default; live reviewed panel refresh | No edition activation |
| Coding attempt starts or changes worktree | Capture its exact wiki context; no current-wiki update | Optional session-private preview only |
| Candidate produced | Compile a preview bound to that session/attempt/candidate when requested and allowed | Preview cannot become current or replace a sibling session preview |
| Candidate verification completes | Refresh preview verification panel; regenerate only if cited inputs changed | Still not current |
| Decision accepts candidate | Record decision link; do not claim external merge | Still not current |
| Draft branch/PR published | Optional private/share-scoped preview refresh | Still not current |
| External merge observed | Compile fresh from observed target snapshot | Eligible after source graph, lint, and review |
| Post-merge verification | Add exact evidence citation or live panel; rebuild affected generated guidance | Activation policy decides ordering |
| Release/tag observed | Produce or pin a release-purpose edition | Retain by release policy |
| Rollback/revert observed | Compile the newly observed tree; retain lineage | Do not relabel an old source identity |
| Compiler/schema/policy upgrade | Rebuild under successor protocol after compatibility decision | Old edition remains selected until safe cutover |
| Repository visibility/tenant change | Reauthorize all projections and external artifacts immediately | Conceal until compatible edition/control state |
| Repository retirement | Stop new maintenance and apply retention policy | No new active edition |

## Targeted Recompilation

Targeted recompilation is an optimization, never a weaker correctness mode. It
is allowed only when the compiler can prove the changed-input-to-page impact
set from the prior edition manifest and current exact inventory.

Even in targeted mode it MUST:

- rebuild all pages whose citations, backlinks, dependency parents, guide
  navigation, freshness, or compiler inputs changed;
- assemble a complete successor page manifest;
- recalculate every affected digest and the whole-edition root;
- run whole-edition link, citation, authorization, and schema lint; and
- publish a new immutable edition.

It never patches the active edition. Unsupported or ambiguous impact analysis
falls back to a full deterministic compile.

## Guide Compilation

Repository-authored guides are discovered by deterministic path/content rules
owned by the compiler profile. Repository configuration may provide bounded
hints but cannot expand readable paths or claim authorship.

For each guide the wiki records:

- exact path, object/tree identity, content digest, media/markup type, title,
  declared or inferred guide class, and heading outline;
- source link at the exact immutable revision;
- authored-content availability and rendering status;
- backlinks from relevant modules, dependencies, releases, and ADRs;
- generated summary, only when enabled and clearly marked;
- drift, broken reference, missing prerequisite, and stale-version findings;
  and
- predecessor/move lineage when deterministically established.

User, developer, operator, contributing, upgrade, security, and release guides
are all first-class. A missing guide creates a gap and may propose normal work.
The maintainer cannot create or commit the missing source guide itself.

## Live Panels Versus Compiled Prose

Volatile facts are represented by a stored reviewed-query reference and a
render policy, not by copying current values into generated prose. Initial
live-panel candidates are:

- repository/source freshness;
- current goals and blocked work;
- active attempts and verification posture;
- release and deployment health;
- currently adopted memory or decision status; and
- wiki staleness and pending compilation state.

The page renderer evaluates live panels under the viewing actor's current
scope. A stored page cannot reveal a resource the live query would conceal.
Panel failure is explicit and does not make the compiled page unavailable.

## Lint Contract

The exact lint profile classifies findings as blocking, warning, or
informational. Blocking findings initially include:

- invalid graph, resource, page, or section shape;
- missing expected segment or page;
- content/edition digest mismatch;
- uncited deterministic or synthesized factual section;
- citation to an unadmitted revision or concealed cross-repository target;
- broken required internal navigation;
- fabricated or unverified exact version, path, source revision, or external
  URL;
- authored/generated authority confusion;
- unsafe markup, secret, credential, absolute host path, prompt, hidden
  reasoning, or raw graph/query disclosure;
- dependency completeness failure without an explicit gap;
- current edition whose source snapshot is not the exact externally observed
  source; and
- compiler/profile/ontology/shape/query incompatibility.

Warnings include bounded missing optional metadata, stale external observation,
noncritical broken external link, documentation gap, source-analysis partial
coverage, and explicit truncation. Policy may promote a warning for security,
operator, migration, recovery, or release guidance.

Lint output is bounded, content-addressed, edition-specific, and independently
recorded. A UI formatter cannot downgrade a blocking class.

## Drift Detection

Drift is discovered from exact input lineage, not a language model's general
impression. Initial deterministic detectors include:

- source or documentation digest changed after the edition input manifest;
- active edition source differs from the repository's observed source head;
- project or lock digest differs from the dependency catalog input;
- cited module, function, path, heading, release, or dependency no longer
  exists at current source;
- generated claim no longer has a supporting admitted citation;
- external metadata passed its expiry or verified link changed identity;
- guide names a version or command contradicted by exact project inputs; and
- current compiler/profile is no longer admitted.

Drift findings state evidence and severity. A maintainer may schedule refresh
or propose a source-doc task but cannot silently repair Git-authored content.

## Preview Protocol

A candidate preview binds the candidate's base, patch/tree digest, attempt,
originating coding session, session-local fence, verification posture, and
exact private audience. It has its own edition purpose, identity, retention,
and presentation badge.

Multiple sessions may produce previews for the same repository and base
revision concurrently. Each preview is a separate compilation request and
edition. Repository-level membership cannot authorize access to a sibling
session's preview. Cancellation, supersession, expiry, or acceptance of one
session has no semantic effect on another session's request or edition.

Preview generation may answer “what would the wiki look like?” and detect
missing guide updates before publication. It MUST NOT:

- replace or alias the current edition;
- appear in ordinary repository search or navigation;
- be cited as externally observed source;
- share generated sections with a current edition without exact input and
  digest verification; or
- survive beyond preview retention merely because the candidate was accepted.

After external merge, the final current compile starts from a fresh observed
checkout and graph-derived context. It does not promote the preview graph in
place.

## Parallel Coding Session Semantics

Every coding session receives a captured `RepositoryWikiContext` that pins the
edition root, evaluated dataset revision, source snapshot, selected sections,
and context digest. The session does not follow the active-edition pointer
implicitly while it runs. An explicit refresh produces a new context identity
and does not rewrite earlier prompts, attempts, evidence, or candidates.

Parallel sessions on one repository therefore behave as independent branches:

1. each reads its own captured context and exact base revision;
2. each may request only its own candidate preview under its attempt fence;
3. one session cannot append to, cancel, review, search, or receive wake hints
   for another session's private preview;
4. candidate completion, verification, acceptance, or draft publication does
   not change the current wiki;
5. externally observed merge order establishes new repository snapshots;
6. ordinary current-source compilation may coalesce rapid observed snapshots
   to the newest eligible head while keeping the active edition visibly stale;
   and
7. the winning current edition is compiled fresh from that observed snapshot,
   never by merging session preview graphs or selecting the first session to
   finish.

If parallel candidates conflict, are rebased, combined, or merged in a
different order, the resulting externally observed tree is a new exact input.
Prior preview citations and roots remain historical and cannot be relabeled as
describing the combined tree.

## Failure And Recovery

All external operations follow invocation-before-effect and terminal-or-
ambiguous accounting. Safe deterministic reads may be repeated. Metadata,
sandbox, and model operations with a possibly completed effect reconcile by
effect identity before retry.

A model effect additionally retains its worst-case budget reservation until
usage is terminally attributable. Disable, cancellation, timeout, or worker
loss cannot erase already incurred cost or release an ambiguous reservation.
Budget exhaustion stops the next synthesis call and yields the exact
deterministic/incomplete/gap outcome selected by policy.

On restart, the coordinator queries requests, editions, segments, manifests,
leases, fences, cancellations, source heads, profiles, lint reports, and
activation transitions. It may:

- resume the next missing segment when every identity remains compatible;
- rerun deterministic work and prove matching digests;
- retry an explicitly safe or reconciled external observation;
- close an exhausted edition incomplete;
- supersede an obsolete ordinary compile with a newer source request; or
- require operator review for ambiguity, corruption, or incompatible profile.

It never trusts a local worktree, ETS entry, process registry, model session,
temporary Markdown export, or PubSub history as recovery truth.

## Semantic Commands And Queries

In addition to the edition commands, implementation planning MUST define
versioned intents equivalent to:

- `RequestWikiCompilation`;
- `SupersedeWikiCompilation`;
- `RecordWikiCompilationFinding`;
- `RequestWikiReview`; and
- `CancelWikiCompilation`.

Required reviewed queries include:

- `WikiCompilationCandidatesByPriority`;
- `WikiCompilationRequestDetail`;
- `WikiCompilationRecoveryState`;
- `WikiInputsForExactSource`;
- `WikiPageImpactSet`;
- `WikiActivationReadiness`; and
- `WikiDriftByRepository`.

Every command uses expected dataset/graph revisions, actor, scope,
idempotency, reason, provenance, audit, exact profile identity, and bounded
receipts. No browser, model, repository file, or runtime process chooses a
command version or graph target.

## Conformance Requirements

Tests MUST prove:

1. exact-input freezing and deterministic inventory under changed checkout,
   reordered event, and concurrent graph mutation races;
2. source precedence, conflict preservation, and no authored/generated
   authority collapse;
3. no host execution of repository code during static extraction;
4. citation-first synthesis rejects instructions, unknown fields, invented
   sources, unsupported URLs, and uncited claims;
5. disabled and unconfigured repositories perform no wiki work, while
   deterministic-only compilation performs no model call and records zero
   model tokens;
6. the complete update-stage matrix, including multiple parallel sessions,
   captured contexts, isolated previews, and candidate/merge separation;
7. targeted compilation produces the same complete successor root as full
   compilation for its qualified impact corpus;
8. live panels cannot leak or become stale copied prose;
9. lint blocks fabricated versions, paths, citations, dependencies, secrets,
   unsafe markup, incompatible contracts, and cross-repository links;
10. cancellation, supersession, crash, provider outage, token/cost or other
    bound exhaustion, ambiguous effect or accounting, and restart recover from
    graph state; and
11. an exact current-source rebuild yields the same deterministic pages,
    citations, dependency catalog, and edition root under the same profile.
