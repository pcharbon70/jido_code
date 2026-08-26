# Repository Wiki Graph And Edition Contract

- Status: Approved and normative under accepted ADRs 0005 and 0007
- Specification version: `0.1.0`
- Owners: JidoCode knowledge and documentation maintainers
- Decision: [ADR 0005](../adr/0005-repository-wikis-as-compiled-knowledge-projections.md)
- Cost decision: [ADR 0007](../adr/0007-repository-wiki-enrollment-and-cost-governance.md)
- Research: [Repository wikis as compiled knowledge projections](../research/11-repository-wikis-as-compiled-knowledge-projections.md)
- Extends: graph registry, ontology, shapes, semantic commands, reviewed queries,
  backup, and retention through additive versioned contracts

## Purpose And Boundary

This specification defines the durable identity, graph topology, resource
model, construction protocol, activation boundary, and retention behavior for
one repository wiki. It does not define a second source of application truth.

A repository wiki is a compiled read product over exact source and graph
inputs. Git remains authoritative for source and repository-authored
documentation. Existing observation, source, control, attempt, evidence,
decision, and memory graphs retain their accepted meanings. Wiki resources
cite those authorities and state their own derivation and uncertainty.

The first implementation MUST be additive. It cannot silently change an
accepted graph family, command, query, ontology/shape pair, or resource IRI.

## Terms

| Term | Meaning |
| --- | --- |
| `RepositoryWiki` | Stable logical wiki identity for exactly one conceptual repository |
| `WikiEdition` | Immutable, content-addressed compilation of the wiki for one exact input manifest |
| `WikiPage` | Addressable page identity and metadata within one edition |
| `WikiSection` | Bounded authored, deterministic, synthesized, live-panel, or gap unit within one page |
| `WikiSource` | Exact cited source identity, revision, location, digest, and authority class |
| `WikiLink` | Typed internal relation between edition-local page or section identities |
| `WikiGap` | Explicitly absent, unavailable, unsupported, contradictory, or incomplete knowledge |
| `WikiDriftFinding` | Evidence that a page, guide, dependency, or reference no longer agrees with its admitted inputs |
| `WikiLintReport` | Bounded whole-edition validation result produced independently of page generation |
| active edition | Closed edition selected by an authorized repository-control transition for ordinary readers |
| preview edition | Private edition for an exact unmerged candidate; never selected as current source |

## Graph Registry Extension

The implementation MUST introduce a new closed family in a new graph-registry
revision. The family definition is:

| Family | Scope inputs | Mutability | Writer capability | Completeness | Retention |
| --- | --- | --- | --- | --- | --- |
| `repository_wiki` | repository, edition | building by bounded append; immutable after closure | `wiki_writer` | building then complete or incomplete | wiki edition class |

No default graph, user-supplied graph name, graph template, or generic write
path can create or mutate this family. Only registered wiki commands holding
`wiki_writer` may target it. Activation targets the existing repository-
control family under a distinct `wiki_activator` capability and never mutates
the edition graph.

Allowed incoming links are limited to repository-control selection,
provenance, audit, retention, and later-edition supersession. Allowed outgoing
links are limited to the owning repository, exact admitted source graphs and
resources, authorized graph inputs, the exact maintainer attempt and bounded
usage/accounting provenance, provider-owned artifact manifests, and edition-
local resources. A wiki MUST NOT establish new authority-bearing relationships
on a source, task, attempt, evidence, decision, memory, budget, or accounting
resource.

## Identity

`JidoCode.Knowledge.ResourceIdentity` remains the only constructor.
Implementation planning MUST allocate deterministic, normalized constructors
equivalent to:

```text
RepositoryWiki:
  https://jido.run/id/repo/{repository-token}/wiki

WikiEdition resource:
  https://jido.run/id/repo/{repository-token}/wiki/edition/{edition-token}

RepositoryWiki graph:
  https://jido.run/graph/repo/{repository-token}/wiki/{edition-token}

WikiPage:
  {edition-iri}/page/{page-token}

WikiSection:
  {page-iri}/section/{section-token}
```

The `edition-token` is derived from the canonical edition root, not a mutable
title, timestamp, branch, or model-generated identifier. Page identity uses a
closed page kind plus canonical source identity or a compiler-owned stable
key. The human slug is display and routing metadata only. Renaming a guide or
changing a generated page key creates explicit lineage and never aliases two
pages merely because their titles match.

All identity constructors enforce the existing NFC, length, encoding,
traversal, control-character, digest, and IRI constraints. Dependency names,
module names, paths, headings, and external URLs are never converted to atoms.

## Edition Input Manifest And Root

Before publication, the compiler freezes one canonical input manifest. It
MUST include:

- conceptual repository IRI and visibility/tenant scope;
- source provider, locator observation, exact Git object, tree digest, and
  default-branch or candidate identity;
- exact revisions and digests of every admitted source, control, decision,
  memory, policy, ontology, shape, query, and compiler input;
- documentation inventory and content digests;
- `mix.exs`, `mix.lock`, toolchain, static-extractor, and optional sandbox-
  introspection result digests;
- metadata observations with provider identity, retrieval time, expiry, and
  payload digest;
- compiler, renderer, link-policy, redaction-policy, lint, and page-schema
  revisions;
- repository wiki configuration plus generation, budget, accounting, and
  pricing profile revisions;
- optional synthesis model/profile, prompt-template, tool-catalog, and
  context-package digests;
- edition purpose: `current`, `release`, `candidate_preview`, or `recovery`;
- originating coding session/attempt, candidate manifest/tree digest, fence,
  and exact audience for `candidate_preview`, with explicit absence for other
  purposes;
- predecessor edition and expected active edition, when present; and
- all declared omissions, authorization gaps, unsupported inputs, and bounds.

The canonical edition root is the SHA-256 digest of:

1. the canonical input manifest;
2. the canonical ordered page manifest;
3. every page content digest;
4. every link and citation digest;
5. the lint-policy identity; and
6. completeness and omission declarations.

The edition root is therefore known before `StartWikiEdition` and can safely
determine the graph identity. The later closure digest covers the edition
root, accepted lint-report digest, closure-policy revision, and final graph
revision. Lifecycle activities and their times do not create a circular input
to either content identity.

Times, random identifiers, graph revisions assigned during publication, and
provider request IDs are excluded from generated content identity unless they
are semantic source observations. The same exact inputs and deterministic
profile MUST reproduce the same edition root. A model-generated edition is
reproducible only as a recorded materialization; its model output is not
assumed to be regenerable byte-for-byte.

## Resource Model

### Edition

Every `WikiEdition` records:

- wiki, repository, graph, edition root, purpose, predecessor, and source
  snapshot;
- input-manifest digest and provider-owned manifest reference when the bounded
  RDF representation is insufficient;
- compiler, ontology, shape, query, renderer, redaction, and lint identities;
- optional model/profile identity and explicit absence when unused;
- generation/configuration identity and bounded edition accounting manifest
  for model calls, token dimensions, calculated cost, reserved exposure, and
  unavailable/contradicted posture;
- lifecycle, completeness, freshness, visibility, and retention class;
- expected and actual page, section, citation, link, dependency, guide, gap,
  and segment counts;
- content-byte and statement counts;
- start, closure, lint, activation, supersession, and invalidation activities;
- exact closure digest and accepted lint report; and
- bounded warnings and omissions.

### Page And Section

Every `WikiPage` records a closed page kind, stable key, title, slug, order,
content digest, freshness state, coverage state, visibility classification,
edition membership, source/citation counts, and predecessor lineage where
applicable.

Every `WikiSection` records a closed section kind and one authority class:

| Authority class | Contract |
| --- | --- |
| `authored` | Exact repository-authored content; Git identity, path, range or heading anchor, and digest required |
| `deterministic` | Produced by a pinned extractor from exact inputs; extractor and input citations required |
| `synthesized` | Bounded explanatory text; model/profile provenance, citations, uncertainty, and lint required |
| `live_panel` | Contains only a reviewed query identity and rendering contract; mutable results are not stored as page prose |
| `gap` | Explicit absence, conflict, authorization, support, truncation, or availability outcome |

Authored and synthesized text cannot share one section. A renderer may place
them together visually only if their source classes remain distinguishable.
Generated text cannot masquerade as an authored guide or accepted decision.

### Citations, Links, And Gaps

Every factual deterministic or synthesized section has at least one
`WikiCitation`, except a section whose complete content is an explicit gap.
A citation records exact source IRI, source class, snapshot/revision, digest,
bounded locator, claim role, and retrieval policy. A citation never grants
read authority to its target.

Every `WikiLink` uses a closed relation such as `contains`, `explains`,
`depends_on`, `used_by`, `implements`, `documents`, `supersedes`, `related`,
or `backlink`. Broken or unauthorized destinations become lint findings; the
renderer cannot reveal a concealed target through its label or URL.

`WikiGap` and `WikiDriftFinding` are first-class resources with category,
severity, evidence/citations, affected pages, detected-at revision, and one
bounded remediation class. They are not automatically tasks, failures,
accepted evidence, or permission to edit a repository.

## Page Kinds

The initial closed page-kind vocabulary is:

- `home` and `project_overview`;
- `architecture_overview`, `module`, `runtime`, and `data_flow`;
- `source_area` and `test_area`;
- `dependency_overview`, `dependency`, and `dependency_gap`;
- `guide_index`, `user_guide`, `developer_guide`, `operator_guide`,
  `contributor_guide`, `upgrade_guide`, and `release_guide`;
- `adr_index`, `adr`, and `research_note`;
- `operations`, `security`, `release`, and `changelog`;
- `glossary`, `reference`, and `known_gap`; and
- `about_this_wiki`.

A new kind requires an additive page-schema revision. Unknown model-supplied
kinds are invalid rather than dynamically admitted.

## Content Storage Boundary

Wiki graphs store bounded generated prose, structural metadata, citations,
digests, excerpts permitted by policy, and artifact references. They do not
store arbitrary source bodies, secrets, build outputs, provider transcripts,
hidden reasoning, raw ASTs, complete tool output, or reusable credentials.

Repository-authored guide bodies remain in Git. The product retrieves them
through the exact source-content boundary or a verified immutable artifact
whose digest is cited by the page. Large rendered exports are provider-owned
artifacts with graph-visible identity, digest, media type, size, retention,
and provenance. A filesystem export or cache is disposable and cannot be the
only copy of application-owned state.

## Construction Lifecycle

The lifecycle is:

```text
requested -> building -> finalized -> linted -> closed
                 |           |          |
                 +--------> incomplete  +-> rejected

closed -> active -> superseded
   |          |
   +-> retained_release
   +-> invalidated
```

`requested` is a control/task state, not a readable edition graph. A building
edition is private to exact authorized compiler and diagnostic queries. It is
never returned by ordinary wiki navigation or search.

An implementation plan MUST introduce semantic intents equivalent to:

- `StartWikiEdition`;
- `AppendWikiEditionSegment`;
- `FinalizeWikiEdition`;
- `RecordWikiLintReport`;
- `CloseWikiEdition`;
- `ActivateWikiEdition`;
- `MarkWikiEditionStale`; and
- `InvalidateWikiEdition`.

Names and grouping may change during implementation, but all distinct guards
and receipts remain visible. Generic graph writes are forbidden.

### Start

`StartWikiEdition` creates graph metadata, edition identity, exact manifest,
expected counts, bounds, lease, and fence in one command. It guards graph
absence, current repository scope, exact source/control heads, profile state,
and expected prior active edition.

### Segmented Append

Segments are canonically numbered and content-addressed. Each append supplies
the exact edition, manifest digest, segment ordinal/digest, expected graph
revision, lease, and fence. Replay of identical content returns the original
receipt. A divergent digest for an admitted ordinal conflicts permanently.

To retain reserve beneath the existing command ceilings, the initial profile
SHOULD limit one segment to at most 800 statement additions and 192 KiB of
canonical logical payload. The accepted global command bound remains the hard
ceiling. Final implementation values must be pinned in a versioned wiki
profile and tested against provenance/audit overhead.

No section crosses segments. Every page has a manifest record before closure,
and a page's segments are contiguous. Bounds include maximum pages, sections,
citations, links, dependencies, statements, generated bytes, segments, wall
time, and external observations. Bound exhaustion yields an explicit
incomplete edition, never silent omission.

### Finalize, Lint, And Close

Finalization proves the exact expected set, counts, canonical digests, segment
closure, citation targets, page membership, link destinations, source
revisions, and computed edition root. No further segment can be appended after
successful finalization.

Lint is a separate operation over the finalized edition. Closure requires the
exact accepted lint-policy revision and a lint report with no blocking issue.
It commits closure metadata and makes the edition immutable. A non-blocking
warning remains visible. A failed or incomplete edition may be retained for
diagnosis but cannot become current.

### Activation

Activation is a repository-control transition, not an edition mutation. It
guards:

- exact closed edition root and graph revision;
- current repository, tenant, source snapshot, and visibility;
- exact expected prior active edition;
- current compiler/profile/policy compatibility;
- accepted lint report and required review evidence;
- current maintainer lease/fence or separately authorized operator action;
- no newer winning source revision or cancellation; and
- mode-specific rules for current, release, preview, and recovery editions.

Candidate previews cannot be activated as current. A current edition must be
compiled after the source change is observed externally and must match the
published source graph. Activation success does not accept the page claims as
evidence, satisfy a goal, adopt memory, or authorize any external effect.

Parallel previews for one repository are distinct editions. Their manifests,
identities, lease/fence namespaces, and visibility include the originating
session/attempt and candidate. A preview query authorizes that scope before
resolving the edition; repository membership alone is insufficient. No
preview command can target the repository-control active-edition relation.

## Reviewed Read Contract

The query catalog MUST provide bounded equivalents of:

- `ActiveRepositoryWikiSummary`;
- `RepositoryWikiEditionDetail`;
- `RepositoryWikiPageByReference`;
- `RepositoryWikiPageNeighborhood`;
- `RepositoryWikiGuideIndex`;
- `RepositoryWikiDependencyIndex`;
- `RepositoryWikiCitationDetail`;
- `RepositoryWikiGapAndDriftIndex`;
- `RepositoryWikiEditionHistory`; and
- privileged `RepositoryWikiBuildDiagnostics`.

Every query begins with actor, tenant, repository, and visibility scope and
evaluates at one dataset revision. Search MUST authorize the repository before
candidate generation and returns opaque presentation references, never raw
graph names. Page reads expose freshness, completeness, truncation, source
class, edition root, and evaluated revision.

No product caller receives raw SPARQL, graph handles, arbitrary RDF, hidden
editions, unauthorized citation targets, source bodies, absolute paths, model
prompts, or diagnostic secrets.

## Retention, Backup, And Recovery

The initial retention classes distinguish:

- active current edition;
- retained release edition;
- superseded ordinary edition;
- private candidate preview;
- failed or incomplete diagnostic edition; and
- invalidated edition tombstone.

Release editions and edition/control provenance follow release-history
policy. Preview and failed editions have shorter explicit limits. Garbage
collection is a governed retention action and cannot delete an edition still
selected, cited by a retained decision/evidence resource, or required for an
active release.

Backup includes closed application-owned wiki graphs, control selection,
profiles, lint reports, and artifact manifests. Restore verifies edition roots,
graph metadata, cross-family links, selection validity, and provider-owned
artifact availability. A missing external artifact produces an unavailable or
incomplete state; it never causes reconstruction from an unpinned model.

## Versioning And Compatibility

The following are authority-bearing and require explicit versioning:

- graph family and graph identity;
- resource and page identity;
- input manifest and edition-root algorithms;
- ontology, shapes, link directions, and page kinds;
- content-storage and redaction policy;
- segmentation, finalization, lint, closure, and activation rules;
- retention classes; and
- query/projection schemas.

Existing repositories without a wiki return `not_compiled`. Existing graph
families remain valid. Startup compatibility MUST fail before serving traffic
when a selected edition requires unsupported identity, ontology, shape,
command, query, compiler, or renderer revisions.

An unconfigured or opted-out repository returns `wiki_disabled` for creation
intents, which is distinct from `not_compiled`. Prior authorized editions may
remain readable according to the separately selected presentation/retention
policy. No edition graph is created merely to represent opt-out.

Old closed editions are never rewritten under a new protocol. Rebuild creates
a successor. Rollback selects a prior still-authorized closed edition and
marks source mismatch explicitly; it cannot pretend an old edition describes
a new source snapshot.

## Conformance Requirements

Tests MUST prove:

1. deterministic repository, edition, page, section, citation, and graph
   identities with hostile Unicode, path, URL, and length inputs;
2. graph-family placement, capability, lifecycle, link-direction, and
   cross-repository rejection;
3. segment ordering, duplicate replay, divergent replay, missing segment,
   bound exhaustion, and append-after-finalization behavior;
4. exact-set finalization and deterministic edition roots;
5. closure immutability and atomic, fenced repository-control activation;
6. candidate-preview concealment, parallel same-repository session isolation,
   and impossibility of current activation;
7. authored, deterministic, synthesized, live, and gap authority classes stay
   distinct in storage and projection;
8. citations cannot reveal unauthorized graphs or source bodies;
9. disabled/unconfigured creation, deterministic-only zero-model accounting,
   and edition usage/cost manifest behavior;
10. backup, restore, retention, invalidation, rollback, and missing-artifact
   states preserve provenance; and
11. zero cross-repository, cross-tenant, secret, raw-query, or hidden-edition
    disclosure across every reviewed query and product projection.
