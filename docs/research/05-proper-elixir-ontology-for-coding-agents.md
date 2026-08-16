## 5. A Proper Elixir Ontology for Coding Agents

- Status: research proposal, not an accepted architecture decision
- Research cutoff: 2026-08-15
- JidoCode revision inspected: `85a8bdd1fd75b5ebaae01e68ad3ad62af59bc254`
- `elixir-ontologies` revision inspected: `fb2432ae666062b8d0d601f742abbadda0583b02`
- Language baseline reviewed: Elixir 1.20.3 and Erlang/OTP 29.0.5

## Executive conclusion

A proper ontology for Elixir cannot be just an RDF serialization of the quoted
AST, and it cannot be one graph in which source modules, compiled modules,
processes, packages, people, agents, tests, and production observations share
generic `uses`, `calls`, or `dependsOn` edges.

The ontology should model a sequence of related but non-equivalent semantic
layers:

```text
authored source
  -> parsed/quoted syntax
  -> macro-expanded program
  -> compiled BEAM artifacts
  -> loaded code and runtime instances
  -> observed executions
```

Each transition may generate entities, erase authored structure, depend on
configuration, or introduce uncertainty. The same name can denote a conceptual
language symbol, one declaration occurrence in a source snapshot, generated
code, a BEAM export, current loaded code, old loaded code, or a process executing
that code. Those are separate resources connected by provenance.

For coding agents, the minimum useful model is not the complete AST. It is a
stable set of exact source occurrences and qualified semantic observations that
can answer bounded questions about:

- definitions, declarations, references, and source spans;
- functions, macros, arities, defaults, ordered clauses, patterns, and guards;
- lexical alias/import/require/use resolution;
- behaviours, callbacks, protocols, implementations, structs, and types;
- macro generation and authored-to-expanded provenance;
- Mix projects, applications, dependencies, locks, build profiles, generated
  source, BEAM artifacts, releases, and protocol consolidation;
- OTP applications, supervision declarations, child specifications, process
  roles, message interactions, links, monitors, registries, ETS, and
  distribution;
- tests, diagnostics, coverage, security findings, and data-flow observations;
- repositories, commits, trees, changes, issues, reviews, users, organizations,
  stewardship, decisions, and agent activity;
- who or what produced each fact, from which exact inputs, under which profile,
  with what coverage, certainty, valid time, and graph revision.

The recommended solution is a modular ontology stack. A small language-neutral
source core provides snapshot-scoped artifacts, symbols, occurrences, spans,
sequence membership, analysis activities, coverage, and certainty. Elixir,
Erlang/OTP, Mix/BEAM, type-analysis, and framework modules extend it. Companion
modules link provenance, actors and organizations, VCS, build and package
metadata, evidence, software supply chain, runtime observations, work, retrieval,
privacy, and governance without making those facts intrinsic source facts.

The stack should directly reuse stable external semantics where they fit,
especially PROV-O, OWL-Time, ORG, DCTerms, SKOS, SHACL, Web Annotation, and
selected FOAF terms [ST01-ST06, ST10, ST14, ST16]. It should map rather than
flatten operational formats and schemas such as SPDX, CycloneDX, SARIF,
OpenTelemetry, SLSA/in-toto, OSV/VEX, Git, Software Heritage, SCIP, Kythe, and
Glean [ST22-ST23, ST32-ST34, ST37-ST38, ST45-ST50]. KDM, ASTM, FAMIX,
CodeOntology, GraphGen4Code, and SEON are design references, not ontologies to
import wholesale [ST39-ST44].

`elixir-ontologies` is a valuable vocabulary experiment and implementation
fixture, but it is not the target ontology unchanged. At the inspected revision,
its default and legacy pipelines can collapse unrelated function structure
through shared blank nodes, lose nested-module ownership, omit top-level
protocols, discard extracted facts, emit literals through OWL object properties,
type source-module IRIs as runtime-oriented Supervisor or Task resources,
construct unresolved call targets as declarations, and silently suppress some
extractor, builder, and SHACL failures. Project analysis can return partial output
as `{:ok}` while recording file errors; strict contextual `analyze_string/3`
full-expression analysis is an important exception. The replacement design below
addresses those semantic gaps rather than merely adding missing classes
[EO02-EO09].

## Recommendation summary

| Question | Recommendation |
| --- | --- |
| What is the ontology's central identity? | Separate conceptual symbols from exact snapshot-scoped occurrences. |
| Is one `Module` resource sufficient? | No. Distinguish module symbol, declaration occurrence, expanded module, BEAM artifact, loaded module version, and process role. |
| How should calls be modeled? | Use call-site occurrences plus provenance-bearing resolution observations such as syntactic target, static-may target, compiler-resolved target, runtime-observed call, and unresolved target. |
| How should order be represented? | Use explicit membership resources with integer positions for clauses, parameters, guards, routes, children, and transaction steps. |
| Should RDF lists be the primary order model? | No. They are cumbersome to update/query, rely on blank nodes in common serializations, and do not carry item-specific provenance cleanly. |
| Should typespecs become OWL classes? | No. Represent type expressions as individuals in a versioned type-language AST. |
| Are typespecs, Dialyzer types, and Elixir inferred types equivalent? | No. Keep authored typespecs, Dialyzer success typings, and gradual set-theoretic compiler assertions separate. |
| Is a `use` edge inheritance? | No. It is a lexically scoped macro invocation whose expansion may generate arbitrary code. |
| Is a supervisor module a runtime process? | No. Model implementation/declaration separately from process instances and observations. |
| Can a missing edge prove absence? | Only within an explicit complete profile, exact snapshot, successful extractor set, and untruncated query. |
| Should user email identify a person? | No. Use issuer/provider plus stable subject/account ID; retain email only as classified optional profile data. |
| Does code ownership grant command authority? | No. Authorship, stewardship, organization membership, authentication, and authorization are distinct. |
| Should every companion standard be imported with `owl:imports`? | No. Reuse IRIs selectively, map native formats, and keep optional alignments in separate modules. |
| Should RDF-star be required? | No. Use qualified assertion resources as the durable form; RDF 1.2 projections can be optional later. |
| What validates the contract? | OWL semantics, SHACL admission, executable query fixtures, and transactional command guards, each with a distinct role. |
| Can this fit the current JidoCode source graph unchanged? | No. It requires a new ontology release, namespace-aware validation, segmented source analysis, compatibility-aware startup, and reviewed query tools. |

## Research scope and method

This report extends
`docs/research/04-ontology-backed-source-graphs-for-coding-agents.md`. The earlier
report established that bounded source relationships improve repository
navigation and exposed implementation defects in the external ontology. This
report asks what the ontology itself should mean.

The study used:

- official Elixir 1.20, Mix, ExUnit, Hex, Erlang/OTP 29, EEP, Dialyzer, BEAM,
  Telemetry, Phoenix, LiveView, and Ecto documentation [EL01-EL30, OTP01-OTP19,
  ECO01-ECO09];
- direct inspection of every ontology and major builder/extractor path in
  `elixir-ontologies` at the pinned commit [EO01-EO11];
- W3C, DCMI, OASIS, OMG, OpenSSF, SPDX, OWASP, CNCF, Git, Software Heritage,
  and code-intelligence standards and schemas [ST01-ST51];
- ontology-engineering standards and peer-reviewed methods covering OWL,
  SHACL, competency questions, modularization, versioning, IRI persistence,
  ontology design patterns, quality checks, and FAIR publication [OE01-OE37];
- JidoCode's accepted ADRs, ontology package, source publication, graph topology,
  identity, authorization, evidence, runtime, memory, privacy, and retention
  contracts [JC01-JC18], plus prior non-binding research [JR01-JR02].

The report distinguishes:

- a schema concept from an extractor capability;
- an authored assertion from an analysis observation;
- an observation from accepted evidence;
- descriptive identity or ownership from command authorization;
- an ontology module from a graph family;
- an external interchange format from the local authoritative model;
- a recommended future design from current accepted JidoCode behavior.

## What makes an ontology proper

A production ontology is not proper merely because its Turtle parses or its
classes sound comprehensive. It needs six coordinated contracts.

### 1. Competency contract

The ontology starts from questions agents and reviewers must answer. Every public
term should support a competency question, interoperability requirement, or
documented design decision. Questions must include dynamic, unresolved,
incomplete, and invalid cases, not only successful extraction [OE21-OE23].

### 2. Semantic contract

OWL describes open-world meaning and valid inferences. It must declare the
supported OWL regime, disjointness, class/property semantics, imported axioms,
and entailment timing. Domain and range axioms infer types; they do not validate
input. Absence of an inferred statement is not falsity [OE01-OE06, OE09-OE11].

### 3. Admission contract

SHACL and executable command validation define which concrete graphs JidoCode
accepts. Shapes check required properties, cardinality, datatypes, class/predicate
allowlists, source-span bounds, certainty values, and graph placement. Command
guards check authorization, existing resources, exact revisions, idempotency,
cross-graph coherence, and lifecycle [OE07-OE08].

### 4. Identity contract

Every resource kind needs deterministic identity and a clear scope. A path is
not a file identity; a name is not an occurrence identity; a branch is not a
snapshot; a module symbol is not a loaded code version; a PID is not a durable
process role; an email is not a person.

### 5. Evidence contract

Every analyzer-derived, generated, inferred, or observed relation records its
producer, activity, method, versions, configuration, exact inputs, time,
coverage, certainty, limitations, and supporting evidence. Confidence is not
acceptance, and provenance is not truth [ST01, ST02, ST12, ST21].

### 6. Evolution contract

The ontology needs a stable ontology IRI, immutable version IRIs, unchanged
public term IRIs, release metadata, migration guidance, compatibility tests, and
tombstones for deprecated terms. Compatibility must be evaluated independently
for OWL entailments, SHACL acceptance, SPARQL answers, identity, and runtime
admission [OE01, OE16-OE19, OE25-OE36].

## Foundational semantic layers

The same Elixir program has multiple representations. The ontology should use an
explicit semantic-layer vocabulary rather than one overloaded source graph.

| Code | Layer | Typical entities | What it establishes |
| --- | --- | --- | --- |
| `A` | Authored | `.ex`, `.exs`, `mix.exs`, config, templates, migrations | Exact bytes and authored syntax in a repository tree |
| `Q` | Quoted | Elixir AST, metadata, lexical environment | Parser output under an exact parser/options version |
| `X` | Expanded | Macro expansions, generated definitions, normalized forms | Compile-time result under an exact environment and dependency state |
| `B` | Built | BEAM, `.app`, docs/debug chunks, package, release | Artifact facts under an exact compiler/toolchain/build configuration |
| `L` | Loaded | Current and old module code, applications, processes, ETS, registrations | Time-bounded runtime state on a node |
| `O` | Observed | Messages, traces, telemetry, coverage, test outcomes | Events observed by one instrumented execution scope |

The transition chain is:

```text
A --parse--> Q --expand--> X --compile/package--> B
B --load/start--> L --instrument/execute--> O
```

It is not invertible:

- comments and formatting disappear from quoted or compiled forms;
- macros generate code with no one-to-one authored declaration;
- defaults generate additional callable arities;
- protocol consolidation changes built dispatch relative to source declarations;
- BEAM chunks can be stripped;
- hot loading allows current and old code simultaneously;
- runtime traces sample only paths that executed and were observed.

Required rules:

1. Every entity that can vary by layer carries or implies one semantic layer.
2. `generatedFrom` never means `authoredBy`.
3. Built facts bind exact Elixir, OTP, compiler, dependency, configuration, and
   artifact digests.
4. Loaded and observed facts carry node/instance identity and valid time.
5. Runtime observation never rewrites authored source semantics.
6. A direct relation across layers requires an explicit generation, compilation,
   loading, correspondence, or observation activity.

## Modular ontology architecture

Ontology modules define vocabulary. Named graph families define assertion
authority, mutability, lifecycle, scope, and retention. They are independent
dimensions. The following modules do not each require a new graph family.

### Proposed modules

| Module | Responsibility | Stability target |
| --- | --- | --- |
| Source Core | Repositories/snapshots references, artifact and symbol occurrences, spans, sequence memberships, analysis profiles, coverage, certainty | Stable, language-neutral |
| Elixir Language | Modules, callable symbols, clauses, patterns, guards, directives, attributes, docs, structs, exceptions | Stable by supported Elixir language range |
| Elixir Resolution | Lexical scopes, bindings, imports, aliases, call/reference occurrences, candidate and resolved targets | Versioned by resolver/compiler semantics |
| Elixir Macro | Quote/unquote, macro invocation, expansion activity, generated definitions, hygiene/environment | Versioned and optional |
| Elixir Type Declarations | Typespec AST, specs, callbacks, opaque/private/public type declarations | Stable for declared dialect/version |
| Elixir Type Analysis | Dialyzer success typings, gradual set-theoretic assertions, refinements, typing diagnostics | Analyzer/version-specific observation module |
| OTP Declarations | Application callbacks, server/supervisor implementations, child specs, message/callback declarations | Static source/build semantics |
| BEAM Artifacts | BEAM modules/chunks, exports/imports, compile info, docs/debug availability, loaded-code correspondence | Build/artifact semantics |
| Mix Build | Projects, applications, umbrellas, dependencies, lock entries, compilers, profiles, releases, generated source | Versioned by Mix/Hex ecosystem |
| Framework Overlays | Phoenix, LiveView, Ecto, Telemetry, Jido, and other DSL semantics | Independent optional profiles |
| VCS | Git objects, commits, trees, refs, changes, continuity observations | External-authority bridge |
| Actors and Stewardship | People, organizations, teams, accounts, software agents, memberships, descriptive roles | Catalog/observation semantics |
| Provenance | Analysis, generation, build, observation, attribution, qualified roles and derivations | PROV-O/OWL-Time alignment |
| Work and Collaboration | Issues, requirements, PRs, reviews, annotations, rationale links | Provider bridge; not source truth |
| Quality and Evidence | Test declarations, diagnostics, runs, outcomes, coverage, findings, supporting/contradicting evidence | Existing run/evidence boundaries |
| Supply Chain and Security | Packages, releases, SBOMs, licenses, advisories, vulnerabilities, attestations, signatures | Native-format mapping layer |
| Runtime Observation | Deployments, loaded modules, process instances, messages, traces, runtime topology | Time-bounded observations |
| Agent and Retrieval | Requests, plans, tasks, tool/model invocations, patches, queries, ranking, context items and omissions | Existing control/run/audit boundaries |
| Governance | Classification, purpose, retention, legal hold, erasure, redaction, egress and policy references | Existing policy/security boundaries |
| Alignments | Optional external vocabulary mappings | Independent, replaceable, no core semantic side effects |
| Shapes | Versioned graph-family admission profiles | Operational contract |

### Import graph

The module import graph should be acyclic:

```text
source-core
  <- elixir-language
  <- elixir-resolution
  <- elixir-macro
  <- elixir-type-declarations
  <- otp-declarations

source-core + provenance
  <- elixir-type-analysis
  <- beam-artifacts
  <- mix-build
  <- framework-overlays

all domain modules
  <- optional alignments
  <- shapes
```

External alignment modules may reference upstream IRIs without importing all
upstream axioms. `owl:imports` is appropriate only when the complete imported
axiom closure is intended to affect local reasoning. Every import must be pinned,
available offline, digest committed, licensed, and tested [OE01, OE28].

### Canonical term registry sketch

All examples and competency queries in this report use one namespace ownership
rule:

| Prefix/module | Owns |
| --- | --- |
| `src:` Source Core | `ConceptualSymbol`, artifact/symbol/declaration/reference/invocation occurrences, `GeneratedOccurrence`, spans, memberships, manifests, segments, coverage, omissions, relation observations, certainty and layer concepts |
| `ex:` Elixir Language/Macro | Elixir module/callable symbols, callable definition and clause occurrences, patterns, directives, protocols, behaviours, structs, macro invocations/definitions, and `MacroExpansionActivity` |
| `extype:` Elixir Type | Type systems/languages/expressions, declarations, analysis assertions, refinements, and type diagnostics |
| `otp:` OTP | Static OTP implementations/declarations and explicitly named runtime observation resources |
| `mix:` Mix Build | Projects, dependency/lock/build/release declarations and activities |
| `beam:` BEAM | BEAM artifacts, chunks, exports/imports, compile information, and loaded module versions |
| `prov:` PROV-O | General entity/activity/agent provenance relationships |

Final term names and namespaces require an accepted ontology release, but one
term in this report always has one owning module. Examples do not introduce
synonymous `FunctionOccurrence`, `FunctionDeclarationOccurrence`, and
`CallableDeclarationOccurrence` terms.

### Upper ontology posture

Do not import BFO, IAO, KDM, or another heavy upper/metamodel solely to claim
alignment. `elixir-ontologies` classifies code elements under BFO generically
dependent continuants but does not import all referenced terms consistently, and
the distinction does not answer the coding-agent competency questions.

Use PROV-O as the light common foundation for entities, activities, agents,
generation, usage, attribution, and association [ST01]. Use explicit local
classes for source and language semantics. Put optional BFO/KDM alignments in a
separate module if a concrete interoperability consumer appears.

## Competency questions

### Exact source and identity

1. Which exact artifact digest and span declares this symbol in this tree?
2. Which source occurrences denote the conceptual function `Module.name/arity`?
3. Is the selected occurrence authored, generated, compiled, loaded, or observed?
4. Which parser/analyzer/profile produced this occurrence?
5. Is extraction complete for the relevant file, module, construct, and query?
6. Which source coordinate convention is used, and is the artifact digest still
   current?
7. Which occurrence in a prior snapshot may be the predecessor of this symbol,
   and what evidence supports that continuity?

### Functions, clauses, and control

8. Which arities are authored and which are generated by default arguments?
9. What is the exact order of a function's clauses?
10. Which patterns and guards qualify each clause?
11. Which values remain possible after earlier clauses are excluded under a
    particular compiler type-analysis run?
12. Which variables does a pattern bind, rebind, pin, read, or constrain?
13. Which expression occurrence generated a diagnostic?
14. Which control branches are syntactic, statically reachable, dynamically
    observed, or proven impossible under a stated model?

### Resolution and compile-time behavior

15. Which lexical alias/import/require/use directive affects this occurrence?
16. Is this invocation a function call, macro invocation, special form, protocol
    dispatch, behaviour callback, or unresolved dynamic apply?
17. Which target candidates were considered, by which resolver, and why?
18. Which macro invocation generated this definition or expression?
19. Which caller environment, dependency module, compiler, and configuration
    governed expansion?
20. Which generated facts are unavailable because expansion was not permitted or
    failed?

### Contracts and polymorphism

21. Which callbacks does a behaviour declare, and which are optional?
22. Which implementation occurrence claims or satisfies each callback?
23. Is a conformance result from authored structure, compiler diagnostics, or
    runtime observation?
24. Which protocol implementations were declared, compiled, and included in a
    particular consolidated protocol artifact?
25. Which dispatch target is possible for a known first-argument type?
26. Which struct fields, enforced keys, derives, exceptions, specs, and type
    declarations are affected by a change?

### Types and analysis

27. Is this type expression a traditional typespec, Dialyzer success typing, or
    Elixir gradual set-theoretic type?
28. Which exact dialect/version defines its constructors and normalization?
29. Which authored spec, inferred type, or intersection influenced a Dialyzer
    warning?
30. Which compiler run inferred this signature or program-point refinement?
31. Which warning absence reflects complete analysis versus unavailable debug
    information or disabled options?
32. Can two type expressions be translated exactly, approximately, or not at
    all between semantic systems?

### Build, package, and artifact lineage

33. Which Mix project, environment, target, lock digest, dependency graph,
    compiler, and external inputs produced this BEAM artifact?
34. Which source or macro-generated definitions correspond to this BEAM export?
35. Which debug, docs, attributes, compile-info, and checker chunks are present,
    absent, stripped, encrypted, or unsupported?
36. Which package release and exact distribution digest supplied a dependency?
37. Which protocol implementation inventory was used during consolidation?
38. Which release or deployment contains this artifact digest?

### OTP and runtime

39. Which source module implements a GenServer or supervisor contract?
40. Which child specifications and strategy are declared for a supervisor?
41. Which runtime process instance currently executes which loaded module
    version?
42. Which message send was syntactically possible, statically resolved, and
    actually observed?
43. Which process registration, link, monitor, child instance, or ETS ownership
    fact was valid at a particular time?
44. Is an edge a declaration, deployed configuration, loaded state, or sampled
    runtime observation?

### People, collaboration, and authority

45. Which Git author/committer account claims are recorded for a commit?
46. Which provider account, person, team, or software agent was reconciled to an
    observed identifier, and on what basis?
47. Who is described as maintainer, reviewer, accountable owner, or CODEOWNER for
    this resource at this time?
48. Does that descriptive role grant any JidoCode command authority? The expected
    answer is no unless a separate current grant exists.
49. Which issue, PR, review, annotation, or decision motivated this change?
50. Which exact patchset and source revision did a review comment target?

### Evidence, security, and agents

51. Which tests were defined, selected, executed, skipped, failed, retried, or
    omitted for this change?
52. Which exact execution observed coverage of this source occurrence?
53. Which SARIF/security finding, source-to-sink path, advisory, VEX assessment,
    or attestation applies to the exact artifact and environment?
54. Which source graph query and ranking path selected each model context item?
55. Which actor, task, purpose, capability, graph revisions, and content permit
    authorized retrieval before candidate generation?
56. Which model/tool invocations and edits produced this patch?
57. Which independent evidence supports or contradicts its claimed outcome?
58. Which data classification, retention, redaction, erasure, or egress policy
    applies to source-derived content and indexes?

## Source Core ontology

The Source Core should be compact, language-neutral, and occurrence-based.

### Core classes

| Class | Meaning |
| --- | --- |
| `RepositorySnapshot` | Exact repository tree state; conceptual repository plus algorithm-qualified tree digest |
| `ArtifactContent` | Content-addressed bytes with digest, media type, and byte count |
| `ArtifactOccurrence` | One artifact at a normalized path in one exact snapshot |
| `ConceptualSymbol` | Language-scoped semantic identity independent of one snapshot occurrence |
| `SymbolOccurrence` | One snapshot/profile occurrence of a symbol |
| `DeclarationOccurrence` | Analysis-created representation of an exact source declaration/span |
| `ReferenceOccurrence` | Source occurrence referring or attempting to refer to a symbol |
| `InvocationOccurrence` | Call-, macro-, dispatch-, send-, or apply-shaped source occurrence |
| `ExpressionOccurrence` | Optional source/expanded expression occurrence |
| `SourceSpan` | Digest-bound location using an explicit coordinate convention |
| `SequenceMembership` | Indexed membership of an item in an ordered construct |
| `AnalysisProfile` | Versioned semantic scope and options for extraction |
| `AnalysisActivity` | Exact analyzer execution using exact inputs |
| `AnalysisManifest` | Expected segments, digests, coverage, omissions, and closure state |
| `AnalysisSegment` | Bounded immutable output unit for one manifest |
| `CoverageAssertion` | Positive scope/coverage statement for one analyzer/profile |
| `Omission` | Unsupported, failed, excluded, truncated, generated-unavailable, or policy-withheld scope |
| `RelationObservation` | Qualified analyzer- or runtime-produced relation between resources |
| `CertaintyClass` | Controlled epistemic category, represented as a SKOS concept |
| `SemanticLayer` | Authored, quoted, expanded, built, loaded, or observed layer concept |

### Symbol versus occurrence

The conceptual symbol and occurrence split is mandatory. An occurrence resource
is the analyzer-created RDF representation of a construct denoted by exact source
bytes and a span. The analyzer generates that representation and graph segment;
it does not generate the pre-existing authored bytes.

```text
ConceptualSymbol
  languageIdentityKey "elixir|function|Elixir.MyApp.Worker|run|1"

DeclarationOccurrence
  occurrenceOf ConceptualSymbol
  inArtifact ArtifactOccurrence
  hasSpan SourceSpan
  validForSnapshot RepositorySnapshot
  generatedBy AnalysisActivity
```

Conceptual symbols support questions across snapshots. Occurrences support exact
editing, provenance, and historical truth. A rename or move does not use
`owl:sameAs`; a `SymbolContinuityObservation` connects two occurrences with
method, producer, confidence, and evidence.

### Artifact identity

Separate:

- conceptual repository;
- repository locator/origin;
- Git commit object;
- Git tree object;
- repository tree snapshot;
- blob/content identity;
- artifact occurrence at path;
- local checkout/worktree;
- generated artifact outside the tree.

JidoCode currently identifies a source snapshot from repository and Git tree,
which correctly collapses commits with identical trees for source semantics.
Commit parentage and authored history remain separate VCS facts [JC05-JC08].

### Source spans

Every actionable declaration, reference, invocation, clause, pattern,
diagnostic, and annotation should point to a `SourceSpan` with:

- exact artifact occurrence and content digest;
- coordinate convention such as UTF-8 byte offset, Unicode code-point, or
  line/column with explicitly defined column units;
- start/end positions and inclusive/exclusive convention;
- authored/generated/embedded classification;
- optional generator and generated-to-authored mapping;
- source profile and extraction activity.

Line/column alone is not stable. A span is invalid for editing if the worktree
artifact digest differs.

### Order without ambiguous lists

Use explicit memberships:

```text
CallableDefinitionOccurrence
  hasClauseMembership ClauseMembership

ClauseMembership
  member ClauseOccurrence
  position 0
  inSequence CallableDefinitionOccurrence
```

Apply the same pattern to:

- function clauses;
- parameters and arguments;
- guard alternatives and expressions;
- body expressions;
- tuple/list/map entries where full AST is retained;
- route declarations;
- supervisor children;
- Ecto.Multi operations;
- compiler phases;
- release applications.

SHACL should require one item, one sequence, one non-negative position, and
position uniqueness within a sequence. Contiguity is profile-specific; generated
or partial graphs may intentionally preserve gaps.

### Relation observations

Use direct edges only for exact structural containment whose meaning and
provenance are graph-wide and unambiguous. Reify uncertain, analyzer-dependent,
temporal, or disputable relations:

```text
RelationObservation
  relationSubject InvocationOccurrence
  relationKind possibleTarget
  relationObject CallableDefinitionOccurrence
  certainty staticMay
  generatedBy ResolutionActivity
  validForSnapshot RepositorySnapshot
  analysisProfile ResolverProfile
  confidenceValue 0.82
  limitation UnresolvedMacroExpansion
```

Initial certainty concepts:

| Concept | Meaning |
| --- | --- |
| `authoredExact` | Directly represented by exact source bytes |
| `quotedExact` | Direct parser output under exact parser/options |
| `compilerExactUnderConfiguration` | Established by pinned compiler/toolchain/configuration |
| `staticMay` | Possible under a documented static model |
| `staticMustUnderModel` | Required only under stated model and assumptions |
| `derivedRule` | Produced by a versioned inference rule |
| `runtimeObserved` | Observed in one exact execution interval |
| `lexicalFallback` | Textual association without semantic resolution |
| `unresolved` | Occurrence found but target/meaning could not be resolved |

Do not define an unqualified universal `calls` relation.

## Elixir Language ontology

### Modules

Required distinctions:

| Class | Meaning |
| --- | --- |
| `ModuleSymbol` | Conceptual Elixir module atom/name |
| `ModuleDeclarationOccurrence` | Authored/generated `defmodule` occurrence |
| `ModuleBodyOccurrence` | Lexically scoped body of one declaration |
| `NestedModuleDeclaration` | Declaration syntactically nested in another body |
| `ExpandedModule` | Module produced after macro expansion |
| `BeamModuleArtifact` | Compiled BEAM representation |
| `LoadedModuleVersion` | Current or old code loaded on a node during an interval |

Rules:

- module-name segments are not ownership or package hierarchy;
- one file may define many modules;
- one module may be generated from multiple source inputs;
- syntactic nesting is not inferred from the module name;
- a module symbol is an atom-level language identity, while string rendering is
  a label;
- `.ex` and `.exs` share language semantics but differ in expected build/lifecycle
  use;
- external Erlang module symbols use the Erlang naming convention, not an
  invented Elixir namespace wrapper [EL01, EL03, OTP01].

### Functions and macros

Use disjoint function, macro, and special-form symbol kinds:

- `FunctionSymbol`;
- `MacroSymbol`;
- `SpecialFormSymbol` for compiler forms, not ordinary definitions.

`GuardMacroSymbol` is a subclass or role of `MacroSymbol`, not a disjoint kind.
`defguard` and `defguardp` define macros, while some guard-usable operations are
built-in functions. Model guard usability separately from callable kind.

Identity includes:

```text
module symbol
callable kind
name atom
arity
```

Function and macro with the same module/name/arity are not one symbol. Visibility
is a property of declarations/exports, not part of conceptual callable identity.

Required classes and relations:

| Class/relation | Purpose |
| --- | --- |
| `CallableDefinitionOccurrence` | Snapshot/profile-scoped aggregate for one module occurrence plus callable kind/name/arity |
| `FunctionClauseOccurrence` | One ordered `def`/`defp` clause form within a function definition occurrence |
| `MacroClauseOccurrence` | One ordered `defmacro`/`defmacrop` clause form within a macro definition occurrence |
| `hasClauseMembership` | Ordered relation from callable definition occurrence to clause occurrence |
| `ParameterPatternOccurrence` | Parameter pattern at a clause position |
| `DefaultArgumentOccurrence` | Authored default expression and parameter position |
| `GeneratedArityBridge` | Compiler/macro-generated forwarding arity relation |
| `FunctionCaptureOccurrence` | Named `&Module.fun/arity` or closure capture occurrence |
| `ClosureOccurrence` | Anonymous function expression with captured environment observations |
| `OverridableDeclarationOccurrence` | `defoverridable` declaration targeting callable name/arity pairs |
| `SuperInvocationOccurrence` | Invocation of the prior overridable implementation from an overriding definition |

Default arguments do not create runtime optional parameters. They produce
additional callable arities or forwarding definitions. The ontology must record
the authored default relation separately from generated callable artifacts
[EL03, EL11, EL13].

`CallableDefinitionOccurrence` is required even when each clause is written as a
separate `def` form. It is scoped to one exact module occurrence, snapshot, and
analysis profile, and owns the complete ordered clause sequence for that
callable. It must not be replaced by the cross-snapshot conceptual symbol.

`defoverridable`, an overriding definition, and `super` form a compile-time
lineage rather than class inheritance. This is common in `use`-based DSLs. An
agent changing generated callbacks needs the original definition, overridable
declaration, override, and `super` invocation path, with expansion provenance
[EL13].

### Clauses, patterns, and guards

Clause order is semantic because matching proceeds in order [EL02, OTP01]. A
clause contains:

- ordered parameter patterns;
- zero or more guard alternatives;
- an ordered body/expression root;
- authored or generated span;
- relation to its callable symbol/declaration;
- optional residual-type observations from a compiler analysis.

Pattern classes should include at least:

- variable, wildcard, pinned variable;
- literal and value pattern;
- alias/match pattern;
- tuple, list, cons, map, struct, binary, and bitstring pattern;
- capture and as-pattern where supported;
- remote/local struct/module references;
- pattern sequence membership.

Variable names are not variable identities. Model `VariableBindingOccurrence`
and `VariableUseOccurrence`. A later match may rebind the same textual name. A
pin refers to an existing binding. Each binding has lexical scope and optional
compiler variable identity/context [EL02, EL09-EL12].

Guard modeling must preserve:

- guard alternative order/grouping;
- restricted guard operation semantics;
- positive and negative refinement observations only when emitted by a versioned
  analyzer;
- the rule that a guard error makes that guard fail rather than behaving like a
  normal body exception;
- provenance of custom guard macros and their expansions [EL02, EL11].

### Expressions and control forms

Do not require the full expression graph for every agent task. Provide profiles:

| Profile | Content |
| --- | --- |
| `structural` | Declarations, clauses, directives, spans, syntactic references |
| `expression` | Full quoted or expanded expression occurrences and ordering |
| `controlFlow` | Analyzer-produced control-flow observations |
| `dataFlow` | Analyzer-produced definitions/uses/flow observations |
| `typeFlow` | Compiler/Dialyzer typing assertions and refinements |

Expression classes should follow actual Elixir forms, but avoid a separate OWL
class for every parser tuple when a controlled kind plus required shape is more
stable. Important explicit classes include invocation, match, block, anonymous
function, case, cond, with, for, try/rescue/catch/after/else, receive/after,
raise/throw/exit, quote/unquote, comprehensions, map/struct update, and send.

Do not reuse JidoCode `Decision` for a conditional or `Agent` for Elixir's OTP
Agent. Domain names must be source-specific.

### Lexical directives

`alias`, `import`, `require`, and `use` are lexically scoped occurrences, not
global module edges [EL04, EL10, EL12].

| Directive | Proper meaning |
| --- | --- |
| `AliasDirectiveOccurrence` | Introduces a module-name alias in a lexical scope |
| `ImportDirectiveOccurrence` | Makes selected function/macro name-arity pairs available unqualified |
| `RequireDirectiveOccurrence` | Makes remote macros available for expansion |
| `UseDirectiveOccurrence` | Invokes target `__using__/1` macro with arguments in a caller environment |

Each directive needs:

- exact source span and scope;
- target syntax and resolution observation;
- only/except selectors where applicable;
- compiler environment before/after if captured;
- expansion activity for `use`;
- generated definitions/aliases/imports as outputs.

Do not infer inheritance, behaviour implementation, runtime use, or package
dependency from `use` alone.

### Module attributes and documentation

Model attribute operations rather than one timeless key/value property:

- declaration/registration;
- put/write occurrence;
- read occurrence;
- accumulate/persist options;
- value at a compilation program point;
- generated versus authored operation;
- selected BEAM `Attr` or docs/debug artifact representation.

Built-in semantic attributes need specialized links:

- `@moduledoc`, `@doc`, `@typedoc`, `@deprecated`, `@since`;
- `@spec`, `@type`, `@typep`, `@opaque`, `@callback`, `@macrocallback`;
- `@behaviour`, `@impl`, `@optional_callbacks`;
- `@derive`, `@enforce_keys`;
- `@compile`, `@external_resource`, `@on_definition`, `@before_compile`,
  `@after_compile`, and related hooks.

Documentation text is governed content, not a structural literal that must always
enter RDF. Structural graphs can retain digest, language/format, metadata, and a
content reference. EEP-48 `Docs` chunks and authored docs are distinct entities
[EL05, OTP11].

### Behaviours and callbacks

Required classes:

- `BehaviourSymbol` or module playing a behaviour role;
- `BehaviourAdoptionOccurrence` from `@behaviour`;
- `CallbackSymbol` with function/macro kind, name, arity;
- `CallbackDeclarationOccurrence`;
- `OptionalCallbackDeclaration`;
- `ImplementationClaimOccurrence` from `@impl`;
- `CallbackImplementationObservation`;
- `BehaviourConformanceDiagnostic`.

Behaviour conformance is primarily compiler/tooling validation, not runtime
dispatch enforcement. Keep separate:

- the callback name/arity/kind contract;
- the callback's traditional typespec;
- an `@impl` source claim;
- an implementation occurrence;
- a compiler conformance observation;
- a runtime call observation [EL06, EL13].

### Protocols and implementations

Protocols are runtime polymorphic APIs dispatched primarily from the first
argument's type; they are not behaviours [EL07, EL19].

Required classes/relations:

- `ProtocolSymbol` and declaration occurrence;
- `ProtocolFunctionSymbol` and declaration occurrence;
- `ProtocolImplementationSymbol` and `defimpl` occurrence;
- `implementationForDispatchType`;
- `fallbackToAny`;
- `DeriveOccurrence` and derivation options;
- generated implementation activity;
- `ProtocolConsolidationActivity`;
- consolidated protocol BEAM artifact;
- exact implementation inventory/digest;
- build-scoped dispatch resolution observation.

A protocol also generates a traditional `t/0` typespec. Model that as a generated
type declaration associated with the protocol and its expansion activity, not as
the protocol resource itself and not as an Elixir gradual type signature
[EL06-EL07, EL19].

An implementation declared after protocol consolidation may not affect the
consolidated artifact. Source declaration, available BEAM implementation, and
active consolidated dispatch are separate facts. Negative claims such as "no
implementation" require a closed implementation inventory for a particular
build artifact.

### Structs, maps, and exceptions

Distinguish:

- `StructSymbol` associated with a module;
- `StructDeclarationOccurrence`;
- `StructFieldSymbol` and field membership/order;
- field default expression occurrence;
- enforced-key declaration;
- struct literal/construction/update/pattern occurrence;
- runtime struct value only if observed, never as a source symbol;
- `ExceptionDeclarationOccurrence` and generated exception callbacks.

A struct is a fixed-key map shape with `__struct__`; it is not an object instance
with mutable identity. The struct module, field symbol, source field occurrence,
type declaration, and runtime value remain separate [EL08].

## Macro and generated-code ontology

Macro semantics require provenance, not only syntax [EL09-EL14].

### Required resources

| Resource | Meaning |
| --- | --- |
| `MacroInvocationOccurrence` | Authored or generated invocation site |
| `MacroDefinitionOccurrence` | Macro declaration used by expansion |
| `QuoteOccurrence` | Quoted AST construction |
| `UnquoteOccurrence` | AST/value insertion point |
| `CallerEnvironment` | Versioned projection of `Macro.Env` relevant to expansion |
| `MacroExpansionActivity` | Compiler/macro execution under exact inputs and sandbox profile |
| `ExpandedAstArtifact` | Deterministic representation/digest of expansion output |
| `src:GeneratedOccurrence` | Source Core declaration/expression occurrence generated by expansion |
| `HygieneContext` | Variable/alias/import hygiene context where retained |
| `ExpansionOmission` | Policy-denied, unsafe, failed, unsupported, or unavailable expansion |

### Expansion provenance

An expansion activity should record:

- exact caller source snapshot and invocation span;
- macro definition occurrence or BEAM artifact;
- Elixir/OTP/compiler versions;
- caller `Macro.Env` projection and digest;
- aliases/imports/requires/functions/macros relevant to resolution;
- Mix environment/target and compilation options;
- dependency lock and loaded macro module digests;
- external resources and declared non-secret environment inputs;
- sandbox/network/filesystem/secret/resource policy;
- output AST digest and generated occurrences;
- warnings, diagnostics, failure, and coverage.

The baseline source profile must not execute untrusted macros. A compiler-derived
profile may run only in a governed sandbox. Failure to expand produces an
explicit omission, not an empty complete graph.

### Authorship

Do not propagate human authorship through `prov:wasDerivedFrom`. Generated code
can be attributed to the expansion activity and associated software/human agents,
but "the user authored every generated line" is a separate and usually invalid
claim.

## Type ontology

Elixir 1.20 has three typing-related systems that must not be collapsed
[EL06, EL15, OTP12, OTP16-OTP18].

| System | Origin | Semantics |
| --- | --- | --- |
| Traditional Erlang/Elixir typespec | Authored or macro-generated `@type`, `@spec`, `@callback`, and related declarations | Documentation and analyzer input; no runtime effect |
| Dialyzer success typing | Dialyzer analysis over BEAM/Core/specs/PLT | Inferred success sets and discrepancy warnings; intentionally incomplete |
| Elixir gradual set-theoretic type | Exact Elixir compiler analysis | Inferred function/program-point information and diagnostics using unions, intersections, negation, dynamic bounds, patterns, guards, and control flow |

### Type expressions are data, not OWL classes

Represent a type-language AST using individuals:

```text
TypeExpression
  inTypeSemanticSystem TraditionalElixirTypespec
  inTypeLanguageVersion ElixirTypespec_1_20
  expressionKind UnionType
  hasOperandMembership ...
  structuralDigest ...
```

Do not make a program type such as `integer()` an OWL class of RDF resources.
That would conflate language-level value sets with ontology classification and
make type-system evolution dependent on OWL semantics.

### Traditional type declarations

Model:

- public/private/opaque type symbol by module/name/arity;
- declaration occurrence and type parameters;
- exact type-expression AST;
- spec clause and function/callback target;
- generated versus authored declaration;
- source span and BEAM debug-form correspondence;
- declaration dialect and Elixir/OTP version.

### Dialyzer

Model at least:

- `DialyzerAnalysisActivity`;
- `PersistentLookupTableArtifact` and digest/kind;
- analyzed module/artifact inventory;
- `DialyzerSuccessTyping`;
- authored declared spec input;
- effective inferred/spec intersection where reported;
- raw warning tag and normalized `DialyzerDiagnostic`;
- warning options, suppressions, source/BEAM mode, and `--no_spec` state;
- Dialyzer/OTP versions and coverage.

An empty warning set is `NoDiagnosticObserved` under one run, not `TypeSafe`.

### Gradual set-theoretic compiler analysis

Elixir's type system evolved substantially from 1.17 through 1.20. In 1.20 all
language constructs participate in best-effort inference/checking, with guard
inference, whole-body inference, ordered-clause refinement, occurrence typing,
and map-domain reasoning. User-authored set-theoretic signatures, typed structs,
and other roadmap items remain evolving/future [EL15, EL20-EL23].

Required resources:

- `ElixirTypeAnalysisActivity` with exact compiler build;
- `InferredFunctionSignature`;
- `VariableBindingVersion`;
- `ProgramPoint` tied to an expression occurrence;
- `FlowTypeAssertion`;
- `TypeRefinement` with before/constraint/after type and polarity;
- `PatternAcceptanceObservation`;
- `GuardRefinementObservation`;
- `ClauseResidualTypeObservation`;
- `BranchJoinObservation`;
- `TypingDiagnostic` and raw compiler diagnostic;
- analysis coverage and unavailable/unsupported evidence.

Never use `owl:sameAs` between traditional, Dialyzer, and set-theoretic type
expressions. A versioned `TypeTranslationAssessment` may classify a translation
as exact, over-approximation, under-approximation, partial, or unsupported.

### BEAM type and documentation evidence

Relevant BEAM evidence includes:

- `Dbgi` debug information and backend identity;
- Erlang abstract forms containing traditional specs/types/callbacks;
- `ExCk` private Elixir checker cache and exact internal checker version;
- persisted `Attr` attributes;
- `CInf` compile information.

EEP-48 `Docs` display signatures are documentation/callable-correspondence
evidence only. They exist for presentation and must not produce type assertions
[OTP11].

Chunks are optional, version-sensitive, and may be stripped or encrypted. The
official `beam_lib` contract treats backend debug payload as opaque [OTP06-OTP08].
An experimental `ExCk` adapter must bind an exact Elixir build/checker identifier,
retain the raw chunk digest, fail closed on unknown schema, and never present the
decoded cache as a stable source declaration.

## Mix, application, package, and build ontology

### Distinct identities

Do not merge:

- Mix project;
- OTP application;
- umbrella child project/application;
- Hex package;
- dependency declaration;
- lockfile resolution;
- downloaded distribution;
- source repository;
- build artifact;
- release;
- deployed workload.

Names can differ across these resources [EL24-EL28, OTP03].

### Mix project and configuration

Model:

- project module/declaration;
- project evaluation activity;
- application name/version/build paths/source paths;
- Mix environment and target;
- compiler sequence and custom compiler tasks;
- aliases and task invocations;
- `elixirc_options`, `erlc_options`, and relevant compiler options;
- config sources, providers, imports, and runtime/compile-time distinctions;
- umbrella root and child relationships;
- release definitions;
- external environment input references without secret values.

`mix.exs` and configuration are executable Elixir. Extracting values may execute
project code. Use syntax-only declarations by default and a governed build
evaluation profile for computed values.

### Dependencies and locks

Required classes:

- `DependencyDeclarationOccurrence`;
- package/application target;
- version requirement;
- source kind: Hex, Git, path, umbrella, SCM;
- environment/target/optional/runtime/build flags;
- override, environment `only`, target, optional, runtime, and other actual Mix
  dependency option semantics;
- `LockfileArtifact` and `LockEntry`;
- resolved package/repository revision/checksum;
- downloaded distribution digest;
- package release coordinate, preferably with purl mapping where applicable
  [ST27].

Separate relation kinds:

- source module reference;
- lexical import/require/use;
- compile dependency;
- Mix dependency declaration;
- resolved package dependency;
- OTP application start dependency;
- runtime observed service dependency.

Never make a broad cross-domain `dependsOn` transitive.

### Build activity

A build activity must bind:

```text
source snapshot and generated-source inventory
dependency lock and submodule digests
Elixir, OTP, Mix, compiler, and toolchain builds
Mix environment and target
compiler/profile/options digest
declared non-secret environment and external inputs
network, sandbox, and filesystem policy
start/end time and accountable actors
diagnostics and completeness
output artifact digests
```

Generated source outside the Git tree belongs to build provenance. It may receive
a source occurrence in a build-scoped graph, but must not be presented as an
authored occurrence in the repository snapshot.

### Releases

Distinguish a release definition, release build activity, release metadata,
release artifact/directory, included applications, optional ERTS, boot scripts,
runtime configuration providers, and a deployed release instance [EL27, OTP15].

## BEAM artifact ontology

### Required classes

- `BeamArtifact`;
- `BeamModuleArtifact`;
- `BeamChunk` and specialized known chunk kinds;
- `ExportEntry`, `ImportEntry`, and local function entry;
- `CompileInformation`;
- `DebugInformationArtifact`;
- `DocumentationChunk`;
- `ApplicationSpecificationArtifact` (`.app`);
- `BootScriptArtifact`;
- `ReleaseArtifact`;
- `LoadedModuleVersion`.

### Correspondence

A BEAM module can correspond to multiple authored/generated inputs. Exports do
not prove whether a function was authored directly, generated by defaults,
generated by a macro, or emitted by a protocol/struct/exception compiler step.
Use `CompilationCorrespondenceObservation` with exact compiler provenance.

### Hot code loading

The runtime may keep current and old code for a module simultaneously. External
calls generally enter current code while processes may remain in old code until
they leave it [OTP05]. Model:

- loaded module artifact digest;
- node and code server observation;
- current/old status;
- valid-time interval;
- load/purge activity;
- process execution observation linked to the loaded version.

Presence on disk, code path availability, loaded current code, and process use
are separate facts.

## OTP declaration and runtime ontology

The most important rule is:

> A source module implementing an OTP behaviour is not a runtime process.

### Static implementation classes

- `ApplicationImplementation`;
- `GenServerImplementation`;
- `SupervisorImplementation`;
- `DynamicSupervisorUsage`;
- `AgentUsage` or `AgentServerImplementation`;
- `TaskInvocationOccurrence` and `TaskSupervisorUsage`;
- `GenStateMachineImplementation`;
- `ChildSpecDeclaration`;
- `ProcessRegistrationDeclaration`;
- `MessageSendOccurrence` and callback/message-pattern declarations.

### Runtime classes

- `RuntimeNode`;
- `RuntimeNodeIncarnation` with node name and creation/incarnation evidence;
- `ProcessInstance` with node incarnation plus PID ID/serial/creation components
  and a valid-time interval;
- `ApplicationInstance`;
- `SupervisorProcessInstance`;
- `ChildProcessInstance`;
- `MessageSignalObservation`;
- `MessageReceiveObservation`;
- `CallRequestObservation`, `ReplyObservation`, `CastObservation`;
- `LinkObservation`, `MonitorObservation`, `ExitSignalObservation`;
- `RegistrationObservation`;
- `EtsTableInstance` and ownership/heir observations;
- `NodeConnectionObservation`;
- `PortInstance` and native boundary observation.

A printed PID and node name are not sufficient durable identity because a node
name can recur after restart. OTP external PID identity includes node, ID,
serial, and creation. The graph should preserve those components when available,
plus observation provenance and interval, without pretending a runtime PID is a
cross-restart conceptual process identity [OTP02, OTP19].

### Applications

Distinguish application specification, loading, starting, running, stopping, and
unloading. Loading an application does not load every module, and loading module
code does not start the application [OTP03]. Application dependency determines
declared start order, not every runtime call.

### GenServer and message semantics

The callback module, registered name, and process instance are separate [EL16,
OTP02]. Many processes may execute one callback module. A process may execute
different loaded versions over time.

Model call, cast, ordinary send, receive, and callback dispatch distinctly. A
call timeout does not prove the server failed to process the request later. A
send observation does not prove receipt or business success. Selective receive
means mailbox consumption is not simple global FIFO, although signal ordering is
preserved from one sender to one receiver [OTP02].

### Supervision

Static child specifications need:

- child identifier;
- start MFA or start invocation expression;
- restart type;
- shutdown policy;
- worker/supervisor type;
- modules metadata;
- source/expanded/build origin;
- ordered membership in a supervisor declaration;
- strategy, restart intensity, and period.

Runtime child process instances and restart events are separate. One child spec
can yield many process instances across restarts. Static and dynamic supervisor
inventories have different closure semantics [OTP04].

### Links, monitors, registries, ETS, and distribution

- Links are bidirectional exit-propagation relations; monitors are unidirectional
  observations that yield `DOWN` signals.
- Registered names are mutable indirections, not process identity.
- Registry uniqueness mode, key, value, registry process, and valid interval are
  required [EL17].
- ETS table name/identifier, owner, heir, access mode, type, key position, and
  lifecycle are runtime facts. Table contents should not enter a source ontology
  [OTP09].
- Distributed node name, connection interval, remote PID/reference/port, and
  observation time are required. A node name does not imply current connection
  [OTP10].
- Ports preserve process/message boundaries; NIFs and linked-in drivers execute
  native code with different risk and observability [EL18, OTP13-OTP14].

## Framework overlay ontologies

Framework semantics should not enter the stable language core. Each overlay
declares supported framework versions, macro/compile profile, coverage, and
certainty.

### Phoenix

Potential classes:

- endpoint, router, scope, pipeline, plug declaration;
- ordered route declaration and route helper;
- controller/action dispatch;
- channel/socket/topic/event;
- generated route function correspondence;
- endpoint/supervision runtime instance;
- request/response/trace observation.

Routes are compile-time DSL declarations matched in order. The authored router
form, expanded functions, runtime route metadata, and observed request are
different layers [ECO02-ECO03].

### LiveView

Model LiveView module/callback declarations, disconnected render, connected mount,
server process instance, socket state observation, assigns, events, components,
render output/diff, transport, and reconnect lifecycle. A browser view identity
is not the same as one server process [ECO04].

### Ecto

Model schema declaration, source/table mapping, fields, associations, embeds,
changeset operations, query AST, Repo invocation, adapter, migration operation,
database object reference, and Ecto.Multi ordered operation [ECO05-ECO09].

Do not equate:

- schema module with database table;
- query construction with query execution;
- changeset validation with database constraint enforcement;
- migration source with deployed database state;
- Multi plan with committed transaction.

### Telemetry

Model event-name schema/declaration, handler attachment, emitted event observation,
measurements, metadata schema, span start/stop/exception, instrumentation scope,
and sampling/coverage. Telemetry handlers run synchronously in the emitting
process, but event observations remain partial [ECO01]. Map runtime telemetry to
OpenTelemetry where available rather than asserting identity [ST32].

### Jido overlay

A Jido-specific source overlay can model action/agent/sensor/skill/workflow
declarations and signal schemas. It must use source-specific names such as
`JidoAgentDeclaration` and never equate a source declaration with JidoCode's
`jf:Agent` software-agent identity. `jf:Agent` class membership itself grants no
authority; a current actor grant and, for delegated execution, a matching
delegation remain mandatory.

## Actors, users, organizations, and stewardship

User information is useful for collaboration, provenance, routing review, and
historical explanation. It is also privacy-sensitive and dangerous if confused
with authorization.

### Actor model

Use these distinct classes:

| Class | Meaning |
| --- | --- |
| `prov:Agent` | Broad entity bearing responsibility in provenance |
| `foaf:Person` | Human person, used selectively |
| `org:Organization` | Institutional agent |
| `org:OrganizationalUnit` | Team/unit within an organization |
| `ExternalAccount` | Provider/issuer-scoped account identity |
| `AuthenticatedPrincipal` | Security principal established for one issuer/session/context |
| `SoftwareAgentDefinition` | Versioned software system/agent identity |
| `SoftwareAgentInstance` | One execution/instance of software agent |
| `ServiceAccount` | Non-human account with issuer/scope |
| `RuntimeWorkloadIdentity` | Deployment/workload identity such as SPIFFE input |
| `CredentialReference` | Reference to secret material, never the value |

JidoCode already has `Actor` and software `Agent` identities used by the authority
model, but class membership grants no authority. External people, accounts, and
organizations require a future privacy-policy and ontology/shape decision before
catalog admission. Current personal data is limited to governed
`security_audit`, and current catalog admission covers `Actor`/`Agent`, not
general person/account/organization profiles. Any future observations must be
reconciled explicitly before a resource can act, and acting still requires an
exact current grant plus delegation where applicable [JC02-JC04, JC09-JC11].

### Identity rules

- Account identity uses provider/issuer plus stable provider subject ID.
- Git author name/email is an authored commit claim, not a reconciled person.
- Display names are labels and can change or collide.
- Email is optional classified personal data, not canonical identity.
- OIDC subject, SCIM user, provider account, signing certificate, SSH key, and
  Git author are different identity assertions.
- Never merge agents solely by name, email hash, username, or certificate subject.
- `owl:sameAs` requires proven identity; use weaker reconciliation claims.
- Credentials, tokens, cookies, private keys, and secret values never enter RDF.

### Roles and memberships

Use qualified, temporal assignments:

```text
RoleAssignment
  assignedAgent
  role
  scopeResource
  validFrom / validTo
  assertedBy
  generatedBy
  sourceSystem
  supersededOrRevokedBy
```

Potential descriptive roles:

- author, committer, contributor;
- maintainer, steward, accountable owner;
- CODEOWNER;
- reviewer, approver, releaser;
- security contact, on-call responder;
- builder, signer, deployer;
- bot, CI runner, coding agent operator.

Use ORG membership and PROV qualified associations/`hadRole` where their
semantics fit [ST01, ST03]. Preserve conflicting ownership sources rather than
silently choosing one.

### Authorship, stewardship, and authorization

These do not imply one another:

```text
authored code
!= maintains repository
!= owns service
!= belongs to team
!= authenticated principal
!= authorized command actor
```

CODEOWNERS and Backstage-style ownership are descriptive routing/stewardship
facts. They never grant graph, tool, publication, evidence-acceptance, or decision
authority. Current command authorization evaluates the coherent policy snapshot
at trusted envelope `issued_at`; reviewed catalog queries authorize their
coherent snapshot before SPARQL evaluation; runtime effects reauthorize
immediately before dispatch. Future source retrieval must additionally authorize
scope-keyed lexical, graph, embedding, and cache paths before candidate
generation [JC09-JC11].

### Data minimization

Retain only actor data needed for a declared competency question and purpose.
Classify optional profile fields. Preserve issuer IDs and provenance rather than
copying provider profiles. Apply retention, erasure, legal hold, redaction, and
model-egress policy to personal data and derived indexes [ST08-ST09, JC10,
JC17-JC18, JR01-JR02].

## Provenance ontology

PROV-O is the backbone [ST01]. The ontology should use:

- `prov:Entity` for source snapshots, artifacts, AST/graph segments, build
  outputs, reports, and attestations;
- `prov:Activity` for parsing, analysis, expansion, compilation, build, load,
  execution, query, retrieval, model/tool invocation, and validation;
- `prov:Agent` for humans, organizations, software agents, builders, analyzers,
  and services;
- `prov:used`, `wasGeneratedBy`, `wasDerivedFrom`, `wasAssociatedWith`, and
  qualified usage/generation/association when role or context matters;
- PROV bundles or named graphs for provenance scope where supported.

### Analysis activity minimum

Every analysis activity should record:

- analyzer software agent and executable/package digest;
- analyzer version, source revision, ontology release, and shape profile;
- exact repository snapshot and artifact inputs;
- parser/compiler/build versions;
- configuration/options digest;
- dependency lock, generated source, and build-profile inputs where relevant;
- actor, purpose, authorization scope, and sandbox profile;
- start/end/recording time;
- result manifest/segments and canonical digests;
- coverage, unsupported units, failures, truncation, and timeout;
- deterministic/reproducibility status.

### Time

Use OWL-Time patterns for intervals and instants [ST02], while preserving
JidoCode's existing valid/recorded/invalidation semantics. Distinguish:

- source commit author/committer time;
- analysis execution time;
- graph recording/transaction time;
- fact valid time;
- runtime observation interval;
- loaded-code interval;
- role/membership interval;
- evidence evaluation time;
- policy/grant validity interval.

### Provenance is not truth

A perfectly attributed analyzer can be wrong. PROV establishes who/what produced
a statement and from which inputs. It does not establish semantic correctness,
authorization, or acceptance. Keep certainty, evidence, validation, and governed
decision state explicit.

## VCS and evolution ontology

### Git model

Map Git's object model directly [ST37]:

- algorithm-qualified blob, tree, commit, and annotated-tag objects;
- commit parent edges;
- commit root tree;
- author and committer identity claims/timestamps;
- refs as mutable observations;
- repository origin/locator separate from conceptual repository;
- checkout/worktree state separate from immutable objects.

Do not call a commit a source snapshot when source identity is based on its tree.
Do not infer authorship of every line from commit authorship.

### Changes

Represent additions, deletions, modifications, moves, copies, and semantic symbol
continuity as analysis observations between exact snapshots. A rename detector's
result is not identity and does not rewrite old resources.

### Software Heritage

SWHIDs are valuable archival external identifiers for content, directories,
revisions, releases, snapshots, and origins [ST38]. Map them to local resources
where exact correspondence is proven. Archive presence does not prove current
repository state, ownership, license, or authority.

## Quality, tests, diagnostics, and evidence

### Test declarations versus executions

Source graphs may contain:

- test module/case declarations;
- generated test function correspondence;
- tags and source spans;
- setup/setup_all declaration relationships;
- doctest declaration/source relationships;
- static references to code under test.

Run/evidence graphs contain:

- suite/case/test execution;
- exact code/artifact/build under test;
- environment, seed, shard, async mode, retries;
- pass/fail/skip/exclude/timeout/infrastructure-error outcome;
- assertion/failure/stack-frame evidence;
- coverage observations;
- selection and omission reasons;
- flake assessments across runs [EL29-EL30].

A passing test proves only that execution under its exact inputs. A coverage edge
means an execution observed an occurrence; it does not prove correctness.

### Diagnostics

Model diagnostic source, tool/run, severity, stable code/tag if available,
message artifact/reference, exact location/span, related locations, rule,
configuration, suppression, baseline state, code flow, and fix proposal.

SARIF is a strong interchange format for analyzer runs, rules, results, physical
and logical locations, fingerprints, code flows, fixes, and suppressions [ST48].
Map admitted fields to local resources while retaining the original document
digest and mapping provenance. A SARIF result is a tool finding, not a confirmed
defect.

EARL provides useful test-subject, criterion, result, assertor, and outcome
patterns [ST21]. Use it as an alignment, not as a replacement for JidoCode's
evidence and acceptance boundaries.

### Claims and acceptance

JidoCode's qualified `Claim` pattern is appropriate for disputable findings.
Source graphs can support a claim, but they cannot accept evidence, approve a
decision, satisfy a goal, or adopt memory. Those remain governed commands in
their existing graph families [JC12-JC16].

## Packages, licenses, and software supply chain

### Native-format mappings

| Standard | Use | Local posture |
| --- | --- | --- |
| SPDX 3.0.1 | Packages, files, snippets, relationships, licensing, security profiles | Map and retain original document/digest [ST22] |
| CycloneDX 1.7 | Components, services, dependency graph, composition, vulnerabilities, formulation | Map without flattening composition/scope [ST23] |
| CodeMeta/DOAP/schema.org | Project discovery, citation, maintainer, language, repository metadata | Selected mappings, not internal lifecycle truth [ST24-ST26] |
| purl | Ecosystem package coordinate | Use as external identifier, never content identity [ST27] |
| SLSA | Assurance tracks, provenance requirements, levels | Versioned assessment, not intrinsic artifact class [ST33] |
| in-toto | Subject digests and typed attestations | Preserve native predicate/envelope [ST34] |
| DSSE | Signed exact payload envelope | Signature does not establish truth [ST35] |
| Sigstore | Certificate/signature/transparency evidence | Separate identity claim, signature, log inclusion, and policy [ST36] |

### Licenses

Distinguish:

- declared license expression;
- concluded license assessment;
- package/file/snippet scope;
- license text/artifact digest;
- detector or human assessor;
- evidence and confidence;
- compatibility/policy decision;
- source ontology/software artifact license.

The package metadata and repository license declare MIT, while the core,
structure, OTP, and evolution ontology files declare CC BY 4.0 and the SHACL file
has no embedded license statement. License provenance must therefore be explicit
rather than represented by one repository-level assertion [EO01-EO06].

### Vulnerabilities and VEX

Model an advisory as a publisher-authored claim bundle. Connect:

```text
advisory
  -> affected ecosystem/package/range claim
  -> exact resolved package or artifact assessment
  -> build/deployment context
  -> VEX applicability statement
  -> evidence, reviewer, decision, and valid time
```

Use OSV for ecosystem ranges, CSAF for product trees/status/remediation, and
OpenVEX or CycloneDX VEX for contextual status [ST23, ST49-ST51]. Do not mark an
entire repository vulnerable from a package-name string match.

## Runtime, deployment, and observations

Separate three states:

| State | Example |
| --- | --- |
| Declared | Source/config says application A starts worker B or service A may call B |
| Deployed/loaded | Artifact digest X is deployed and module version Y is loaded in environment Z |
| Observed | Trace/event/test run observed instance A calling endpoint B |

Runtime concepts do not belong in immutable source segments. Attempt-scoped
runtime observations may use `run_attempt`; external provider/CI observations may
use an admitted `observation_batch`; governed verification belongs in `evidence`;
and general fleet/runtime topology needs a newly accepted ontology, shape, and
family-placement contract. Every deployment should trace through build artifact
digest and build provenance to an exact source snapshot.

OpenTelemetry signals are observations, not an execution-completeness guarantee:
traces may be sampled, log records may be filtered or dropped, and metric streams
aggregate measurements [ST32]. Record instrumentation scope, resource, sampling,
trace/span IDs, timestamps, and mapping provenance. Do not equate one span with a
complete execution history.
SOSA/SSN observation patterns can help model procedures, features of interest,
results, and sampling [ST20], but a compiler or scanner is not automatically a
physical sensor.

## Work, issues, reviews, and annotations

Provider issues, requirements, pull requests, reviews, discussions, and comments
are external observations until adopted by a governed control/decision command.

Use Web Annotation for a review/finding body targeting an exact source artifact,
span, diff hunk, or graph resource [ST05-ST06]. Target state/selectors must bind
the exact patchset or artifact digest because line offsets drift.

OSLC Change Management provides useful external mappings for change requests,
status, priority, and related change resources [ST29]. Provider-specific states
remain provider values; they are not automatically equivalent to JidoCode work
states.

## Agent, retrieval, and context provenance

The ontology should preserve:

```text
request -> goal -> plan -> task -> context package
  -> model/tool invocation -> edit proposal -> patch
  -> result tree/candidate commit -> verification -> review -> decision
```

This lineage belongs in existing repository-control, run-attempt, evidence,
memory, and security-audit families, not the source graph.

### Retrieval activity

Record:

- authenticated actor, purpose, task, plan phase, and capability scope;
- for the future source-retrieval contract, authorization decisions before
  lexical/graph/embedding/cache candidate generation;
- repository/snapshot and exact graph revisions;
- reviewed query name/version/parameters and consistency receipt;
- retriever/ranker versions and candidate channel;
- score components as observations, not universal confidence;
- selected and omitted candidates with reasons;
- budgets, truncation, degree caps, and unexpanded frontier;
- exact source spans read and content classifications;
- context items delivered to the model;
- model/provider/sink permit and content-access consumption;
- later usefulness, harm, contradiction, or invalidation observations.

The current execution context package cannot be replaced by a source ontology.
A future compiler validates query receipts, then supplies selected `source_items`
and exact source graph revisions into the existing package. The package validates
identity form and execution constraints such as plan, lease, fence, effect
subset, budget, omission, and digest. Query authorization, actor grants and
delegation, authorized-agent availability/capability, and immediate effect
authorization remain separate boundaries [JC09, JC11, JC13-JC14].

### Patches

A patch artifact needs:

- exact base snapshot/tree;
- normalized patch/content digest;
- affected artifact and symbol occurrence observations;
- producing model/tool invocation;
- proposed result tree;
- apply/conflict/partial/rejected status;
- validation/build/test outcomes;
- later review/decision lineage.

Patch production does not grant publication authority or prove correctness.

## Privacy, access, retention, and erasure

### Governance metadata

Track:

- classification and handling policy;
- purpose and permitted sink/model profile;
- retention class and expiry;
- legal hold;
- erasure state/generation;
- redaction activity;
- content-access permit and consumption;
- export/cache/index/model-derivative obligations;
- audit requirements.

DPV supplies useful privacy-purpose, processing, role, and data-category mappings
[ST09]. ODRL supplies permission/prohibition/duty patterns [ST07]. Neither is the
JidoCode authorization engine, and neither proves legal compliance.

### Secret and personal data rules

- Secret values never enter RDF.
- Credentials are references with provider/key identifiers.
- Source/docs/messages/tool output may contain personal or confidential data and
  need classification before model egress.
- Stable account IDs are preferable to copied profile fields.
- Email and display names are optional classified data.
- Immutable provenance shells should be separable from erasable content bodies.
- Derived indexes/caches must not resurrect erased content.

## External ontology and schema reuse

### Direct foundations

| Vocabulary | Reuse |
| --- | --- |
| PROV-O | Direct provenance backbone [ST01] |
| OWL-Time | Intervals/instants and temporal relations [ST02] |
| ORG | Organizations, units, memberships, roles [ST03] |
| DCTerms | Generic title, creator, issued, modified, license, identifier, source [ST10] |
| SKOS | Controlled term schemes and weak mappings [ST14] |
| OWL 2 | Descriptive semantics and limited inference [ST15] |
| SHACL | Versioned graph admission profiles [ST16] |
| Web Annotation | Reviews, findings, comments, selectors [ST05-ST06] |
| FOAF | Selected `Person`, `Organization`, and account ideas only [ST04] |

Direct IRI reuse does not require runtime `owl:imports` of every upstream graph.

### Map or borrow

| Standard/model | Posture |
| --- | --- |
| ODRL, DPV, WAC | Map policy/privacy/access descriptions; authorization remains local [ST07-ST09] |
| DCAT, DQV, Profiles | Map catalogs, quality metrics, and conformance profiles [ST11-ST13] |
| P-PLAN | Borrow intended-plan/step patterns; execution stays PROV/Jido [ST19] |
| SOSA/SSN | Map runtime measurement procedures/results [ST20] |
| EARL | Map test assertions/results [ST21] |
| SPDX/CycloneDX | Native adapters and original-document retention [ST22-ST23] |
| CodeMeta/DOAP/schema.org | Public/project metadata mappings [ST24-ST26] |
| OSLC | Provider/change/configuration interoperability [ST28-ST30] |
| ActivityStreams | Optional user-facing activity feed, not audit provenance [ST31] |
| OpenTelemetry | Runtime observation adapter [ST32] |
| SLSA/in-toto/DSSE/Sigstore | Native assurance/attestation/signature adapters [ST33-ST36] |
| Git/Software Heritage | Exact object/archive mappings [ST37-ST38] |
| SCIP/Kythe/Glean | Code-index adapters; preserve producer schemes/versions [ST45-ST47] |
| SARIF/OSV/VEX/CSAF | Security/evidence adapters [ST48-ST51] |

### Patterns only or avoid

- KDM is a broad modernization metamodel, not a lightweight RDF source ontology
  [ST39].
- ASTM provides AST exchange patterns but is XMI-oriented and heavy [ST40].
- FAMIX provides strong source anchors and invocation/access patterns [ST41].
- CodeOntology is Java-focused research infrastructure [ST43].
- GraphGen4Code is a research graph/toolkit, not a stable canonical vocabulary
  [ST44].
- SEON demonstrates ontology modularity for software evolution [ST42].

Use these as reviewed design references only.

## OWL semantic profile

### Recommended regime

Target a documented OWL 2 RL-compatible core where practical, because JidoCode
already supports a bounded OWL 2 RL subset. Keep complex analysis semantics in
qualified resources and reviewed rules rather than deep class restrictions.

Rules:

- no accidental class/individual or object/datatype property punning;
- no use of object properties with literal objects;
- multiple domain/range axioms mean intersection, not union;
- no strong equivalence or `owl:sameAs` for approximate mappings;
- no global transitivity for overloaded dependency relations;
- no authority-producing property chains;
- no general cardinality axioms as an admission substitute;
- disjointness only where simultaneous membership is truly impossible;
- every reasoner profile and entailment timing is versioned.

### Classes versus concepts

Use OWL classes for semantic categories whose instances are resources, such as
`FunctionSymbol` and `CallSiteOccurrence`. Use SKOS concepts for controlled
values such as certainty, visibility, source layer, dependency scope, diagnostic
severity, and omission reason. Do not use one IRI as both class and concept.

### Open-world absence

The ontology never infers "missing callback," "dead code," or "no protocol
implementation" merely because an edge is absent. An absence conclusion requires:

- exact closed analysis manifest/profile;
- complete relevant extractor coverage;
- no unsupported units or macro/build omissions for the question;
- no truncation;
- a versioned closed-world query/rule;
- provenance and limitations on the resulting claim.

## SHACL and executable validation

### SHACL responsibilities

Shapes should validate:

- graph metadata, ontology release, family, owner scope, lifecycle, completeness,
  retention, and revisions;
- canonical Jido product IRI or approved external identifier syntax;
- snapshot/artifact/occurrence/span identity closure;
- allowed class and predicate namespace by graph family;
- object versus datatype property node kinds;
- required analysis activity/profile/configuration/input provenance;
- sequence membership item/sequence/index and uniqueness;
- source span coordinate and artifact digest coherence;
- certainty, semantic layer, visibility, dependency scope, and omission concepts;
- generated occurrence provenance;
- relation observation subject/kind/object/certainty/activity;
- temporal interval ordering;
- package coordinate and digest syntax;
- bounded literals and forbidden secret-bearing fields;
- coverage and failure reporting.

### Command guard responsibilities

Transactional code, not SHACL, should validate:

- authorization and delegation;
- exact graph and global revisions;
- idempotency and canonical content digest;
- cross-graph existence and family links;
- snapshot/tree/artifact digest verification;
- immutable segment closure and manifest expected set;
- current lease/fence for execution;
- claim/evidence/decision state;
- retention, content permit, and egress policy;
- query result and context consistency receipts.

### Portability

Publish the supported SHACL Core subset. Avoid custom JS/functions in the stable
contract. Treat SHACL-SPARQL constraints as separately versioned and fail closed
on unsupported execution, error, or timeout. Test the ontology and shapes with at
least two selected reasoners and SHACL engines [OE01-OE08].

### No blank application resources

Use deterministic IRIs for clauses, sequence memberships, patterns, spans,
observations, and shapes. JidoCode currently rejects blank nodes in ontology
packages and application writes. Deterministic resources improve identity,
provenance, diffing, and cross-segment references [JC06-JC07].

## Inference profiles

Inference must be bounded, versioned, replaceable, input-revision-pinned, and
explainable.

Safe candidate profiles include:

- class hierarchy and explicit subproperty inference;
- structural containment closure with depth bounds;
- lexical scope resolution under exact language/compiler profile;
- callback/protocol candidate matching;
- source dependency paths over source-specific relations;
- generated-to-authored correspondence from explicit provenance;
- cross-snapshot continuity suggestions;
- data/control/type flow from specialized analyzers;
- declared/deployed/observed topology comparisons.

Never infer:

- authorization from identity, ownership, membership, or source authorship;
- evidence acceptance from confidence or test pass;
- decision approval from a merged PR;
- memory adoption from repeated use;
- safe deletion from source reachability alone;
- complete runtime behavior from static or sampled observations.

Derived facts belong in replaceable `derived` graphs unless a separate governed
command explicitly admits them elsewhere.

## Example RDF design

The following is conceptual Turtle. Final namespaces and terms require an
accepted ontology release.

```turtle
@prefix src: <https://jido.run/ontology/source#> .
@prefix ex: <https://jido.run/ontology/elixir#> .
@prefix prov: <http://www.w3.org/ns/prov#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<https://jido.run/id/symbol/example-worker-run-1>
  a ex:FunctionSymbol ;
  ex:inModule <https://jido.run/id/symbol/example-worker> ;
  ex:callableName "run" ;
  ex:arity 1 .

<https://jido.run/id/occurrence/tree123-worker-run-1>
  a ex:CallableDefinitionOccurrence ;
  src:occurrenceOf <https://jido.run/id/symbol/example-worker-run-1> ;
  src:inArtifact <https://jido.run/id/artifact-occurrence/tree123-worker> ;
  src:hasSpan <https://jido.run/id/span/tree123-worker-100-220> ;
  prov:wasGeneratedBy <https://jido.run/id/activity/elixir-analysis-456> .

<https://jido.run/id/clause-membership/run-1-0>
  a src:SequenceMembership ;
  src:inSequence <https://jido.run/id/occurrence/tree123-worker-run-1> ;
  src:member <https://jido.run/id/occurrence/tree123-worker-run-1-clause-0> ;
  src:position 0 .
```

Qualified call resolution:

```turtle
<https://jido.run/id/observation/call-resolution-789>
  a src:RelationObservation ;
  src:relationSubject <https://jido.run/id/occurrence/call-site-321> ;
  src:relationKind src:PossibleCallTarget ;
  src:relationObject <https://jido.run/id/occurrence/target-function-654> ;
  src:certainty src:StaticMay ;
  src:analysisProfile <https://jido.run/id/profile/elixir-resolver-2> ;
  prov:wasGeneratedBy <https://jido.run/id/activity/resolution-456> .
```

No RDF-star dependency is required. A future RDF 1.2 projection can serialize
simple observations more compactly while preserving the qualified durable form
[ST17-ST18].

## Reviewed SPARQL competency queries

SPARQL is the backend query mechanism, not the model's unrestricted action
language. Each query must be fixed, typed, bounded, graph-scoped, authorized,
and versioned.

The graph placeholders below are typed query-catalog parameters resolved only
after graph authorization. A logical multi-segment analysis query must receive
an explicit revision-pinned graph allowlist from the executor; it never relies on
an implicit store default graph.

### Ordered clauses

```sparql
PREFIX src: <https://jido.run/ontology/source#>
PREFIX ex: <https://jido.run/ontology/elixir#>

SELECT ?position ?clause ?span
WHERE {
  VALUES ?sourceGraph { <SOURCE_GRAPH> }
  VALUES ?definitionOccurrence { <CALLABLE_DEFINITION_OCCURRENCE> }

  GRAPH ?sourceGraph {
    ?membership a src:SequenceMembership ;
                src:inSequence ?definitionOccurrence ;
                src:member ?clause ;
                src:position ?position .
    ?clause a ex:FunctionClauseOccurrence ;
            src:hasSpan ?span .
  }
}
ORDER BY ?position
LIMIT 100
```

### Call targets by certainty

```sparql
PREFIX src: <https://jido.run/ontology/source#>

SELECT ?target ?certainty ?activity
WHERE {
  VALUES ?sourceGraph { <SOURCE_GRAPH> }
  VALUES ?callSite { <CALL_SITE> }

  GRAPH ?sourceGraph {
    ?observation a src:RelationObservation ;
                 src:relationSubject ?callSite ;
                 src:relationKind src:PossibleCallTarget ;
                 src:relationObject ?target ;
                 src:certainty ?certainty ;
                 <http://www.w3.org/ns/prov#wasGeneratedBy> ?activity .
  }
}
LIMIT 50
```

### Generated definition provenance

```sparql
PREFIX src: <https://jido.run/ontology/source#>
PREFIX ex: <https://jido.run/ontology/elixir#>
PREFIX prov: <http://www.w3.org/ns/prov#>

SELECT ?generated ?invocation ?macro ?activity
WHERE {
  VALUES ?sourceGraph { <SOURCE_GRAPH> }
  VALUES ?generated { <GENERATED_OCCURRENCE> }

  GRAPH ?sourceGraph {
    ?generated a src:GeneratedOccurrence ;
               prov:wasGeneratedBy ?activity .
    ?activity a ex:MacroExpansionActivity ;
              ex:expandedInvocation ?invocation ;
              ex:usedMacroDefinition ?macro .
  }
}
LIMIT 20
```

### Behaviour obligations without false absence

The reviewed tool first proves manifest/profile completeness, then runs a bounded
query comparing declared callbacks with implementation observations. The SPARQL
must not use `FILTER NOT EXISTS` as proof unless the command/query preconditions
establish the exact closed scope.

## Agent tool surface enabled by the ontology

### Source and identity

- `resolve_source_occurrence`
- `inspect_source_span`
- `search_source_entities`
- `compare_symbol_occurrences`
- `explain_symbol_continuity`
- `inspect_generated_origin`

### Elixir semantics

- `inspect_function_clauses`
- `inspect_patterns_and_guards`
- `explain_lexical_resolution`
- `find_call_targets`
- `inspect_default_arities`
- `inspect_behaviour_contract`
- `inspect_protocol_dispatch`
- `inspect_struct_field_uses`
- `inspect_macro_expansion`
- `inspect_type_declarations`
- `inspect_type_analysis`

### Build and OTP

- `trace_beam_to_source`
- `explain_build_inputs`
- `inspect_dependency_resolution`
- `inspect_protocol_consolidation`
- `inspect_release_contents`
- `inspect_supervision_declaration`
- `inspect_message_handlers`
- `compare_declared_and_observed_topology`
- `inspect_loaded_code_versions`

### Quality, security, and work

- `select_related_tests`
- `inspect_test_evidence`
- `explain_diagnostic`
- `slice_dataflow`
- `assess_vulnerability_applicability`
- `trace_issue_to_change`
- `inspect_review_target`
- `find_stewards`
- `explain_ownership_source`

### Agent provenance and governance

- `compile_source_context`
- `explain_context_item`
- `inspect_context_omissions`
- `explain_patch_lineage`
- `check_context_eligibility`
- `explain_access_decision`
- `explain_retention_or_redaction`

Every result must carry exact source/graph/profile revisions, certainty,
provenance, coverage, freshness, truncation, limitations, and bounded explanation
paths.

## JidoCode graph-family placement

| Facts | Graph family |
| --- | --- |
| Ontology modules, shapes, mappings, concept schemes | Existing `ontology` |
| Repositories and current `Actor`/software `Agent` catalog entries | Existing `factory_catalog` |
| Person/account/organization profiles or reconciliations | Proposed catalog/observation placement, contingent on accepted privacy policy and ontology/shapes; current personal facts remain limited to governed `security_audit` |
| Grants, delegations, policy, adopted stewardship policy | Existing `factory_policy` |
| Provider/VCS/package/advisory observations admitted by the observation contract | Existing `observation_batch`; account/personal observations require the policy change above |
| Legacy compact `elixir-ast/1.0.0` source graphs | Existing `source_revision`, immutable legacy contract |
| New analysis identity, expected segments, coverage, closure | Proposed `source_analysis_manifest` |
| Authored/quoted/approved compiler-derived bounded source occurrences | Proposed `source_segment` |
| Static-may resolution, continuity, transitive dependency, data/type-flow outputs | Existing `derived` unless explicitly admitted source semantics |
| Attempt-scoped tool, build, test, coverage, and runtime execution provenance | Existing `run_attempt` where current attempt shapes admit it |
| External CI/provider build observations | Existing `observation_batch` where its admission contract applies |
| General OTP/runtime/deployment topology | Proposed placement requiring an accepted ontology, shape, authority, lifecycle, and retention contract |
| Governed verification checks, findings, test/security outcomes | Existing `evidence` |
| Goals, plans, tasks, edit obligations | Existing `repository_control` |
| Accepted reusable source knowledge | Existing `memory` |
| Authorization/privacy/retention/quarantine/content-access audit | Existing `security_audit` |

This preserves the sole embedded quad-store authority while separating semantic
domains. External ontology tools, graph databases, and indexes may be analyzers
or disposable projections, never parallel product authority [JC01-JC03].

## JidoCode ontology integration blockers

### Runtime vocabulary drift

JidoCode production code uses many `jf:` terms not declared in ontology release
`1.0.0`, including most current source predicates and several newer control,
evidence, learning, reasoning, and security terms. The new release must first
reconcile every emitted term with its actual current meaning, declare it, replace
it through a new term/migration, or reject its use. It must not claim the current
package is the complete runtime vocabulary [JC04-JC07].

### Namespace-aware validation

Current generic validation treats non-`jf:` classes as standard classes and
primarily recognizes project relationships in the existing factory namespace. A
new source or Elixir namespace could bypass family-specific class and relationship
checks. A vocabulary registry must record every class/property/concept, owning
module, object/datatype kind, graph-family allowlist, and shape profile before a
companion namespace can be admitted [JC06-JC07].

### Ontology loading and startup

JidoCode already has governed graph-migration commands and release migration
workflow scaffolding. The current release loader remains initial-install and
single-release oriented, recognizes only `1.0.0`, and rejects blank nodes. Once
an ontology graph exists, the wired startup gate requires current compatible
versions; a substrate-only dataset is the explicit startup exception. Existing
migration machinery must be extended for multi-release loading, activation, and
retained-version compatibility. A future release needs:

- module/namespace manifest and digests;
- governed post-install activation/migration;
- compatibility-aware startup for retained prior-release graphs;
- immutable old source graphs and validated target graphs;
- versioned shape catalog and query/projection compatibility;
- rollback and recovery semantics [JC04-JC07].

### Source topology and capacity

The current single closed source graph has a 400 analyzer-statement publication
bound, ordinary 1,000-addition command bound, and 10,000-quad/20-graph semantic
snapshot bounds. The proposed ontology requires bounded immutable segments,
closeable manifest/recovery semantics, logical analysis snapshots, paged reviewed
queries, and context receipts. Raising one constant is not a complete design
[JC05-JC08].

### Identity collisions

The current reference identity can collapse repeated references to the same name
across artifacts. The proper ontology requires occurrence-specific reference,
invocation, clause, pattern, membership, and span identities. Existing legacy
`calls`, `dependsOn`, `CodeSymbol`, and concept-valued `Module`/`Function` meanings
must not be silently reinterpreted [JC05-JC08].

## Corrections required in `elixir-ontologies`

The external project can become an extractor/reference implementation only after
semantic corrections.

### Critical correctness

1. Replace shared blank-node labels with deterministic occurrence-scoped IRIs.
2. Group and order clauses in every profile.
3. Make parser, extractor, builder, module, SHACL, SPARQL, timeout, and task
   failures fail closed with structured omissions, while preserving the stricter
   contextual analysis contract rather than generalizing legacy behavior.
4. Remove avoidable input-derived atom creation. Parse genuinely untrusted Elixir
   source in a bounded short-lived OS/BEAM process or reject it as unsupported,
   because the parser itself can intern identifiers.
5. Extend existing contextual full-mode limits and enforce bounds across every
   entry point: source bytes before parsing, downloads, archive expansion, file
   counts/sizes, AST depth, terms, triples, time, and memory.
6. Stop writing literal objects through OWL object properties.

### Language semantics

7. Implement scope-aware nested-module traversal and ownership.
8. Handle top-level `defprotocol` and `defimpl` as roots.
9. Distinguish call-site occurrences from function symbols and perform explicit
   resolution rather than constructing declaration-looking target IRIs.
10. Preserve containing module, callable definition, clause, and source span
    during call extraction; remove the synthetic `module/0` caller, align context
    keys, and do not apply Function-domain properties to call-site occurrences.
11. Complete or narrow claims for specs, attributes, standalone macro resources,
    ETS, exception payloads, GenServer callbacks, supervisor strategies/children,
    applications, source/Git provenance, and evolution builders.
12. Separate OTP source implementation classes from runtime process classes.
13. Use one canonical IRI service for every resource kind.
14. Emit complete source file/location resources and exact snapshot provenance.

### Ontology and validation

15. Remove duplicate/conflicting property declarations and unintended
    intersection domains/ranges. Remove or map undeclared `core:Module` and
    `core:Function` targets to canonical structure classes, and test for
    disconnected public terms.
16. Align OWL restrictions and SHACL acceptance semantics.
17. Make SHACL target/class checks entailment-aware or emit required base types.
18. Declare the exact supported SHACL subset and test in standard engines.
19. Resolve the package version `0.1.0` versus ontology/shapes version `1.0.0`,
    hosted namespace, import, format, CI, guide, and licensing inconsistencies.

Even after those fixes, JidoCode should transform selected output into local
snapshot-scoped identities and validate it through local governed commands. The
upstream store and arbitrary SPARQL path remain outside JidoCode authority.

## Ontology engineering and release governance

### Three release artifacts

Treat the contract as:

1. **OWL ontology** for descriptive, monotonic, open-world semantics.
2. **SHACL shapes and semantic command guards** for concrete admission.
3. **Executable fixtures** for entailments, validation, query answers, imports,
   identity, and portability.

### IRI policy

- stable ontology IRI;
- immutable dereferenceable version IRI per release;
- versionless public term IRIs;
- deterministic product instance IRIs under Jido ResourceIdentity;
- no reassignment of released term meaning;
- `owl:deprecated true` plus retained definition and migration guidance;
- no public blank-node terms;
- HTTP persistence, content negotiation, redirects, and tombstones;
- offline vendored release with exact digests.

### Compatibility

Classify separately:

- IRI compatibility;
- OWL consistency and expected entailments;
- SHACL acceptance;
- query result compatibility;
- identity output;
- graph-family admission;
- reasoning profile output;
- migration requirements.

A syntactically additive axiom can be breaking if it creates inconsistency,
changes inferred types, rejects old fixtures, alters query answers, or changes
symbol identity. Use ontology-specific semantic versioning rather than assuming
all term additions are minor [OE01-OE06, OE36].

### Release metadata

Publish:

- `owl:versionIRI`, `owl:priorVersion`, release date, creators, contributors,
  license, source repository, commit, and changelog;
- supported Elixir/OTP/Mix/framework versions;
- imports/IRI reuse manifest and checksums;
- OWL profile and entailment regime;
- SHACL subset/engines;
- reasoning profiles;
- competency questions and query versions;
- positive, negative, edge, incomplete, inference, and inconsistency fixtures;
- mappings, migration, rollback, and support policy;
- human-readable generated docs and diagrams [OE16-OE19, OE32-OE35].

### Quality gates

- parse every serialization and compare canonical datasets;
- validate OWL 2 DL/profile conformance;
- test expected consistency and entailments in selected reasoners;
- run SHACL fixtures in selected engines;
- run every competency query with expected result sets;
- detect undeclared/disconnected terms;
- detect duplicate labels, accidental punning, object/datatype misuse, unintended
  multiple-domain intersections, equivalence/sameAs risk, and broken imports;
- run OOPS or equivalent with reviewed suppressions [OE34];
- verify every IRI/version IRI dereferences;
- verify license/attribution and no runtime network imports;
- compare analyzer-produced RDF to ontology/shapes, not merely hand fixtures;
- fail release on skipped validation or engine timeout.

### Change governance

Every ontology change proposal should state:

- competency questions added/changed;
- terms/axioms/shapes/queries affected;
- semantic and graph-family authority impact;
- supported language/tool versions;
- privacy/security implications;
- identity and migration impact;
- fixtures and acceptance evidence;
- compatibility classification;
- rollback posture.

Require language-domain, ontology-engineering, Jido architecture/security, and
extractor/tooling review for stable modules.

## Phased roadmap

### Phase 0: accepted contracts

Decide through ADR/architecture changes:

- module and namespace ownership;
- conceptual symbol and occurrence identities;
- semantic layers and certainty vocabulary;
- qualified relation pattern;
- source span coordinate convention;
- source manifest/segment topology and recovery;
- ontology activation/compatibility/migration;
- source-content and personal-data policy;
- external vocabulary import/mapping policy;
- graph-family placement and retention;
- reviewed query/tool authorization.

### Phase 1: vocabulary reconciliation

- inventory every emitted Jido term;
- reconcile ontology/code drift;
- preserve legacy term meanings;
- define the Source Core, provenance alignment, certainty, and shapes;
- implement namespace-aware term/family registry;
- create executable source identity/span/observation fixtures.

### Phase 2: corrected structural Elixir profile

- build a safe syntax-only parser/adapter;
- support flat/nested modules correctly;
- support functions/macros, defaults, clauses, parameters, patterns, guards,
  directives, attributes, behaviours, protocols, structs, typespec declarations,
  and source spans;
- emit no runtime-process claims;
- record unsupported/generated omissions;
- benchmark against hand-reviewed Elixir fixtures.

### Phase 3: segmented publication and reviewed tools

- implement manifest and immutable segment families/commands;
- implement startup/recovery and logical analysis snapshots;
- add product-authorized reviewed queries;
- add the minimal source/context tool surface;
- bind selected source items into existing execution contexts;
- evaluate localization, context size, impact accuracy, and staleness safety.

### Phase 4: compiler, Mix, BEAM, and type profiles

- governed macro/compiler sandbox;
- expansion provenance and generated definitions;
- Mix/project/dependency/lock/build modeling;
- BEAM chunks and source correspondence;
- protocol consolidation;
- traditional typespec, Dialyzer, and gradual type-analysis modules;
- release and artifact lineage.

### Phase 5: OTP runtime and framework overlays

- OTP declaration profile;
- runtime observation adapters with valid time;
- Phoenix/LiveView/Ecto/Telemetry overlays;
- Erlang/native/cross-language bridges;
- declared/deployed/observed topology comparison.

### Phase 6: collaboration, supply chain, and governance

- provider actor/account/org and stewardship reconciliation;
- issues/PR/review annotations;
- SPDX/CycloneDX/SARIF/SLSA/in-toto/OSV/VEX adapters;
- privacy, retention, erasure, content egress, and agent retrieval provenance;
- cross-domain competency tools.

## Evaluation plan

### Ontology metrics

- competency-question coverage;
- public terms justified by questions/interop requirements;
- OWL profile and consistency failures;
- SHACL portability and false accept/reject rates;
- undeclared/disconnected/ambiguous term count;
- import and IRI availability;
- compatibility fixture regressions;
- mapping loss by external format;
- ontology/query/reasoner latency and memory.

### Extractor metrics

- precision/recall for declarations, clauses, spans, bindings, directives,
  behaviours, protocols, type declarations, and OTP declarations;
- nested module and generated code accuracy;
- reference/call target precision/recall by certainty class;
- deterministic graph digest;
- coverage/omission accuracy;
- fail-closed behavior under parser/builder/validator failure;
- no atom/resource exhaustion or source/secret/path leakage;
- triples/bytes/time per profile and repository.

### Agent outcome metrics

- file/function/span localization;
- complete accepted-patch edit-site recall;
- context precision, tokens, and explanation-path validity;
- change-impact precision/recall;
- behaviour/protocol/migration completeness;
- patch compile/test/issue-resolution rate;
- unnecessary edits and regressions;
- stale-graph rejection;
- authorization/cross-scope leakage;
- human review time and trust calibration;
- tool calls, latency, cost, and repeated-run variance.

### Negative and adversarial fixtures

Include:

- nested modules and top-level protocols;
- function/macro same name/arity;
- multi-clause/default/guard ordering;
- alias/import/require/use scopes;
- generated functions and failed macro expansion;
- dynamic `apply`, protocol consolidation drift, hot code loading;
- stripped/encrypted/missing BEAM chunks;
- incomplete builds and dependencies;
- malicious source labels/docs;
- duplicate people/account names and conflicting ownership;
- expired/revoked grants;
- high-degree graph hubs and path-query denial of service;
- erased/redacted content and stale disposable indexes.

## Final recommendation

Build a new modular ontology release; do not extend the current external ontology
or JidoCode `1.0.0` in place.

The proper ontology should make these distinctions non-negotiable:

1. symbol versus occurrence;
2. authored versus quoted versus expanded versus built versus loaded versus
   observed;
3. function versus macro versus special form;
4. callable versus ordered clause;
5. syntactic invocation versus candidate/resolved/observed target;
6. behaviour contract versus protocol dispatch;
7. source OTP implementation versus runtime process instance;
8. typespec versus Dialyzer versus gradual compiler type;
9. source dependency versus build/package/application/runtime dependency;
10. person versus account versus principal versus software agent instance;
11. authorship/stewardship versus authorization;
12. provenance versus correctness;
13. evidence versus acceptance;
14. ontology module versus graph family;
15. external interchange format versus local authority.

For coding agents, this design enables precise and explainable tools without
pretending static analysis is runtime truth or turning source relationships into
authority. It gives each answer an exact snapshot, source span, semantic layer,
producer, profile, certainty, coverage, time, and graph revision. That is the
difference between a large graph of code-shaped triples and a trustworthy source
knowledge system.

## Sources

### Elixir language, Mix, and ecosystem

- **EL01.** Elixir, [Syntax reference](https://hexdocs.pm/elixir/1.20.3/syntax-reference.html), 1.20.3.
- **EL02.** Elixir, [Patterns and guards](https://hexdocs.pm/elixir/1.20.3/patterns-and-guards.html), 1.20.3.
- **EL03.** Elixir, [Modules and functions](https://hexdocs.pm/elixir/1.20.3/modules-and-functions.html), 1.20.3.
- **EL04.** Elixir, [Alias, require, and import](https://hexdocs.pm/elixir/1.20.3/alias-require-and-import.html), 1.20.3.
- **EL05.** Elixir, [Module attributes](https://hexdocs.pm/elixir/1.20.3/module-attributes.html), 1.20.3.
- **EL06.** Elixir, [Typespecs and behaviours](https://hexdocs.pm/elixir/1.20.3/typespecs.html), 1.20.3.
- **EL07.** Elixir, [Protocols guide](https://hexdocs.pm/elixir/1.20.3/protocols.html), 1.20.3.
- **EL08.** Elixir, [Structs](https://hexdocs.pm/elixir/1.20.3/structs.html), 1.20.3.
- **EL09.** Elixir, [Quote and unquote](https://hexdocs.pm/elixir/1.20.3/quote-and-unquote.html), 1.20.3.
- **EL10.** Elixir, [Macros](https://hexdocs.pm/elixir/1.20.3/macros.html), 1.20.3.
- **EL11.** Elixir, [`Macro`](https://hexdocs.pm/elixir/1.20.3/Macro.html), 1.20.3.
- **EL12.** Elixir, [`Macro.Env`](https://hexdocs.pm/elixir/1.20.3/Macro.Env.html), 1.20.3.
- **EL13.** Elixir, [`Module`](https://hexdocs.pm/elixir/1.20.3/Module.html), 1.20.3.
- **EL14.** Elixir, [`Code`](https://hexdocs.pm/elixir/1.20.3/Code.html), 1.20.3.
- **EL15.** Elixir, [Gradual set-theoretic types](https://hexdocs.pm/elixir/1.20.3/gradual-set-theoretic-types.html), 1.20.3.
- **EL16.** Elixir, [`GenServer`](https://hexdocs.pm/elixir/1.20.3/GenServer.html), 1.20.3.
- **EL17.** Elixir, [`Registry`](https://hexdocs.pm/elixir/1.20.3/Registry.html), 1.20.3.
- **EL18.** Elixir, [`Port`](https://hexdocs.pm/elixir/1.20.3/Port.html), 1.20.3.
- **EL19.** Elixir, [`Protocol`](https://hexdocs.pm/elixir/1.20.3/Protocol.html), 1.20.3.
- **EL20.** Elixir, [Elixir v1.17 released](https://elixir-lang.org/blog/2024/06/12/elixir-v1-17-0-released/), 2024.
- **EL21.** Elixir, [Elixir v1.18 released](https://elixir-lang.org/blog/2024/12/19/elixir-v1-18-0-released/), 2024.
- **EL22.** Elixir, [Elixir v1.19 released](https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/), 2025.
- **EL23.** Elixir, [Elixir v1.20 released](https://elixir-lang.org/blog/2026/06/03/elixir-v1-20-0-released/), 2026.
- **EL24.** Mix, [`Mix.Project`](https://hexdocs.pm/mix/1.20.3/Mix.Project.html), 1.20.3.
- **EL25.** Mix, [`mix deps`](https://hexdocs.pm/mix/1.20.3/Mix.Tasks.Deps.html), 1.20.3.
- **EL26.** Mix, [`mix compile`](https://hexdocs.pm/mix/1.20.3/Mix.Tasks.Compile.html) and [`Mix.Task.Compiler`](https://hexdocs.pm/mix/1.20.3/Mix.Task.Compiler.html), 1.20.3.
- **EL27.** Mix, [`mix release`](https://hexdocs.pm/mix/1.20.3/Mix.Tasks.Release.html), 1.20.3.
- **EL28.** Hex, [Usage and lock semantics](https://hex.pm/docs/usage), accessed 2026-08-15.
- **EL29.** ExUnit, [`ExUnit.Case`](https://hexdocs.pm/ex_unit/1.20.3/ExUnit.Case.html), 1.20.3.
- **EL30.** ExUnit, [`ExUnit.DocTest`](https://hexdocs.pm/ex_unit/1.20.3/ExUnit.DocTest.html), 1.20.3.

### Erlang/OTP, BEAM, and analysis

- **OTP01.** Erlang/OTP, [Functions](https://www.erlang.org/doc/system/ref_man_functions.html), OTP 29.
- **OTP02.** Erlang/OTP, [Processes and signals](https://www.erlang.org/doc/system/ref_man_processes.html), OTP 29.
- **OTP03.** Erlang/OTP, [Applications](https://www.erlang.org/doc/system/applications.html), OTP 29.
- **OTP04.** Erlang/OTP, [Supervisor behaviour](https://www.erlang.org/doc/system/sup_princ.html), OTP 29.
- **OTP05.** Erlang/OTP, [Code loading](https://www.erlang.org/doc/system/code_loading.html), OTP 29.
- **OTP06.** Erlang/OTP, [`beam_lib`](https://www.erlang.org/doc/apps/stdlib/beam_lib.html), OTP 29.
- **OTP07.** Erlang/OTP, [Abstract format](https://www.erlang.org/doc/apps/erts/absform.html), OTP 29.
- **OTP08.** Erlang/OTP, [Compiler](https://www.erlang.org/doc/apps/compiler/compile.html), OTP 29.
- **OTP09.** Erlang/OTP, [`ets`](https://www.erlang.org/doc/apps/stdlib/ets.html), OTP 29.
- **OTP10.** Erlang/OTP, [Distributed Erlang](https://www.erlang.org/doc/system/distributed.html), OTP 29.
- **OTP11.** EEP 48, [Documentation storage](https://www.erlang.org/eeps/eep-0048.html).
- **OTP12.** Erlang/OTP, [Dialyzer analysis model](https://www.erlang.org/doc/apps/dialyzer/dialyzer_chapter.html), OTP 29.
- **OTP13.** Erlang/OTP, [NIF API](https://www.erlang.org/doc/apps/erts/erl_nif.html), OTP 29.
- **OTP14.** Erlang/OTP, [Linked-in driver API](https://www.erlang.org/doc/apps/erts/erl_driver.html), OTP 29.
- **OTP15.** Erlang/OTP, [Release structure](https://www.erlang.org/doc/system/release_structure.html), OTP 29.
- **OTP16.** Erlang/OTP, [Types and function specifications](https://www.erlang.org/doc/reference_manual/typespec.html), OTP 29.
- **OTP17.** Erlang/OTP, [Nominal types](https://www.erlang.org/doc/system/nominals.html), OTP 29.
- **OTP18.** Erlang/OTP, [Opaque types](https://www.erlang.org/doc/system/opaques.html), OTP 29.
- **OTP19.** Erlang/OTP, [External term format: `NEW_PID_EXT`](https://www.erlang.org/doc/apps/erts/erl_ext_dist.html#new_pid_ext), OTP 29.

### Ecosystem overlays

- **ECO01.** Telemetry, [`:telemetry`](https://hexdocs.pm/telemetry/1.4.2/telemetry.html), 1.4.2.
- **ECO02.** Phoenix, [`Phoenix.Endpoint`](https://hexdocs.pm/phoenix/1.8.11/Phoenix.Endpoint.html), 1.8.11.
- **ECO03.** Phoenix, [`Phoenix.Router`](https://hexdocs.pm/phoenix/1.8.11/Phoenix.Router.html), 1.8.11.
- **ECO04.** Phoenix LiveView, [`Phoenix.LiveView`](https://hexdocs.pm/phoenix_live_view/1.2.9/Phoenix.LiveView.html), 1.2.9.
- **ECO05.** Ecto, [`Ecto.Repo`](https://hexdocs.pm/ecto/3.14.2/Ecto.Repo.html), 3.14.2.
- **ECO06.** Ecto, [`Ecto.Schema`](https://hexdocs.pm/ecto/3.14.2/Ecto.Schema.html), 3.14.2.
- **ECO07.** Ecto, [`Ecto.Changeset`](https://hexdocs.pm/ecto/3.14.2/Ecto.Changeset.html), 3.14.2.
- **ECO08.** Ecto, [`Ecto.Query`](https://hexdocs.pm/ecto/3.14.2/Ecto.Query.html), 3.14.2.
- **ECO09.** Ecto, [`Ecto.Multi`](https://hexdocs.pm/ecto/3.14.2/Ecto.Multi.html), 3.14.2.

### `elixir-ontologies` implementation and schema

- **EO01.** pcharbon70, [`elixir-ontologies`](https://github.com/pcharbon70/elixir-ontologies/tree/fb2432ae666062b8d0d601f742abbadda0583b02), [`mix.exs`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/mix.exs), and [MIT license](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/LICENSE), inspected commit `fb2432ae666062b8d0d601f742abbadda0583b02`.
- **EO02.** Elixir Ontologies, [Core ontology](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/priv/ontologies/elixir-core.ttl).
- **EO03.** Elixir Ontologies, [Structure ontology](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/priv/ontologies/elixir-structure.ttl).
- **EO04.** Elixir Ontologies, [OTP ontology](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/priv/ontologies/elixir-otp.ttl).
- **EO05.** Elixir Ontologies, [Evolution ontology](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/priv/ontologies/elixir-evolution.ttl).
- **EO06.** Elixir Ontologies, [SHACL shapes](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/priv/ontologies/elixir-shapes.ttl).
- **EO07.** Elixir Ontologies, [`FileAnalyzer`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/analyzer/file_analyzer.ex) and [`Pipeline`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/pipeline.ex).
- **EO08.** Elixir Ontologies, [`ClauseBuilder`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/clause_builder.ex), [`CallGraphBuilder`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/call_graph_builder.ex), and [`Orchestrator`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/orchestrator.ex).
- **EO09.** Elixir Ontologies, [SHACL validator](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/shacl/validator.ex) and [SPARQL constraint validator](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/shacl/validators/sparql.ex).
- **EO10.** Elixir Ontologies, [parser](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/analyzer/parser.ex), [project analyzer](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/analyzer/project_analyzer.ex), [configuration](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/config.ex), and [graph serialization](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/graph.ex).
- **EO11.** Elixir Ontologies, [builder helpers](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/helpers.ex), [control-flow builder](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/control_flow_builder.ex), [exception builder](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/exception_builder.ex), and [OTP builders](https://github.com/pcharbon70/elixir-ontologies/tree/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/otp).

### Standards and reusable models

- **ST01.** W3C, [PROV-O](https://www.w3.org/TR/prov-o/), Recommendation, 2013.
- **ST02.** W3C, [OWL-Time](https://www.w3.org/TR/2017/REC-owl-time-20171019/), Recommendation, 2017.
- **ST03.** W3C, [Organization Ontology](https://www.w3.org/TR/vocab-org/), Recommendation, 2014.
- **ST04.** FOAF, [FOAF Vocabulary Specification 0.99](http://xmlns.com/foaf/spec/), community vocabulary, 2014.
- **ST05.** W3C, [Web Annotation Data Model](https://www.w3.org/TR/annotation-model/), Recommendation, 2017.
- **ST06.** W3C, [Web Annotation Vocabulary](https://www.w3.org/TR/annotation-vocab/), Recommendation, 2017.
- **ST07.** W3C, [ODRL 2.2 Information Model](https://www.w3.org/TR/odrl-model/), Recommendation, 2018.
- **ST08.** Solid, [Web Access Control](https://solidproject.org/TR/wac), technical report.
- **ST09.** W3C Data Privacy Vocabularies and Controls CG, [DPV 2.3](https://w3id.org/dpv/2.3), Final Community Group Report, 2026.
- **ST10.** DCMI, [Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/).
- **ST11.** W3C, [DCAT 3](https://www.w3.org/TR/vocab-dcat-3/), Recommendation, 2024.
- **ST12.** W3C, [Data Quality Vocabulary](https://www.w3.org/TR/vocab-dqv/), Working Group Note, 2016.
- **ST13.** W3C, [Profiles Vocabulary](https://www.w3.org/TR/dx-prof/), Working Group Note, 2019.
- **ST14.** W3C, [SKOS Reference](https://www.w3.org/TR/skos-reference/), Recommendation, 2009.
- **ST15.** W3C, [OWL 2 Overview](https://www.w3.org/TR/owl2-overview/), Recommendation, 2012.
- **ST16.** W3C, [SHACL](https://www.w3.org/TR/shacl/), Recommendation, 2017.
- **ST17.** W3C, [RDF 1.2 Concepts](https://www.w3.org/TR/2026/CR-rdf12-concepts-20260407/), Candidate Recommendation Snapshot, 2026.
- **ST18.** W3C RDF-star CG, [RDF-star report](https://www.w3.org/2021/12/rdf-star.html), Community Group Report, 2021.
- **ST19.** P-PLAN, [P-PLAN 1.3](https://vocab.linkeddata.es/p-plan/), community ontology, 2014.
- **ST20.** W3C, [SSN/SOSA](https://www.w3.org/TR/vocab-ssn/), Recommendation, 2017.
- **ST21.** W3C, [EARL 1.0 Schema](https://www.w3.org/TR/EARL10-Schema/), Working Group Note, 2017.
- **ST22.** SPDX, [SPDX 3.0.1](https://spdx.github.io/spdx-spec/v3.0.1/).
- **ST23.** OWASP CycloneDX, [CycloneDX 1.7](https://github.com/CycloneDX/specification/tree/1.7), standardized as [ECMA-424, second edition](https://ecma-international.org/publications-and-standards/standards/ecma-424/), 2025.
- **ST24.** CodeMeta, [CodeMeta project and crosswalk](https://codemeta.github.io/).
- **ST25.** DOAP, [Description of a Project](https://github.com/ewilderj/doap).
- **ST26.** Schema.org, [`SoftwareSourceCode`](https://schema.org/SoftwareSourceCode).
- **ST27.** Package URL, [purl specification](https://github.com/package-url/purl-spec).
- **ST28.** OASIS, [OSLC Core 3.0](https://docs.oasis-open-projects.org/oslc-op/core/v3.0/os/oslc-core.html).
- **ST29.** OASIS, [OSLC Change Management 3.0](https://docs.oasis-open-projects.org/oslc-op/cm/v3.0/errata01/os/change-mgt-spec.html).
- **ST30.** OASIS, [OSLC Configuration Management 1.0](https://docs.oasis-open-projects.org/oslc-op/config/v1.0/os/oslc-config-mgt.html).
- **ST31.** W3C, [ActivityStreams 2.0](https://www.w3.org/TR/activitystreams-core/), Recommendation, 2017.
- **ST32.** CNCF, [OpenTelemetry Specification 1.60.0](https://github.com/open-telemetry/opentelemetry-specification/tree/v1.60.0), 2026; document maturity varies by section.
- **ST33.** SLSA, [SLSA 1.2](https://slsa.dev/spec/v1.2/).
- **ST34.** in-toto, [Attestation Framework 1.2.0](https://github.com/in-toto/attestation/tree/v1.2.0), 2026.
- **ST35.** Secure Systems Lab, [DSSE Protocol 1.0.2](https://github.com/secure-systems-lab/dsse/blob/1d14ad6f941e31670a9ee42d64afd8ce1572bc37/protocol.md), inspected commit `1d14ad6f941e31670a9ee42d64afd8ce1572bc37`.
- **ST36.** Sigstore, [Overview](https://docs.sigstore.dev/about/overview/).
- **ST37.** Git, [Git object model](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects).
- **ST38.** Software Heritage, [data model](https://gitlab.softwareheritage.org/swh/devel/swh-model/-/blob/f348a4bb6a49b0f8dd816fca9086140937402778/docs/data-model.rst) and [persistent identifiers](https://gitlab.softwareheritage.org/swh/devel/swh-model/-/blob/f348a4bb6a49b0f8dd816fca9086140937402778/docs/persistent-identifiers.rst), inspected `swh-model` commit `f348a4bb6a49b0f8dd816fca9086140937402778`.
- **ST39.** OMG, [Knowledge Discovery Metamodel 1.4](https://www.omg.org/spec/KDM/1.4/About-KDM).
- **ST40.** OMG, [Abstract Syntax Tree Metamodel 1.0](https://www.omg.org/spec/ASTM/1.0/About-ASTM).
- **ST41.** Moose Technology, [FAMIX](https://github.com/moosetechnology/Famix/tree/8d5e1d37ba48c174fd27a5978707ea4cebcd1ad3), inspected commit `8d5e1d37ba48c174fd27a5978707ea4cebcd1ad3`.
- **ST42.** Wuersch et al., [SEON: a pyramid of ontologies for software evolution and its applications](https://doi.org/10.1007/s00607-012-0204-1), Computing, 2012.
- **ST43.** Atzeni and Atzori, [CodeOntology: RDF-ization of Source Code](https://doi.org/10.1007/978-3-319-68204-4_2), ISWC, 2017.
- **ST44.** IBM/WALA, [GraphGen4Code](https://github.com/wala/graph4code/tree/855471a19f55f0a9101d175baff80980b16ab236), inspected commit `855471a19f55f0a9101d175baff80980b16ab236`.
- **ST45.** SCIP, [Code Intelligence Protocol](https://scip-code.org/).
- **ST46.** Kythe, [Overview](https://kythe.io/docs/kythe-overview.html).
- **ST47.** Glean, [Introduction](https://glean.software/docs/introduction/).
- **ST48.** OASIS, [SARIF 2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/sarif-v2.1.0-os.html), OASIS Standard, 2020.
- **ST49.** OpenSSF, [OSV schema 1.9.0](https://github.com/ossf/osv-schema/blob/f3f826310aeca8e324baabd195632f2229952abe/docs/schema.md), 2026.
- **ST50.** OpenVEX, [Specification 0.2.0](https://github.com/openvex/spec/tree/v0.2.0), 2023.
- **ST51.** OASIS, [CSAF 2.0](https://docs.oasis-open.org/csaf/csaf/v2.0/os/csaf-v2.0-os.html), OASIS Standard, 2022.

### Ontology engineering and quality

- **OE01.** W3C, [OWL 2 Structural Specification](https://www.w3.org/TR/owl2-syntax/), Recommendation, 2012.
- **OE02.** W3C, [OWL 2 Direct Semantics](https://www.w3.org/TR/owl2-direct-semantics/), Recommendation, 2012.
- **OE03.** W3C, [OWL 2 Profiles](https://www.w3.org/TR/owl2-profiles/), Recommendation, 2012.
- **OE04.** W3C, [OWL 2 Conformance](https://www.w3.org/TR/owl2-conformance/), Recommendation, 2012.
- **OE05.** W3C, [OWL 2 Primer](https://www.w3.org/TR/owl2-primer/), 2012.
- **OE06.** W3C, [OWL 2 New Features and Rationale](https://www.w3.org/TR/owl2-new-features/), 2012.
- **OE07.** W3C, [SHACL](https://www.w3.org/TR/shacl/), Recommendation, 2017.
- **OE08.** W3C, [SHACL Advanced Features](https://www.w3.org/TR/shacl-af/), Working Group Note, 2017.
- **OE09.** W3C, [RDF 1.1 Concepts](https://www.w3.org/TR/rdf11-concepts/), Recommendation, 2014.
- **OE10.** W3C, [RDF 1.1 Semantics](https://www.w3.org/TR/rdf11-mt/), Recommendation, 2014.
- **OE11.** W3C, [RDF Schema 1.1](https://www.w3.org/TR/rdf-schema/), Recommendation, 2014.
- **OE12.** W3C, [RDF 1.1 Test Cases](https://www.w3.org/TR/2014/NOTE-rdf11-testcases-20140225/), Working Group Note, 2014.
- **OE13.** W3C, [SPARQL 1.1 Query](https://www.w3.org/TR/sparql11-query/), Recommendation, 2013.
- **OE14.** W3C, [PROV-O](https://www.w3.org/TR/prov-o/), Recommendation, 2013.
- **OE15.** W3C, [SKOS Reference](https://www.w3.org/TR/skos-reference/), Recommendation, 2009.
- **OE16.** W3C, [Data on the Web Best Practices](https://www.w3.org/TR/dwbp/), Recommendation, 2017.
- **OE17.** W3C, [Architecture of the World Wide Web: URI persistence](https://www.w3.org/TR/webarch/#URI-persistence), Recommendation, 2004.
- **OE18.** W3C, [Cool URIs for the Semantic Web](https://www.w3.org/TR/cooluris/), Interest Group Note, 2008.
- **OE19.** W3C, [Best Practice Recipes for Publishing RDF Vocabularies](https://www.w3.org/TR/swbp-vocab-pub/), Working Group Note, 2008.
- **OE20.** W3C, [Defining N-ary Relations on the Semantic Web](https://www.w3.org/TR/swbp-n-aryRelations/), Working Group Note, 2006.
- **OE21.** W3C, [OWL Use Cases and Requirements](https://www.w3.org/TR/webont-req/), Recommendation, 2004.
- **OE22.** Noy and McGuinness, [Ontology Development 101](https://protege.stanford.edu/publications/ontology_development/ontology101.pdf), Stanford technical report, 2001.
- **OE23.** Gangemi and Presutti, [Content Ontology Design Patterns as Practical Building Blocks](https://doi.org/10.1007/978-3-540-87877-3_11), 2008.
- **OE24.** Guarino and Welty, [Evaluating Ontological Decisions with OntoClean](https://doi.org/10.1145/503124.503150), 2002.
- **OE25.** OBO Foundry, [Principles](https://obofoundry.org/principles/fp-000-summary.html).
- **OE26.** OBO Foundry, [Versioning principle](https://obofoundry.org/principles/fp-004-versioning.html).
- **OE27.** Smith et al., [The OBO Foundry](https://doi.org/10.1038/nbt1346), Nature Biotechnology, 2007.
- **OE28.** Courtot et al., [MIREOT](https://doi.org/10.3233/AO-2011-0087), Applied Ontology, 2011.
- **OE29.** Vandenbussche et al., [Linked Open Vocabularies](https://doi.org/10.3233/SW-160213), Semantic Web, 2016.
- **OE30.** Wilkinson et al., [FAIR Guiding Principles](https://doi.org/10.1038/sdata.2016.18), Scientific Data, 2016.
- **OE31.** Cox et al., [Ten Simple Rules for Making a Vocabulary FAIR](https://doi.org/10.1371/journal.pcbi.1009041), PLOS Computational Biology, 2021.
- **OE32.** Ciccarese et al., [PAV ontology](https://doi.org/10.1186/2041-1480-4-37), Journal of Biomedical Semantics, 2013.
- **OE33.** Garijo, [WIDOCO](https://doi.org/10.1007/978-3-319-68204-4_9), ISWC, 2017.
- **OE34.** Poveda-Villalon et al., [OOPS! Ontology Pitfall Scanner](https://doi.org/10.4018/ijswis.2014040102), 2014.
- **OE35.** DCMI, [Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/).
- **OE36.** [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).
- **OE37.** ISO, [ISO/IEC 21838-1:2021, Top-level ontologies requirements](https://www.iso.org/standard/71954.html).

### JidoCode local architecture sources

- **JC01.** `docs/adr/0001-graph-only-source-of-truth.md`
- **JC02.** `docs/adr/0002-triple-store-backend-contract.md`
- **JC03.** `docs/architecture/module-boundaries.md`
- **JC04.** `docs/architecture/factory-ontology.md`
- **JC05.** `docs/architecture/source-analysis.md`
- **JC06.** `docs/architecture/graph-identity-and-topology.md`
- **JC07.** `docs/architecture/semantic-validation-and-evolution.md`
- **JC08.** `docs/architecture/reviewed-query-catalog.md`
- **JC09.** `docs/architecture/authority-bootstrap-and-audit.md`
- **JC10.** `docs/architecture/product-security-privacy-and-threat-model.md`
- **JC11.** `lib/jido_code/knowledge/authorization.ex`
- **JC12.** `docs/architecture/verification-evidence-boundary.md`
- **JC13.** `docs/architecture/execution-runtime-boundary.md`
- **JC14.** `lib/jido_code/factory/execution/context_package.ex`
- **JC15.** `docs/architecture/governed-knowledge-memory.md`
- **JC16.** `docs/architecture/claims-time-transitions-and-inference.md`
- **JC17.** `docs/operations/fleet-capacity-retention-and-observability.md`, `lib/jido_code/knowledge/retention/policy.ex`, and `lib/jido_code/knowledge/retention/planner.ex`
- **JC18.** `lib/jido_code/security/data_policy.ex`

### JidoCode research background

- **JR01.** `docs/research/02-secure-effective-agent-harness.md`
- **JR02.** `docs/research/04-ontology-backed-source-graphs-for-coding-agents.md`

## Milestones

1. Accepted contracts: namespace/module ownership, symbol-versus-occurrence
   identity, certainty vocabulary, and span conventions decided through ADRs.
2. Vocabulary reconciliation: every emitted term declared or replaced, Source
   Core and provenance alignment shipped with a namespace-aware registry.
3. Corrected structural Elixir profile: safe syntax-only extraction of modules,
   clauses, patterns, guards, directives, behaviours, protocols, and structs.
4. Segmented publication and reviewed tools: manifest/segment families, logical
   analysis snapshots, and the minimal authorized source tool surface.
5. Compiler, Mix, BEAM, and type profiles: governed macro expansion provenance,
   build lineage, and separate typespec/Dialyzer/gradual-type modules.
6. OTP runtime and framework overlays: declared-versus-observed topology plus
   Phoenix/LiveView/Ecto/Telemetry profiles.
7. Collaboration, supply chain, and governance: actor reconciliation, external
   format adapters, and privacy/retention/erasure contracts.
