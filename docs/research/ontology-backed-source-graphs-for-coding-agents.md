## 4. Ontology-Backed Source Graphs for Coding Agents

- Status: research proposal, not an accepted architecture decision
- Research cutoff: 2026-08-15
- JidoCode revision inspected: `f412969301be201a4783612184be607673273a79`
- `elixir-ontologies` revision inspected: `fb2432ae666062b8d0d601f742abbadda0583b02`

## Executive conclusion

A source-code graph can make a coding agent materially better at navigating a
repository, selecting context, explaining dependencies, planning cross-file
changes, and checking whether an edit is structurally complete. The best
evidence is for code localization and repository context selection. There is
also long-standing production evidence for graph-backed navigation, static
analysis, vulnerability discovery, migration tooling, and dead-code analysis.

The defensible claim is narrower than "graphs make agents understand code":

> Revision-pinned, typed source relationships can make repository navigation
> more relevant, inspectable, reproducible, and economical when graph expansion
> is bounded, combined with lexical retrieval, and validated by source reads,
> builds, static analysis, and tests.

The graph should not replace source text, grep, compiler analysis, runtime
evidence, or tests. It should provide a governed semantic index and evidence
layer over those sources. A productive agent retrieval sequence is:

1. Anchor on issue terms, paths, stack frames, exact symbols, grep, or lexical
   search.
2. Resolve those anchors to revision-pinned graph entities.
3. Expand a small, relation-filtered neighborhood, normally one hop.
4. Rank paths and retrieve only the relevant source spans.
5. Re-query after edits and verify with executable tools.

This conclusion is supported by RepoGraph, LocAgent, CodexGraph, GraphCoder,
DraCo, RepoHyper, CodePlan, learned program-graph research, and production
systems including Joern, CodeQL, Glean, Kythe, SCIP, and aider. RepoGraph also
shows a specific failure mode: its two-hop flattened context used substantially
more tokens and underperformed the no-RepoGraph Agentless baseline [S26].
SWE-agent and aider separately support concise, budgeted context [S32, S46].

`elixir-ontologies` is strategically valuable because it models Elixir concepts
that JidoCode's current compact source graph omits: ordered function clauses,
patterns, guards, protocols, behaviours, macros, types, structs, OTP patterns,
expressions, source locations, and code evolution. It is a broad research
prototype and ontology reference, not currently a drop-in production analyzer.
JidoCode should evaluate a pinned subset behind the existing
`Factory.Ports.SourceAnalyzer` boundary, transform all output into a new closed
JidoCode source contract, and never let the package own the store or publish raw
RDF directly.

The recommended target is an ontology-backed hybrid retrieval service with:

- immutable, exact-snapshot source facts;
- separate authored, static-may, inferred, runtime-observed, and temporal
  relations;
- deterministic source occurrences and source spans;
- provenance and coverage on every analysis layer;
- segmented source graphs with a closeable manifest;
- reviewed, typed, authorized, bounded semantic tools over SPARQL;
- source text fetched from an exact verified worktree rather than persisted in
  the structural graph;
- compact evidence paths compiled into model context;
- no unrestricted model-generated SPARQL;
- no second application-owned graph authority;
- independent build, test, and security verification after graph-guided edits.

## Recommendation summary

| Question | Recommendation |
| --- | --- |
| Does a source graph benefit coding agents? | Yes, primarily for localization, context selection, dependency explanation, change planning, and structural checks. |
| Does RDF or SPARQL itself improve model accuracy? | No such causal evidence was found. RDF/SPARQL provides integration, governance, provenance, and deterministic querying. |
| Should graph retrieval replace grep or embeddings? | No. Use exact and lexical retrieval to anchor graph traversal. |
| Should the model receive raw triples or whole neighborhoods? | No. Return ranked paths, compact entities, source spans, omissions, and a bounded frontier. |
| Should the model generate arbitrary SPARQL? | No. Use reviewed semantic query tools backed by the query catalog. A constrained query planner may select templates, never query text. |
| Should `elixir-ontologies` publish directly to TripleStore? | No. Its output is untrusted analyzer input and must pass a new JidoCode admission contract. |
| Should JidoCode adopt the full expression graph immediately? | No. Start with a corrected, bounded structural profile and measure each additional relation. Do not publish raw upstream light-mode output. |
| Can the current `source_revision` graph hold the richer model? | Not safely. Current publication and semantic-snapshot bounds require a segmented protocol and topology change. |
| Is static `calls` a fact? | Usually it is a `mayCall` result with an analysis method and uncertainty. Runtime `observedCall` is a different relation. |
| Can graph reachability prove dead code or safe deletion? | Not for Elixir by itself. Dynamic dispatch, macros, configuration, and runtime registrations require conservative fallbacks and runtime/domain evidence. |

## Scope and method

This report asks:

1. What kinds of source-code graph exist, and which questions can each answer?
2. What empirical benefits have graph-guided coding systems demonstrated?
3. What tools become possible for an autonomous or human-supervised coding
   agent?
4. What is special about an Elixir ontology?
5. What does `elixir-ontologies` actually implement at the inspected revision?
6. How could it fit JidoCode's graph authority, security, provenance, revision,
   query, and capacity contracts?
7. What should be measured before graph retrieval can influence production
   execution?

The review used four evidence classes:

- foundational and peer-reviewed work on program graphs, source ontologies,
  graph learning, repository retrieval, localization, and repair;
- normative RDF, SPARQL, PROV-O, SHACL, and KDM specifications;
- official documentation and engineering reports from mature code-intelligence
  systems;
- direct source inspection of JidoCode and `elixir-ontologies` at the revisions
  named above.

Reported benchmark numbers are evidence about a complete experimental system,
not proof that a graph alone caused every gain. Results from SWE-bench original,
Lite, Verified, filtered subsets, completion benchmarks, and proprietary product
telemetry are not directly comparable [S38]. Preprints and vendor reports are
labeled as such. README claims were checked against implementation where
possible.

## What "a graph of source code" means

The phrase covers several different representations. They should not be merged
without preserving their semantics.

### Syntax graph

An abstract syntax tree records authored language structure: module and function
declarations, clauses, patterns, guards, calls, literals, operators, control
forms, and source ranges. It is precise about parsed syntax, but not necessarily
about runtime targets or values. srcML is a mature example of source-preserving,
lightweight syntax infrastructure, distinct from compiler-resolved semantics
[S49].

Good uses:

- locate declarations and clauses;
- preserve containment and ordering;
- distinguish `def`, `defp`, and `defmacro`;
- identify syntactic call sites;
- select exact source spans for editing;
- drive structural refactoring.

Risks:

- expression-level ASTs are large and deep;
- generated behavior is absent unless macros are expanded;
- syntax alone does not establish runtime control or data flow.

### Symbol and cross-reference graph

This graph connects files, modules, functions, types, declarations, references,
imports, aliases, and implementations. SCIP, Kythe, Glean, and language servers
provide mature examples [S40-S43, S48].

Good uses:

- go to definition;
- find references;
- list callers and implementations;
- repository maps;
- rename and signature-change preparation;
- code ownership and API surface discovery.

Its usefulness depends on symbol resolution. A syntactic string such as
`Worker.run/1` is not equivalent to a compiler-resolved target.

### Call and dispatch graph

A call graph links caller occurrences to possible or observed callees. Dynamic
languages require qualification:

- `syntacticInvocation`: source contains a call-shaped expression;
- `mayCall`: static analysis found a possible target;
- `mustCall`: valid only under a documented analysis model;
- `observedCall`: a trace observed the edge in one execution;
- `unresolvedCall`: the target could not be resolved.

Collapsing all five into `calls` gives agents false confidence.

### Control-flow graph

Control-flow graphs connect possible execution steps inside a function or across
procedures. They support reachability, exceptional flow, path explanation, and
some verification tasks. They are more expensive and more analysis-dependent
than syntax or symbol graphs.

### Data-flow and dependence graphs

Program dependence graphs combine data and control dependencies. System
dependence graphs extend slicing across procedure boundaries. IFDS frames a
class of interprocedural data-flow problems as graph reachability [S8-S10].

Good uses:

- backward slices from an error or sink;
- forward impact from a value or source;
- taint and vulnerability paths;
- variable misuse and resource-flow checks;
- selecting the smallest behaviorally relevant context.

These graphs express an analysis result, not ground truth. CodeQL explicitly
notes challenges involving missing library source, runtime call targets,
aliasing, size, and global-analysis cost [S39].

### Code property graph

A code property graph combines syntax, control flow, and data flow into a
directed, labeled, attributed multigraph. The original CPG work targeted
vulnerability discovery; Joern later added language frontends and abstraction
overlays [S11-S13].

The central benefit is cross-view querying. A query can move from a source
construct to its control or data-flow consequences without manually joining
separate tools. The operational warning is equally important: Joern replaced a
general-purpose graph database and Gremlin with specialized storage and a DSL
after encountering limitations [S12]. RDF is therefore a useful governed model,
but not automatically the fastest execution representation for every analysis.

### Ontology-backed knowledge graph

An ontology gives shared meaning to classes and relationships. CodeOntology,
SEON, and iSPAROL demonstrate RDF/ontology-backed source and repository models
[S14-S16]. KDM provides a standardized software metamodel [S17]. RDF, SPARQL,
PROV-O, and SHACL provide semantic-web integration and validation standards
[S18]. `elixir-ontologies` adds an Elixir-specific model.

Benefits beyond a generic property graph include:

- stable, globally named terms;
- explicit distinctions such as protocol versus behaviour;
- schema and alignment across language, repository, runtime, and provenance
  domains;
- named graph and revision scoping;
- declarative SPARQL queries and property paths;
- PROV-O attribution;
- SHACL integrity checks;
- controlled inference over class and property hierarchies.

No reviewed study establishes that RDF or SPARQL as storage/query technologies
directly improve coding accuracy. Their value is architectural: integration,
interoperability, reviewability, provenance, and deterministic questions.

### Dynamic evidence graph

Coverage, traces, process registrations, messages, endpoint traffic, and test
results describe observed executions. Dynamic evidence can resolve or refute
some static possibilities, but an unobserved edge is not necessarily impossible.

Static and dynamic relations need separate predicates and provenance. Meta's
SCARF combines compiler-derived dependencies with runtime and domain-specific
usage because static graphs alone miss dynamic references [S45].

### Temporal and evolution graph

A temporal graph connects commits, snapshots, files, symbol occurrences,
changes, renames, migrations, reviews, and releases. It supports questions such
as "when did this dependency appear?" and "which accepted change introduced
this path?"

Snapshot occurrence identity and conceptual symbol continuity are different:

- the occurrence is exact for one tree and location;
- continuity across revisions is a derived, confidence-bearing claim;
- a rename detector must not silently rewrite historical identity.

### Task, plan, and provenance graphs

CodePlan and CodeR also use graphs, but their plan or task graphs represent edit
obligations and agent work, not source structure [S29-S30]. JidoCode should link
these layers without conflating them:

```text
source graph -> supports -> localization or impact observation
observation -> motivates -> edit obligation
edit obligation -> realized by -> patch
patch -> evaluated by -> test/static-analysis evidence
```

## What the research demonstrates

### Strongest result: better localization and context selection

Repository tasks fail when relevant code is outside the current file or prompt.
Graph relations provide a different relevance signal from lexical similarity:
containment, definitions, references, calls, imports, inheritance, data flow,
and configuration. Several systems show that this helps locate functions and
assemble context [S25-S28, S34-S37].

| System | Representation | Reported result | Important caveat |
| --- | --- | --- | --- |
| RepoGraph, ICLR 2025 | Line-level definition/reference graph with `invoke` and `contain` edges | Agentless on SWE-bench Lite rose from 27.33% to 29.67%; AutoCodeRover 19.00% to 21.33%; SWE-agent 18.33% to 20.33% | One-hop flattened context worked; two-hop flattened context used far more tokens and fell below the Agentless baseline. |
| LocAgent, ACL 2025 | Directory, file, class, and function graph with containment, import, invocation, and inheritance | Fine-tuned Qwen-32B reached 92.70% file Acc@5 and 77.01% function Acc@10 on 274 Lite cases | Python-only and task-specific fine-tuning; lexical `SearchEntity` was more important than graph traversal alone. |
| CodexGraph, NAACL 2025 | Python symbol graph queried through generated Cypher | On a random 1,000-example Python CrossCodeEval Lite subset, GPT-4o exact match was 27.90 versus 21.20 for BM25/AutoCodeRover; on 212 retained EvoCodeBench examples, Pass@1 was 36.02 versus 28.78 | Weak Qwen results and high token use show dependence on model/query translation; environment exclusions affected EvoCodeBench, and 43 SymPy SWE-bench cases were excluded. |
| GraphCoder, ASE 2024 | Statement graph with control flow and dependence | Average gains over RAG baselines of 6.06 percentage points code exact match and 6.23 identifier exact match | Next-statement completion on a custom Python/Java benchmark, not issue repair. |
| DraCo, ACL 2024 | Type-sensitive Python data-flow context graph | Average gains over RepoCoder of 3.43 points exact match and 3.27 identifier F1; prompt generation around 40-44 ms versus roughly 4.1-4.4 s | A two-hop CCFinder comparator could hurt; the task is completion, not repair. |
| RepoHyper, FORGE 2025 | Function/class/script graph with imports, calls, ownership, containment, inheritance | GPT-3.5 exact match reached 52.76/64.06 on two RepoBench settings versus RepoCoder 48.73/59.55 | Python-only; link prediction trained on RepoBench. |
| CodeAnchor, 2026 preprint whose manuscript states acceptance at ISSTA 2026 | Lightweight topology injected as source comments | On LocAgent's filtered 274-task SWE-bench Lite subset, basic topology improved Func@5 from 83.21 to 85.40 and shortened trajectories | Dense annotations increased rounds and tokens without improving function accuracy; independent proceedings metadata was not available at the cutoff. |

The clearest design signal comes from the negative results:

- RepoGraph's one-hop flattened graph used about 2,311 tokens and resolved
  29.67% with Agentless. Its two-hop flattened graph used about 10,505 tokens
  and resolved 26.00%, below the 27.33% baseline [S26].
- LocAgent's sparse entity search was essential; removing it hurt more than
  removing graph traversal [S27].
- CodexGraph's separate natural-language-to-Cypher translator was critical.
  Removing it reduced GPT-4o CrossCodeEval exact match from 27.90 to 8.30, while
  graph interaction used much more context than BM25 [S25].
- SWE-agent found that concise, bounded file views outperformed showing full
  files or retaining full history [S32].
- aider ranks a repository graph to fit a token budget rather than dumping the
  whole graph [S46].

The product implication is not "retrieve more relationships." It is "use typed
relationships to select less, better source."

### End-to-end repair gains are smaller than localization gains

LocAgent's localization improved downstream Agentless Pass@10 from 33.58% to
36.13% with Qwen and 37.59% with Claude, but Pass@1 moved only from 26.31% to
26.79%/27.92% [S27]. A graph can identify likely edit sites, but patch correctness
still depends on model capability, edit mechanics, requirements, tests, and
selection among candidates.

Graphs should therefore optimize an intermediate contract:

```text
issue evidence
  -> candidate entities with reasons
  -> bounded source spans
  -> explicit edit obligations
  -> patch
  -> independent verification
```

### Graph-guided planning helps multi-file changes

CodePlan incrementally builds a dependency graph and an adaptive plan graph.
Five of seven evaluated repositories passed build/type validity checks, while
baselines using the same context but no planning passed none of seven [S29]. The
sample is small and task-specific, but it supports a useful distinction:

- a source graph explains what may be affected;
- a plan graph records which edits remain required;
- verification updates or closes obligations.

For example, changing an Elixir behaviour callback signature may create
obligations for the behaviour declaration, every implementing module, specs,
tests, and callers. The plan should reference exact source entities but remain in
the `repository_control` graph; `run_attempt` records only execution provenance.

### Graphs are established for security and maintenance tools

The non-agent evidence is mature:

- program dependence and slicing have decades of formal foundations [S8-S10];
- CPG queries combine syntax, control, and data flow for vulnerability discovery
  [S11-S13];
- CodeQL exposes local/global flow and taint tracking with source-to-sink paths
  [S39];
- Glean supports callers, inheritance, dead-code searches, linters, migrations,
  refactoring, and custom facts [S43];
- SCIP, Kythe, and Sourcegraph support interoperable definitions/references and
  cross-language associations [S40-S42, S48];
- Meta reports that moving SCARF from per-symbol checks to a complete augmented
  dependency graph increased dead code removed by nearly 50%, and that the
  system deleted over 100 million lines through more than 370,000 change
  requests over five years [S45].

SCARF is also a warning. Meta augments static facts with runtime and
domain-specific edges, retains textual fallback for dynamic references, and
acknowledges that misunderstood edges can cause incorrect deletion [S45]. A
coding agent must not equate graph non-reachability with proof of safety.

### Learned program graphs show useful semantics, but not an agent blueprint

GraphCodeBERT's data-flow-aware pretraining improved code-search MRR from
CodeBERT's 0.693 to 0.713, and removing data flow returned it to 0.693. It also
improved reported code-refinement results [S21]. Learning to Represent Programs
with Graphs, Global Relational Models, Devign, and ProGraML show benefits from
syntax, semantic, control, and data-flow relations on bounded tasks [S19-S24].

These results support preserving semantic relations. They do not show that a
tool-using coding agent should ingest a full AST/CPG, use a GNN, or serialize RDF
into its prompt.

### Strong non-graph baselines remain necessary

RepoCoder improved an in-file completion baseline through iterative similarity
retrieval [S31]. Agentless uses repository trees, skeletons, patch sampling, and
test-based selection without a graph-driven autonomous loop [S33]. SWE-agent
shows that a disciplined agent-computer interface itself has a large effect
[S32].

Every JidoCode graph evaluation must compare against:

- exact path/symbol extraction;
- grep or ripgrep;
- lexical/BM25 retrieval;
- repository tree and skeleton;
- optional embeddings;
- the same agent, model, budget, prompts, editor, and tests without graph tools.

## JidoCode's current source graph

JidoCode already has a governed source-analysis boundary. It should be evolved,
not bypassed.

### Existing flow

```text
exact clean Git worktree
  -> Factory.SourceAnalysis.Request
  -> Factory.Ports.SourceAnalyzer
  -> Integrations.ElixirSourceAnalyzer
  -> Factory.SourceAnalysis.Result
  -> Factory.SourceAnalysis.Command
  -> Knowledge.Commands.PublishSourceGraph
  -> governed command pipeline
  -> closed source_revision graph
  -> reviewed QueryCatalog query
  -> Knowledge.Projections.Source
```

The analyzer does not receive a store handle or command authority. Its RDF is
untrusted input. Publication separately checks identity, vocabulary, bounds,
snapshot linkage, authorization, target revision, and graph lifecycle. This is
the correct trust boundary.

Binding constraints include:

- the embedded quad dataset is the sole application-owned durable authority
  (`docs/adr/0001-graph-only-source-of-truth.md`);
- production callers use semantic commands and reviewed queries, not store
  handles or arbitrary SPARQL
  (`docs/adr/0002-triple-store-backend-contract.md`);
- one source graph is immutable and closed for a repository tree snapshot
  (`docs/architecture/source-analysis.md` and
  `docs/architecture/graph-identity-and-topology.md`).

### Facts represented today

The current `elixir-ast/1.0.0` analyzer emits:

- one analysis activity with analyzer version, configuration digest, and input
  tree digest;
- `.ex`/`.exs` source artifacts with relative path, content digest, byte count,
  language, source snapshot, and analysis provenance;
- module symbols;
- `def` and `defp` function symbols with name, arity, visibility, module, and
  artifact;
- syntactic local and remote call references;
- module dependencies collapsed from `alias`, `import`, `require`, `use`, and
  `@behaviour`;
- coarse OTP labels for `GenServer`, `Supervisor`, and `Application`;
- graph-level coverage, warning, count, analyzer, configuration, tree, and
  dataset-digest metadata.

Current reviewed queries provide:

- source readiness/freshness;
- modules;
- functions;
- OTP patterns;
- dependencies;
- one-entity neighborhood;
- a shallow impact view over calls, dependencies, callers, dependents, and
  definitions.

### Important limitations

The current graph does not represent:

- source ranges, bodies, comments, or docs;
- function clauses, order, patterns, guards, or defaults;
- `defmacro`, quote/unquote, generated definitions, or macro provenance;
- specs, types, callbacks, protocols, implementations, structs, or fields;
- resolved declaration-reference identity;
- the distinction between alias/import/require/use/behaviour edges;
- control or data flow;
- test, route, endpoint, Ecto, configuration, or migration relationships;
- dynamic OTP process/message topology;
- commit parentage, rename continuity, or graph diffs.

Calls are syntactic strings connected to separate reference resources, not
resolved declared functions. A repeated reference identity can also collapse
occurrences across files and violate the publication command's single-artifact
cardinality. A rich graph needs first-class reference or call-site occurrences.

The production application does not yet orchestrate source analysis end to end;
the complete flow currently appears in test fixtures. The product query
allowlist also does not expose source queries. A rich ontology alone would not
make source relationships available to an agent. The coordinator, reviewed tool
surface, context compiler, and product authorization path are still required.

### Current scale barriers

The existing contract is intentionally small:

- default source request: 100 files, 5 MB total, 100 symbols, 100,000 AST
  expressions, 400 statements, and 10 seconds;
- source publication: at most 400 analyzer statements;
- command change set: at most 1,000 effective additions;
- backend atomic batch: at most 10,000 quads;
- semantic snapshot: at most 20 graphs and 10,000 total quads;
- normal reviewed query: 200 rows, 500 triples, depth 2, and 5 seconds;
- declared fleet capacity: 250,000 source symbols.

`elixir-ontologies` documents roughly 500 KB per 100 functions in light mode and
5-20 MB per 100 functions in full expression mode [S1-S2]. Even allowing for
serialization differences, its rich output cannot be inserted into the current
single source graph by increasing one constant.

## `elixir-ontologies` deep inspection

### Project identity and maturity

The inspected public repository is
[`pcharbon70/elixir-ontologies`](https://github.com/pcharbon70/elixir-ontologies)
at commit `fb2432ae666062b8d0d601f742abbadda0583b02` [S1]. It describes an OWL
ontology and Elixir implementation for static structure, OTP, and evolution.

Direct inspection found:

- package version `0.1.0`;
- no Git tags or GitHub releases;
- no published Hex package under `elixir_ontologies` at the research cutoff;
- no CI workflow in the repository;
- README/getting-started installation text claiming `~> 1.0`, inconsistent with
  the package version;
- MIT repository/package metadata; four OWL artifacts additionally declare CC BY
  4.0, while the Shapes artifact has no embedded license declaration, so the
  artifact licensing must be clarified before vendoring;
- a Req `~> 0.5` constraint that overlaps JidoCode's `~> 0.6.1`; compatibility
  with upstream's Req 0.5.16 lock still needs testing;
- an optional relative path dependency on `../triple_store`, while JidoCode pins
  TripleStore from Git [S2-S3].

This is a research prototype with a large implementation and test corpus, not a
stable released dependency.

### Ontology scope

The project exposes five main ontology artifacts [S1-S2]:

| Ontology | Intended content |
| --- | --- |
| Core | AST nodes, expressions, literals, operators, control forms, patterns, scopes, and bindings |
| Structure | Modules, functions, ordered clauses, parameters, macros, protocols, behaviours, structs, types, specs, callbacks, and attributes |
| OTP | Processes, registration, supervision, GenServer, Agent, Task, Application, `:gen_statem`, ETS, distribution, and telemetry |
| Evolution | Code versions, commits, changesets, refactorings, releases, agents, provenance, and bitemporal concepts |
| Shapes | Naming, required properties, cardinality, values, and cross-entity SHACL constraints |

The namespaces are:

```text
https://w3id.org/elixir-code/core#
https://w3id.org/elixir-code/structure#
https://w3id.org/elixir-code/otp#
https://w3id.org/elixir-code/evolution#
https://w3id.org/elixir-code/shapes#
```

These are valid RDF namespace IRIs but did not resolve to hosted ontology
documents at the research cutoff. JidoCode must vendor and digest-pin reviewed
artifacts rather than depend on namespace dereferencing.

The schema correctly highlights language distinctions that generic
object-oriented ontologies often obscure:

- function identity includes module, name, and arity;
- clauses are ordered because first match wins;
- patterns and guards are semantic structure, not parameter decoration;
- protocols dispatch on data type and are not behaviours;
- behaviours define callback contracts;
- macro and quote forms represent compile-time metaprogramming;
- OTP supervision and process patterns are first-class concepts.

### Implemented strengths

The strongest implementation features are:

- static parsing with `Code.string_to_quoted/2`, avoiding compilation or project
  code execution;
- broad extractor and builder components;
- working module/function/structure extraction;
- contextual `FileAnalyzer.analyze_string/3` with caller-supplied relative path,
  source kind, and expression identity material;
- deterministic SHA-256 full-expression namespaces; the identity material does
  not revision-scope module or function IRIs;
- contextual input limits of 1,024-byte paths and 2,048-byte expression identity
  material; contextual full-expression mode additionally caps 100,000 pre-build
  AST nodes, depth 100, 100,000 emitted expression resources, and 500,000 total
  triples;
- no graph after a detected parse, bound, or builder failure, although individual
  extractor failures can still be silently omitted;
- generic expression fallback for unsupported AST forms;
- substantial native SHACL support;
- Turtle graph output and optional in-memory querying.

The contextual file API is the most promising integration point because
JidoCode can provide a trusted, exact snapshot and admitted relative path while
retaining control of discovery, limits, timeouts, and publication [S4].

### Implemented capability versus schema capability

The ontology is broader than the normal analysis pipeline. A schema class or
standalone builder does not mean the default project analyzer emits complete
facts for it.

| Capability | Inspected implementation status | Agent consequence |
| --- | --- | --- |
| Modules and functions | Basic flat-module output exists; nested hierarchy and function ownership are unreliable | Useful only after nested-module fixtures and adapter fixes |
| Clauses, parameters, patterns, and many types | Builders exist, but light-mode repeated clauses and fixed blank nodes collapse | Ordered clause facts require full mode or an adapter/upstream fix |
| Protocols, behaviours, and structs | Behaviour/struct support is partial; ordinary top-level `defprotocol`/`defimpl` files are missed | Defer protocol facts until normal file analysis is fixed |
| Calls | Light-mode ownership is synthetic; remote targets are constructed, not resolved, and local target edges may be absent | Not safe as authoritative function impact data |
| Specs and attributes | Extracted into intermediate analysis, then omitted by pipeline conversion | README/schema breadth exceeds normal output |
| Rich macro data | Partial; some intermediate results are dropped | Cannot claim macro-complete source understanding |
| GenServer/Supervisor/Agent/Task | Basic implementation markers in normal pipeline | Detailed OTP topology needs separate component integration |
| ETS | Extracted by `FileAnalyzer`, dropped by pipeline conversion | Not available in ordinary project output |
| Application | Schema and standalone extractor, but no normal RDF builder/pipeline integration | Application/supervision queries would be incomplete |
| Evolution | Rich schema and standalone APIs | Not an operational revisioned dataset in normal analysis |
| Named graphs | `RDF.Graph` may have a name | No dataset-level snapshot orchestration |
| RDF-star | Documented in evolution design | No implementation found |
| Output formats | README/config mention Turtle, N-Triples, JSON-LD | Standard graph save/load accepts Turtle only |
| Incremental CLI | State and update commands exist | Persisted state drops analyses and normally falls back to full reanalysis |
| Phoenix, Ecto, Jido | No route/schema/Jido semantics; a standalone, non-integrated macro classifier recognizes selected Ecto/Phoenix macro names | Requires separate framework overlays |

### Specific defects and integration risks

#### Nested modules and function ownership

Nested modules are discovered, but the normal analyzer does not pass parent
context into module extraction. Recursive function walking can also attribute
inner functions to the outer module and then extract them again for the inner
module. Basic flat-module output exists; nested hierarchy and ownership need an
adapter or upstream fix [S4].

#### Light-mode clause identity

In light mode, repeated definitions begin with the same clause order and can map
to the same function/clause IRI. Fixed blank-node labels can also collapse heads,
bodies, and guards when graphs merge. Ordered clauses and detailed patterns
require contextual full mode or an adapter/upstream identity fix [S4, S6].

#### Top-level protocols

Normal file analysis roots at `defmodule` and runs protocol extraction inside
discovered module bodies. Ordinary top-level `defprotocol` and `defimpl` files
are therefore missed. Protocol builders exist, but this output should not enter a
production profile until the analysis root is fixed [S4].

#### Function-level call ownership and resolution

The default/light pipeline extracts calls across a module and the orchestrator
assigns them to a synthetic `Module/module/0` caller rather than each containing
function. Remote targets are constructed from syntactic module/name/arity rather
than resolved to declarations, and local target edges may be absent because the
pipeline and call builder use different metadata keys [S5-S6]. This makes
function-level caller, impact, and path tools unreliable in that mode. JidoCode's
current analyzer is simpler but more precise about which parsed function body
contains a syntactic call.

#### Pipeline data loss

`FileAnalyzer` extracts specs, attributes, macro details, calls, control flow,
exceptions, and ETS information. `Pipeline.convert_module_analysis/1` omits
several of those fields before the normal builder path [S4-S5]. Integration tests
must evaluate emitted RDF, not merely the presence of extractors.

#### Incomplete source-location resources

Some module and function builders link to source-location IRIs without fully
describing those location/source-file resources, while expression locations are
more complete [S6]. Clause building emits no complete clause location. JidoCode
needs adapter-synthesized, digest-validated spans plus a closed source-span shape
and must reject dangling or ambiguous locations.

#### Output-format mismatch

Configuration and documentation claim multiple formats, but the standard
`Graph.save/3` and load path support Turtle at the inspected revision [S7]. This
does not block an in-process adapter, but it is a maturity signal.

#### Incremental update mismatch

The CLI update state records paths/status but reconstructs files with
`analysis: nil`; the updater then detects missing analyses and performs a full
analysis [S5]. In-process update can reuse analyses, but cross-process CLI
incrementality does not currently provide the advertised operational behavior.

#### SHACL fail-open behavior

When upstream SPARQL execution returns or raises an error, its validator logs the
problem and returns no violations; that code path does not itself enforce a
timeout [S7]. The fail-open behavior is unsuitable for JidoCode write admission.
Upstream validation may be diagnostic, but JidoCode's own closed validator must
fail safely.

#### Graph authority conflict

The upstream knowledge-graph and store commands must not run as a JidoCode
sidecar. JidoCode's accepted ADRs allow one application-owned durable quad
authority. Any accepted source facts must enter via JidoCode's semantic command
pipeline with local authorization, provenance, revisions, and receipts.

### Recommended posture toward the project

Do not add the project as a production dependency yet. Use it in three roles:

1. **Ontology reference**: evaluate classes, properties, constraints, and Elixir
   distinctions for a JidoCode ontology release.
2. **Fixture oracle candidate**: compare emitted structure against hand-reviewed
   snapshots and JidoCode's current analyzer.
3. **Pinned adapter spike**: invoke only a bounded contextual file API in an
   isolated evaluation path with no store or publication authority.

Avoid in the first spike:

- the project-wide recursive scanner;
- the upstream persistent knowledge-graph layer;
- the evolution writer;
- the incremental CLI;
- raw source inclusion;
- Git metadata extraction already owned by JidoCode;
- full-expression mode as default;
- raw upstream SHACL as the admission authority.

## Benefits for coding agents

### 1. Stable repository orientation

A repository map can show modules, public functions, behaviours, protocols,
supervision roots, tests, and high-value dependencies without reading every
file. Unlike an LLM-generated summary, every item can point to an exact source
occurrence and graph revision.

Agent questions:

- Which modules define the public surface of this application?
- Where is `JidoCode.Knowledge.execute/2` defined?
- Which modules implement a given behaviour?
- Which protocol implementation handles this struct?
- Which files contain the supervision path to a worker?

### 2. Better localization

An issue rarely names every affected function. A hybrid locator can search issue
terms, resolve candidate entities, then rank incoming/outgoing relationships.
For a failing GenServer callback, it might retrieve:

- the callback clause and guard;
- the behaviour declaration;
- callers or message senders;
- sibling callback clauses;
- the child spec and supervisor;
- focused tests;
- recent changes to those entities.

The agent receives why each entity is relevant, not just a similarity score.

### 3. Smaller and more coherent context

Graph traversal can replace broad file inclusion with:

- one declaration span;
- two callers;
- one implementation;
- a callback contract;
- one failing test;
- an explicit frontier saying which neighbors were not expanded.

This is the primary context-economy benefit. The graph itself should normally
remain outside the prompt.

### 4. Explainable change impact

Reverse traversal from changed symbols can identify direct callers, behaviour
implementations, protocol implementations, type/spec consumers, struct field
users, and tests. Every candidate should include an evidence path:

```text
changed callback
  <- implements callback - Worker.handle_call/3
  <- supervised child - WorkerSupervisor
  <- started by - Application.start/2
```

Impact is a candidate set, not automatic proof that every node must change.

### 5. Ordered migration planning

The graph can turn a repository-wide API change into explicit obligations:

- declaration and specs;
- implementations/overrides;
- direct callers;
- adapters at application boundaries;
- tests and fixtures;
- docs or examples if separately indexed;
- configuration and generated bindings where modeled.

Strongly connected components and dependency order can group edits. The agent
can re-run an "old API remaining" query after each patch.

### 6. Structural verification

After an edit, a rebuilt graph can check expected structural outcomes:

- no remaining references to the old function/arity;
- every behaviour callback is still implemented;
- a protocol implementation exists for a new type;
- no forbidden dependency crosses a layer boundary;
- all intended call sites now reach the new adapter;
- no newly introduced cycle exists;
- every new public function has an expected spec if policy requires it.

These checks supplement compilation/tests. They do not replace them.

### 7. Security path analysis

With a trustworthy data-flow overlay, an agent can request source-to-sink paths,
sanitizers, unresolved calls, and affected source spans. It can then edit the
smallest relevant slice and verify that the path is absent or guarded after
reanalysis. This follows the Joern and CodeQL model [S11-S13, S39].

Semgrep's official documentation similarly distinguishes local community
analysis from proprietary cross-function/cross-file analysis [S47]. GitHub's
product-reported Copilot Autofix beta data associated CodeQL-backed remediation
with a median 28 minutes versus 1.5 hours for manual fixes; this is observational
vendor evidence, not a graph-only controlled study [S50].

An Elixir-specific analysis would need semantics for Plug/Phoenix parameters,
Ecto queries, file/process/network sinks, serializers, and sanitizers. Those are
framework overlays, not consequences of the base language ontology.

### 8. Test selection and fault localization

Static paths can suggest tests related to changed entities. Runtime coverage and
prior failure evidence can substantially improve the mapping. A safe strategy is:

1. run graph-ranked focused tests for fast feedback;
2. run package/application tests;
3. run the required full verification suite before acceptance.

Static reachability alone must not authorize skipping required tests.

### 9. Architecture conformance

Reviewed queries can detect forbidden paths such as UI-to-storage calls that
bypass an application boundary, dependencies from a lower layer to a higher
layer, or unauthorized direct store access. The ontology can classify modules
and relations, while repository policy defines allowed paths.

The graph reports violations. Authority to define or waive architecture policy
remains separate.

### 10. Dead code and cycle analysis

Whole-graph reachability can find unreachable components and cycles that
per-symbol checks miss. For Elixir, roots must include more than direct calls:

- application and supervision starts;
- Phoenix routes and plugs;
- protocol and behaviour dispatch;
- test/config task entry points;
- module/function captures;
- `apply/3` and string/atom dispatch;
- Mix tasks;
- telemetry handlers;
- runtime registrations and messages;
- NIF and Erlang boundaries.

Destructive proposals require conservative text search, runtime evidence,
review, and rollback.

### 11. Semantic code review

A graph diff can summarize a patch by relations rather than lines:

- public symbols added/removed;
- call edges added/removed;
- changed behaviour/protocol obligations;
- dependency cycles introduced;
- new source-to-sink paths;
- supervision topology changes;
- tests no longer connected to changed behavior.

This gives reviewers a high-level checklist while preserving exact diff and test
evidence as primary artifacts.

### 12. Historical "why" queries

Linking source occurrences to commits, pull requests, decisions, evidence, and
accepted knowledge enables:

- Why does this adapter exist?
- Which change introduced this dependency?
- Which test justified this workaround?
- Has a similar migration succeeded before?
- Which analyzer and query produced this impact claim?

Historical content never grants current authority. The query must preserve
valid time, transaction time, source snapshot, and provenance.

### 13. Multi-agent partitioning

A plan can be partitioned by module, umbrella application, strongly connected
component, or bounded subgraph, with explicit boundary symbols and shared
contracts. This can reduce overlapping edits and reveal merge dependencies.

Direct causal evidence for graph-based multi-agent partitioning is limited. It
should be treated as plausible and evaluated through conflicts, duplicated work,
merge failures, elapsed time, and final correctness.

## Elixir-specific graph opportunities

### Function identity and clauses

Elixir function identity is module, name, and arity. Behavior also depends on
ordered clauses, patterns, and guards. The graph should distinguish:

```text
Function JidoCode.Worker.handle_call/3
  hasClause Clause#0
  hasClause Clause#1

Clause#0
  position 0
  headPattern ...
  guard ...
  sourceSpan ...
```

Tools enabled:

- inspect every clause before editing;
- detect shadowed or unreachable clauses with a separate analysis;
- identify which messages a GenServer handles;
- explain why a proposed new clause must precede another;
- preserve defaults and generated arities during signature changes.

### Behaviours and callbacks

Model separately:

- behaviour declaration;
- callback signature/spec;
- module's `@behaviour` claim;
- implementing function occurrences;
- optional callbacks;
- static conformance result;
- compiler or test evidence.

Tools enabled:

- list every implementation affected by callback change;
- identify missing or arity-mismatched callbacks;
- retrieve callback contract beside implementation;
- plan behavior migrations.

### Protocols and implementations

Protocols dispatch on data type, not module inheritance. A graph can connect:

- protocol functions;
- `defimpl` modules;
- `for` target types;
- fallback and deriving declarations;
- call sites whose static type is known or unknown.

Tools enabled:

- find implementations for a value type;
- assess impact of changing a protocol function;
- distinguish protocol dispatch from behaviour callbacks;
- expose unresolved dynamic dispatch rather than inventing one target.

### Macros and generated code

Authored syntax and expanded syntax require separate layers:

- authored macro invocation;
- macro definition;
- quote/unquote structure;
- generated declaration if observed through trusted expansion;
- generated-to-authored provenance;
- compiler/toolchain and configuration identity.

Arbitrary macro expansion executes code and is unsafe for untrusted
repositories. The baseline analyzer should remain syntax-only. A trusted
compile-derived overlay may run only in the governed sandbox with network,
filesystem, secret, time, and resource controls. It must never overwrite the
authored graph.

### `use`, imports, aliases, and requires

These relations must not be collapsed:

- `aliasesModule` affects name resolution;
- `importsFrom` affects unqualified function/macro resolution;
- `requiresModule` enables macro invocation;
- `usesModule` invokes `__using__/1` and may generate code;
- `declaresBehaviour` states a callback contract.

This distinction lets an agent explain whether removing a directive is safe and
why an unqualified call resolves as it does.

### OTP supervision and process interactions

Separate static declarations from observed runtime topology:

- application callback and supervision root;
- child specs and restart/shutdown policy;
- supervisor strategy and static child order;
- registered names and Registry/Via forms;
- GenServer calls, casts, sends, receives, and callback message patterns;
- `DynamicSupervisor` potential children;
- runtime-observed process and message edges.

Tools enabled:

- explain the startup path to a process;
- find restart-impact boundaries;
- locate handlers for a message shape;
- detect likely orphaned workers or unsupervised starts;
- plan supervision migrations;
- correlate a crash with parent/child and recent change evidence.

Static analysis cannot know every runtime PID, dynamic child, registry key, or
message target. The ontology must express unknowns and possibilities.

### Types, specs, structs, and fields

Typespec and struct relations enable:

- signature-aware context;
- callers affected by type changes;
- field read/write sites;
- enforced-key and constructor impact;
- spec/implementation mismatch observations;
- migration from raw maps to structs.

Elixir's typespecs are optional and not a proof of runtime values. Results must
report whether a relation came from a declaration, Dialyzer, another analyzer,
or runtime evidence.

### Mix, umbrella, Phoenix, and Ecto overlays

The base ontology does not currently provide JidoCode-ready framework semantics.
Separate overlays could model:

- umbrella applications and Mix dependencies;
- compile/runtime configuration keys;
- Phoenix routers, scopes, routes, plugs, controllers, LiveViews, and events;
- Ecto schemas, fields, associations, queries, repositories, and migrations;
- Oban jobs, telemetry handlers, and endpoint configuration;
- Jido actions, agents, signals, skills, and workflow relations.

Framework extraction should remain versioned and optional. A false Phoenix or
Ecto edge must not contaminate the language-level ontology.

### Erlang and NIF boundaries

Elixir code invokes Erlang modules directly and may depend on NIFs or ports. A
complete graph needs external symbol/resource stubs and unresolved boundary
markers. Cross-language facts can later link to Erlang or native-language
ontologies without pretending that the Elixir parser analyzed those bodies.

## Recommended agent tool surface

### Principles

The model should ask semantic questions, not write SPARQL. Each tool must be:

- named for user intent;
- backed by a reviewed query or fixed query plan;
- capability- and scope-authorized;
- pinned to repository, source snapshot, analysis profile, ontology release,
  and graph revisions;
- relation-, depth-, row-, byte-, graph-, and time-bounded;
- explicit about coverage, uncertainty, truncation, omissions, and frontier;
- accompanied by a consistency/query receipt;
- unable to mutate the graph or grant capability.

Every result item should include at least:

```text
entity
entity_kind
display_name
source_artifact
source_span
artifact_digest
relation_path
relation_semantics
producer
producer_version
analysis_profile
confidence_or_certainty_class
coverage_status
query_name_and_version
graph_revisions
truncated
omissions
```

### Discovery and navigation tools

#### `search_source_entities`

Inputs:

```text
repository, snapshot, query, kinds, path_prefix, limit
```

After authorizing the repository, snapshot, scope-keyed index, and source graphs,
returns exact and lexical symbol candidates. This is the bridge from issue text
to graph identity. It should combine a reviewed source catalog with a disposable
lexical index, then resolve already authorized candidates in the graph.

#### `inspect_source_entity`

Returns declaration, kind, arity, visibility, clauses, source span, containing
module/file, specs/types, and selected direct relationships.

#### `find_definitions_and_references`

Distinguishes declaration entities from reference occurrences. Returns every
reference site, resolution status, and reason. It must not collapse repeated
occurrences into one symbol resource.

#### `find_callers` and `find_callees`

Inputs include relation modes such as `syntactic`, `static_may`, or
`runtime_observed`. Results expose unresolved dynamic calls and avoid claiming
completeness when macro/build coverage is partial.

#### `find_implementations`

Supports behaviour callbacks, protocols, and future cross-language interfaces
without treating them as one relation.

#### `get_source_neighborhood`

Allows an explicit relation allowlist, direction, one-hop default, degree cap,
node budget, and source-span budget. It returns an unexpanded frontier rather
than silently discarding high-degree neighbors.

### Impact and planning tools

#### `analyze_change_impact`

```text
base_snapshot
target_snapshot or proposed_changed_entities
relation_profile
max_hops
max_nodes
include_tests
```

Returns changed entities, impacted candidates, evidence paths, candidate tests,
uncertainties, and unsupported units. It creates observations, not edit
authority.

#### `plan_api_migration`

Returns declarations, callers, implementations, type/spec consumers, tests,
dependency groups, and a proposed partial order. The repository-control planning
and adoption boundary converts governed candidates into edit obligations.

#### `find_remaining_old_api_uses`

Runs after edits against the new worktree graph. It is especially useful for
arity changes, module moves, and callback/protocol migrations.

#### `explain_dependency_path`

Returns a small number of shortest or highest-confidence paths between two
entities, including edge semantics and provenance. This supports "why is this
file relevant?" and architecture review.

### Elixir semantic tools

#### `inspect_function_clauses`

Returns ordered clauses, parameters, patterns, guards, defaults, and exact spans.

#### `inspect_behaviour_conformance`

Returns declared callbacks, implementations, optional callbacks, missing or
ambiguous matches, and compiler/static evidence.

#### `inspect_protocol_dispatch`

Returns protocol functions, implementations, target types, derives/fallbacks,
and unresolved call sites.

#### `inspect_macro_effects`

By default returns only authored invocation/definition relationships. Expanded
facts require an explicitly trusted expansion profile and include generated
provenance.

#### `inspect_supervision_path`

Returns application, supervisors, child specs, strategies, worker, registration,
and static/dynamic certainty for each edge.

#### `find_message_handlers`

Maps call/cast/send/receive shapes to possible handlers and returns unresolved
dynamic targets. It should never imply exhaustive runtime delivery.

#### `find_struct_field_uses`

Returns declarations, enforced keys, construction, pattern matches, reads,
writes, specs/types, and tests involving a field.

### Analysis and verification tools

#### `slice_dataflow`

Returns bounded source-to-sink or backward slices, sanitizers, unresolved calls,
analysis semantics, and exact source spans. This requires a dedicated data-flow
extractor; the base Elixir ontology does not create one automatically.

#### `check_architecture_rules`

Runs fixed repository policy questions such as forbidden relation paths,
dependency direction, or direct access to protected boundaries.

#### `select_related_tests`

Ranks tests by static paths, runtime coverage, historical co-change/failure, and
scope. Results are an optimization hint, never permission to omit required
verification.

#### `diff_source_graph`

Returns added/removed/changed occurrences and edges between two complete
analysis revisions. It must distinguish a source edit from analyzer/schema drift.

#### `verify_expected_graph_effects`

Checks explicit post-edit obligations: old edges absent, new implementation
present, no new forbidden cycle, and affected callback/protocol sets complete.

#### `explain_source_fact`

Returns the extractor activity, version, configuration, source span/digest,
certainty class, graph revision, and any derivation or runtime evidence behind a
fact.

## SPARQL as an implementation mechanism

SPARQL is well suited to fixed graph patterns, named graph scoping, optional
facts, aggregation, and property paths [S18]. It should remain behind JidoCode's
reviewed query catalog.

### Upstream evaluation query

This query reflects `elixir-ontologies` structure vocabulary and can be used in
an isolated fixture evaluation:

```sparql
PREFIX struct: <https://w3id.org/elixir-code/structure#>

SELECT ?moduleName ?function ?functionName ?arity
WHERE {
  ?module a struct:Module ;
          struct:moduleName ?moduleName ;
          struct:containsFunction ?function .

  ?function struct:functionName ?functionName ;
            struct:arity ?arity .
}
ORDER BY ?moduleName ?functionName ?arity
LIMIT 200
```

This is an evaluation query, not a proposed arbitrary production endpoint.

### Conceptual bounded caller query

The final JidoCode vocabulary must be defined by the ontology release. Using a
placeholder `source:` namespace, a reviewed caller template could be:

```sparql
PREFIX source: <https://jido.run/ontology/source#>

SELECT ?callSite ?caller ?file ?startLine ?certainty
WHERE {
  VALUES ?target { <TARGET_RESOURCE> }

  ?callSite a source:CallSite ;
            source:possibleTarget ?target ;
            source:inCallable ?caller ;
            source:inArtifact ?file ;
            source:startLine ?startLine ;
            source:certaintyClass ?certainty .
}
ORDER BY ?file ?startLine
LIMIT 50
```

The production catalog substitutes an RDF term through typed parameters; it
never interpolates caller-supplied query text.

### Conceptual impact path

```sparql
PREFIX source: <https://jido.run/ontology/source#>

SELECT DISTINCT ?impacted
WHERE {
  VALUES ?changed { <CHANGED_RESOURCE> }

  ?impacted
    (source:possibleTarget|source:implementsCallback|
     source:implementsProtocolFunction|source:dependsOn)+
    ?changed .
}
LIMIT 100
```

In production this needs an explicit depth implementation, relation profile,
degree cap, graph allowlist, and timeout. SPARQL `+` alone is not an adequate
resource bound.

### Conceptual dependency cycle check

```sparql
PREFIX source: <https://jido.run/ontology/source#>

SELECT DISTINCT ?module
WHERE {
  ?module a source:Module ;
          source:dependsOn+ ?module .
}
LIMIT 100
```

Cycle semantics must use source-specific dependency predicates. JidoCode's
existing broad `jf:dependsOn` is also used for work dependencies and must not be
made transitively meaningful across domains.

### Absence queries need completeness

A query such as "behaviour callbacks with no implementation" uses
`FILTER NOT EXISTS`. Under RDF's open-world model, missing data does not mean the
implementation is absent. The tool may report a violation only when:

- the relevant source profile is closed for the exact snapshot;
- every admitted file/module was successfully analyzed;
- generated/macro-derived coverage assumptions are explicit;
- the callback and implementation extractors completed;
- truncation is false.

Otherwise the result is "not found in this incomplete analysis," not "missing."

## Recommended graph model

### Separate schema, facts, analysis, and evidence

Use distinct semantic layers mapped to accepted or explicitly proposed graph
families. These rows do not each create a new family:

| Layer | Examples | Authority semantics |
| --- | --- | --- |
| Ontology release | Elixir classes, properties, shapes, controlled terms | Existing immutable `ontology` family |
| Snapshot manifest | repository tree, analysis profiles, segments, coverage, digests | Proposed source-analysis topology; immutable closed inventory after completion |
| Authored structure | files, modules, functions, clauses, patterns, source spans | Existing or proposed source family; exact parsed-source assertions |
| Static analysis overlay | resolved references, may-call, control/data flow, inferred framework relations | Source or `derived` family according to accepted semantics; method-dependent observations |
| Raw runtime observations | coverage, observed calls/messages/processes, test-run facts | Existing `run_attempt` family |
| Governed verification | admitted build, test, and static-analysis results | Existing `evidence` family |
| Temporal evolution | commits, graph diffs, possible successor/rename links | Existing observation/source/derived families according to fact kind; immutable history and derived continuity |
| Agent goals, plans, and tasks | candidates promoted to control state and edit obligations | Existing `repository_control` family; attempt provenance remains in `run_attempt` |

Do not type all analysis output as equally true. At minimum, preserve:

```text
authored_exact
compiler_exact_under_configuration
static_may
static_must_under_model
derived_rule
runtime_observed
lexical_fallback
unresolved
```

### Identity model

Use occurrence identity for source facts:

```text
Repository
  -> TreeSnapshot
    -> SourceArtifactOccurrence
      -> ModuleOccurrence
        -> FunctionOccurrence
          -> ClauseOccurrence
            -> ExpressionOrReferenceOccurrence
              -> SourceSpan
```

Identity inputs should include what makes the occurrence exact:

- repository identity;
- Git object algorithm and tree digest;
- normalized relative path;
- artifact content digest;
- language/profile;
- occurrence kind and stable structural locator;
- analyzer/schema version where identity depends on extraction granularity.

A conceptual `Function` such as `MyApp.Worker.run/1` may link occurrences across
snapshots. It must not replace the exact occurrence. Rename/move continuity uses
an explicit derived relation with producer, confidence, and evidence.

JidoCode currently identities snapshots by tree digest, not commit SHA. Two
commits with the same tree therefore share a source snapshot. That is appropriate
for exact content. Commit history and parentage must be separate evolution
resources if the product needs "introduced by commit" queries.

### First-class source spans and occurrences

Every declaration, clause, reference, call site, pattern, and diagnostic should
have a span with:

- source artifact occurrence;
- start/end line and column or byte offsets;
- file content digest;
- authored/generated classification;
- optional generated-to-authored provenance.

The graph need not retain raw source bodies. A context compiler can verify the
artifact digest in an exact disposable worktree and read the span through a
governed source-content tool. This preserves the current analyzer/publication
behavior of excluding source bodies. Accepted data policy nevertheless permits
governed source bodies in `source_revision` or bounded artifacts; this proposal
recommends not using that permission for structural segments.

### Qualified relation assertions

Direct RDF edges are compact for exact structural facts:

```text
module containsFunction function
function hasClause clause
clause inArtifact artifact
```

Uncertain or evidence-bearing relationships need a qualified assertion resource:

```text
CallResolutionObservation
  subject call-site occurrence
  predicate possibleTarget
  object function occurrence
  generatedBy analyzer activity
  certainty static_may
  confidence optional calibrated score
  sourceSnapshot exact snapshot
  semanticsProfile exact profile
```

This avoids relying on RDF-star, which `elixir-ontologies` documents but did not
implement at the inspected revision, and which JidoCode's current ontology
loader/backend contract does not require.

### Segmented immutable publication

A realistic structural/expression graph cannot fit JidoCode's existing 400
statement source command or 10,000-quad semantic snapshot. Introduce a new
versioned topology rather than mutating the existing contract.

Recommended shape:

```text
source analysis manifest graph
  - repository and tree snapshot
  - ontology/extractor/profile/configuration identity
  - expected segment inventory and digests
  - coverage and unsupported units
  - lifecycle building -> closed

source unit segment graphs
  - one file/module or bounded group of units
  - immutable after publication
  - independently digestible and idempotent
  - fewer than the backend/query safety ceiling

source cross-reference segment graphs
  - bounded edges partitioned by source occurrence or package
  - exact target identities or unresolved target descriptors

optional deep-expression segments
  - built only for selected files/tasks or a separately admitted full profile
  - disposable/rebuildable if not accepted as durable source history
```

Publication protocol:

1. Create the manifest in `building` state with exact expected segment
   commitments.
2. Publish each immutable segment through a governed, idempotent command.
3. Validate segment identity, graph family, schema, size, literals, provenance,
   source paths, and digest.
4. Close the manifest only after the exact expected segment set exists and
   coverage/omissions are recorded.
5. Make only closed manifests selectable for normal agent context.
6. On failure, retain complete audit/failure facts and keep any registered
   incomplete manifest available only to the accepted recovery path, never to
   normal agent selection.

This needs a new graph-registry and command protocol. A durable `building`
manifest is not compatible with the current startup gate, which permits building
completeness only for run attempts. Before multi-command source manifests exist,
an accepted startup/recovery contract must permit registered incomplete source
manifests while excluding them from normal selection; every published segment
must remain complete and immutable.

Segmentation alone also does not resolve closure or query limits. An accepted
logical-analysis-snapshot protocol must bound manifest inventory, closure
validation, authorization, reviewed query planning, pagination, and context
revision receipts without loading every segment. Until that protocol exists,
reject publication or use that exceeds the current 1,000-addition command,
20-graph semantic snapshot, or 10,000-quad semantic snapshot ceilings.

The design cannot be smuggled into the current immutable `source_revision`
identity, which has no analyzer/profile dimension and cannot be enriched after
first publication.

### Analysis revision

Every source query should bind an analysis revision derived from:

```text
repository identity
tree snapshot identity
submodule identities
dependency lock digest
build configuration digest
generated-source digest or explicit omission
extractor name and version
ontology/schema release
analysis profile and options digest
segment manifest digest
```

Write-capable agents must never query an implicit `latest`. After an edit, the
old analysis remains valid for the old tree but is stale for planning further
edits. Reindex affected units before the next graph-dependent decision or expose
the stale state explicitly.

### Incremental indexing

Use immutable snapshot semantics with reusable extraction, not in-place graph
mutation:

1. compare old/new tree entries;
2. reuse only intermediate extraction results for unchanged units when every
   analysis input is identical;
3. re-emit every persisted segment with artifact, symbol, span, and relation
   identities bound to the new `TreeSnapshot`;
4. rebuild changed units and affected cross-reference units;
5. publish a new manifest referencing only segments for that exact snapshot;
6. preserve both revisions;
7. compute graph diffs as derived evidence.

Glean demonstrates a production alternative using stacked databases, units, and
fact ownership. It reports about 7% storage overhead for ownership, 2-3% Python
indexing overhead, under 10% overhead for typical queries, and larger penalties
for search-heavy queries [S43-S44]. JidoCode should use those results as design
evidence, not import Glean's storage model into its sole TripleStore authority.

### Query funnel and context compiler

```text
user issue / failing evidence
  -> term, path, symbol, and stack-frame extraction
  -> authorize repository, snapshot, source graphs, and scope-keyed indexes
  -> exact/lexical search
  -> canonical entity resolution
  -> reviewed one-hop graph expansion
  -> relation-aware ranking and degree control
  -> exact source-span reads from verified worktree
  -> compact source-context projection with receipts and omissions
  -> existing Factory.Execution.ContextPackage
  -> model reasoning/editing
  -> graph refresh plus build/test/static verification
```

Ranking signals may include:

- lexical/entity match;
- relation type and direction;
- graph distance;
- source/test evidence;
- changed-since relation;
- direct issue/stack trace link;
- certainty class;
- degree penalty for hubs;
- recency of runtime evidence;
- source-token cost.

Authorization and visibility filtering precede candidate generation, cache
lookup, and ranking. They are eligibility checks, not relevance signals.

The source-context compiler validates query receipts before constructing the
existing `Factory.Execution.ContextPackage`. The package carries selected
`source_items` and exact `source_graph_revisions`, not per-item receipts. This
does not replace or weaken the package's approved-plan, task, lease/fence, actor,
agent, capability, effects, source revision, budget, omission, or digest checks.

Recommended initial budgets:

- 20 entity search results;
- 8 neighbors per entity;
- one graph hop by default;
- two hops only through a named relation profile and smaller degree budget;
- 100 graph nodes for an impact observation;
- 5 relevance paths per returned source span;
- separate graph-metadata and source-token budgets;
- explicit unexpanded frontier;
- no complete-graph serialization into model context.

### Store and index posture

The embedded RDF quad store remains the authoritative application-owned fact
store. Specialized indexes may be useful for:

- lexical symbol lookup;
- adjacency/path acceleration;
- embeddings;
- source-span lookup;
- graph ranking.

They must be disposable, derivable only from authorized graph/source inputs,
version committed, scope-keyed, and authorization/visibility filtered before
candidate generation, lookup, cache access, or ranking. They are never a fallback
authority. An external Neo4j, Joern, Glean, or upstream `elixir-ontologies` store
cannot become an ungoverned parallel product store under the accepted ADR.

## Integrating `elixir-ontologies` safely

### Schema import is not instance import

Two independent decisions are required:

1. Which external ontology terms or ideas become part of a JidoCode ontology
   release?
2. Which extractor outputs are admitted as facts for a source snapshot?

JidoCode should vendor reviewed ontology artifacts locally with commit, digest,
license, attribution, compatibility notes, and term mappings. Runtime
`owl:imports` network fetches are not acceptable. The current ontology loader
rejects blank nodes, so external artifacts must be checked and, if necessary,
deterministically skolemized or represented through a deliberately revised
loader contract.

Do not silently equate existing Jido terms with external terms:

- existing `Module`, `Function`, and `Reference` values act as undeclared
  concepts, while the external ontology models classes;
- existing `SourceArtifact` and policy concept `SourceFile` have different
  modeling roles;
- broad `jf:dependsOn` spans source and work domains;
- policy ownership must not become source-code ownership;
- external evolution concepts overlap existing JidoCode provenance, run,
  evidence, decision, and repository-control contracts.

Use explicit mappings only after domain/range, inference, authority, and query
effects are reviewed.

### Adapter boundary

A candidate adapter should implement the existing port:

```text
JidoCode.Integrations.ElixirOntologyAnalyzer
  implements JidoCode.Factory.Ports.SourceAnalyzer
```

It should:

- receive JidoCode's verified exact worktree and request;
- use JidoCode file discovery, symlink policy, path normalization, byte/file,
  timeout, and cancellation limits;
- invoke pinned `FileAnalyzer.analyze_string/3`; treat
  `expression_identity_base` only as a full-expression scope and replace all
  accepted instance identities with JidoCode snapshot-scoped identities;
- disable source-text and redundant Git metadata output;
- transform approved upstream classes/properties into canonical JidoCode
  occurrence identities;
- emit explicit coverage and unsupported semantics;
- retain no store handle;
- perform no network access;
- return an untrusted bounded result for separate publication.

The adapter must not call upstream project scanning or knowledge-graph commands.

### Start with a structural profile

The first profile should include only facts that can be evaluated rigorously:

- adapter-synthesized, digest-validated artifacts and source spans;
- flat modules and `def`/`defp` functions only from source units containing no
  nested `defmodule`; reject or mark other units unsupported until ownership is
  fixed;
- aliases/imports/requires/uses/behaviours as distinct relations where output is
  fixture-proven;
- adapter-owned syntactic call-site occurrences, without pretending targets are
  resolved;
- reliable struct/field or basic OTP markers only after feature-specific gold
  fixtures pass;
- explicit unsupported, omitted, generated, and dynamic warnings.

Defer nested-module hierarchy, ordered clause facts, macros, specs/types,
top-level protocols/implementations, complete expressions, control/data flow,
evolution, Phoenix/Ecto overlays, and runtime topology until upstream or adapter
fixes have feature-specific evidence and capacity results.

### Preserve JidoCode authority boundaries

The richer source graph may inform:

- candidate location;
- context selection;
- impact observations;
- plan obligations;
- verification questions.

It may not itself grant:

- command or tool capability;
- permission to read source outside scope;
- authority to edit or publish;
- acceptance of evidence;
- approval of a decision;
- adoption of memory or policy;
- permission to skip tests;
- permission to execute macros or project code.

## Threat model and failure modes

### Source and prompt injection

Repository text is untrusted. Comments, docs, identifiers, generated labels, and
string literals can contain instructions aimed at a model. Structural triples
reduce but do not remove this risk because labels and source spans eventually
enter context.

Controls:

- keep source content in clearly delimited data channels;
- exclude comments/docs by default from structural context;
- never interpret graph literals as policy or tool commands;
- maintain sink-bound context permits;
- redact secrets before model delivery;
- record which source spans entered each invocation.

### Extractor and ontology supply-chain compromise

A malicious or compromised extractor can fabricate edges that steer the agent
toward sensitive or incorrect code. An ontology change can alter inference or
query meaning without changing source.

Controls:

- pin source commit and dependency lock;
- record executable/package digest where feasible;
- sandbox extraction with no credentials/network;
- validate output against a closed local contract;
- compare deterministic output in fixtures;
- sign or digest segment artifacts;
- version every query and reasoning profile;
- require ontology review and migration plans.

### Static-analysis false precision

Macros, protocols, dynamic dispatch, `apply/3`, `Module.concat/2`, runtime
configuration, Registry/Via names, messages, generated modules, Erlang calls,
NIFs, and missing dependencies can make static edges incomplete or overbroad.

Controls:

- use certainty-specific predicates;
- preserve unresolved calls;
- expose unsupported files/units;
- distinguish authored from generated and observed facts;
- combine static, runtime, and lexical evidence;
- fail destructive workflows conservatively.

### Staleness and mixed revisions

An agent may edit a file and then query the old graph, or combine source spans
from different trees.

Controls:

- explicit analysis revision on every request/result;
- artifact content digest on every source span;
- no implicit latest for write workflows;
- source-item query receipts validated before package construction; the existing
  package carries selected source items and exact source graph revisions;
- invalidate changed units immediately;
- rebuild before graph-dependent post-edit planning;
- final complete reanalysis for high-risk workflows.

### Query denial of service

High-degree nodes, property paths, broad regex, optional joins, and expression
graphs can consume excessive time and memory.

Controls:

- reviewed fixed queries;
- typed terms, not query fragments;
- graph and predicate allowlists;
- required snapshot and starting entity;
- hop, row, byte, graph, degree, and timeout limits;
- cost tests against worst-case repositories;
- no remote `SERVICE`;
- pagination/frontier receipts.

### Cross-scope leakage

Cross-repository paths or caches may reveal names and code from unauthorized
repositories.

Controls:

- authorize graphs before query execution;
- bind owner scope in every segment;
- visibility-filter before ranking/cache lookup;
- scope-key every disposable index and cache;
- return no existence signal for unauthorized entities.

### Incomplete graph interpreted as absence

Parse failures or unsupported macros may make a callback, use, or dependency
appear absent.

Controls:

- separate graph closure from source coverage;
- carry per-unit coverage;
- prohibit closed-world absence conclusions on incomplete profiles;
- include truncation/omissions in every result;
- retain lexical fallback.

### Unsafe extraction

Compiling or expanding untrusted Elixir can execute Mix tasks, macros, build
scripts, and dependency code.

Controls:

- syntax-only default;
- no dependency install or code execution in baseline extraction;
- separate trusted expansion profile;
- disposable sandbox, no host credentials/network, read-only inputs, bounded
  CPU/memory/time/output;
- generated-to-authored provenance;
- never treat expansion failure as source absence.

### Over-trusting graph verification

A patch may satisfy a structural query and still be behaviorally wrong.

Controls:

- graph checks are observations;
- compilation, tests, static/security analysis, and acceptance remain
  independent evidence;
- no source graph relation can assert evidence acceptance or decision approval.

## Evaluation plan

### Questions

1. Does the graph improve file, function, and complete edit-site localization?
2. Does it improve patch correctness after controlling for model and budget?
3. Which Elixir relations contribute useful signal?
4. What traversal depth and presentation minimize tokens and latency?
5. How accurate and complete is extraction on real Elixir code?
6. How quickly can an edited tree receive a safe fresh analysis?
7. Does provenance improve debugging and reviewer trust?
8. Do false or stale edges cause unsafe edits?

### Corpus

Use fixed, redistribution-compatible snapshots containing:

- JidoCode and sibling Jido projects;
- Phoenix applications;
- OTP-heavy services;
- protocol/behaviour-heavy libraries;
- macro-heavy libraries;
- umbrella projects;
- mixed Elixir/Erlang projects;
- repositories with generated code and parse failures;
- held-out issues after model training cutoffs where possible.

Record every excluded repository and extraction failure. Do not silently remove
unsupported cases from the denominator.

### Extractor quality metrics

- module/function/clause precision and recall;
- source-span validity;
- definition-reference resolution precision and recall;
- function-level call-site ownership accuracy;
- target resolution precision/recall by certainty class;
- behaviour/protocol implementation accuracy;
- supervision edge accuracy;
- files/bytes/functions covered;
- parse/unsupported/generated-unit rate;
- deterministic graph digest across repeated extraction;
- no raw source, absolute path, credential, or host leakage;
- full and incremental indexing time;
- triples and bytes per file/function/profile.

Build hand-reviewed gold fixtures for Elixir features. Do not infer quality from
SHACL conformance alone.

### Retrieval ablations

Hold model, prompts, temperature, editor, tests, task order, source snapshot, and
budget constant. Compare:

- grep/exact symbols only;
- lexical/BM25 only;
- embeddings only;
- repository tree/skeleton;
- source graph only;
- lexical plus one-hop graph;
- lexical plus two-hop graph;
- lexical plus graph plus runtime evidence;
- graph with edge types removed one at a time;
- graph with shuffled edges as a negative control;
- raw triples versus compact paths versus source annotations;
- direct query generation versus fixed semantic tools, in a research-only
  sandbox.

### Agent outcome metrics

- file Acc@k;
- function Acc@k;
- line/range localization;
- recall of every accepted-patch edit site;
- changed-file precision/recall;
- patch application and compile rate;
- tests resolved and regressions introduced;
- issue-resolution rate;
- unnecessary files/lines edited;
- human acceptance/review time;
- model tokens and graph/source context tokens;
- tool calls, latency, wall time, and cost;
- repeated-run variance;
- stale-edge and invalid-result rate;
- percentage of decisions backed by valid evidence paths.

### Tool-specific metrics

| Tool | Metrics |
| --- | --- |
| Impact | affected-symbol recall, false candidates, path validity |
| Test selection | fault detection, test reduction, missed failing tests |
| Migration | old API references remaining, build/test success, edit count |
| Security slice | known path recall, false paths, fix acceptance |
| Architecture | known violation recall, false positives, query latency |
| Dead code | false deletion rate, review rejection, rollback incidents |
| Graph diff | edge-change precision, rename continuity accuracy |
| Multi-agent partition | overlapping edits, conflicts, duplicate work, elapsed time |

### Reliability and statistics

- paired task instances;
- at least five repeated stochastic runs for agent outcomes;
- confidence intervals and per-repository reporting;
- predeclared primary metrics;
- exact benchmark variant and denominator;
- report graph build cost separately from query/agent cost;
- test stale graphs intentionally at increasing commit distance;
- inject parse failures, high-degree hubs, malicious source labels, and incorrect
  edges;
- preserve all query, context, patch, and verification receipts.

### Initial success gates

Before source graph retrieval influences production write planning:

- no authorization or cross-scope leakage in adversarial tests;
- deterministic complete-manifest publication;
- exact artifact/source-span digest verification;
- no false "complete" status after failed units;
- p95 reviewed-query latency inside the agreed interactive budget;
- bounded result size on hub-heavy repositories;
- measurable function-localization gain over lexical/tree baseline;
- no regression in issue resolution under equal token/cost budget;
- call-site ownership and source-span precision meet a declared threshold;
- stale graph is rejected or visibly degraded;
- post-edit graph refresh is reliable;
- required tests remain mandatory.

Do not set numeric extraction thresholds until the gold corpus and baseline have
been measured. A threshold chosen without a denominator creates false assurance.

## Phased roadmap

### Phase 0: contract decisions

Produce accepted decisions for:

- source ontology release and term alignment;
- occurrence and source-span identity;
- authored versus analysis versus runtime relation semantics;
- segmented graph family and manifest lifecycle;
- multiple analyzer/profile identity for one source snapshot;
- source-content read policy;
- graph capacity and retention;
- query/tool capability scopes;
- incomplete coverage and closed-world rules;
- ontology and extractor licensing/attribution.

Resolve existing issues first:

- source predicates used by implementation but absent from the current ontology
  package;
- the 800-request versus 400-publication statement mismatch;
- source projection accepting only query catalog `1.1.0` while current catalog
  versions carry source queries forward;
- repeated reference identity/cardinality across artifacts;
- same-snapshot analyzer upgrade targeting an already closed graph;
- semantic-snapshot 10,000-quad ceiling;
- source query absence from product query security;
- no production source-analysis coordinator.

### Phase 1: pinned offline adapter benchmark

- pin `elixir-ontologies` commit and dependency lock;
- remove or isolate unused store/network dependencies in an evaluation fork;
- call contextual per-file analysis only;
- disable source text and upstream Git/evolution output;
- create hand-reviewed feature fixtures;
- compare emitted RDF, not extractor availability;
- measure corrected structural-profile size, determinism, coverage, latency, and
  accuracy;
- file upstream defects or maintain a minimal adapter patch set.

No production publication occurs in this phase.

### Phase 2: ontology and segmented publication

- release a new immutable JidoCode ontology package with attribution;
- define source-specific classes/properties and SHACL-compatible shapes;
- implement canonical occurrence/span identities;
- add manifest and source-segment graph families;
- add governed create-segment/close-manifest commands;
- enforce exact expected segment set and digest commitments;
- update capacity, retention, backup, restore, and migration tests;
- preserve current source graphs immutably, create validated target graphs
  through governed migration commands, and accept explicit startup compatibility
  semantics for retained prior-release source graphs before activating the new
  ontology.

### Phase 3: reviewed source tools

Implement a minimal set:

1. `search_source_entities`
2. `inspect_source_entity`
3. `find_definitions_and_references`
4. `find_callers`
5. `find_implementations`
6. `get_source_neighborhood`
7. `explain_dependency_path`
8. `analyze_change_impact`

Add a trusted context compiler that consumes query receipts and exact source
spans and supplies bounded `source_items` to the existing
`Factory.Execution.ContextPackage`. Do not let callers manually label arbitrary
context items as fresh or accepted, and do not weaken existing plan,
lease/fence, authority, effect, revision, budget, or digest checks.

### Phase 4: shadow agent evaluation

- run graph retrieval beside current lexical/tree retrieval;
- do not let graph output authorize additional tools or edits;
- compare localization, context, cost, and final outcomes;
- inspect false paths and missing Elixir semantics;
- tune relation profiles, degree caps, and one-hop defaults;
- promote only tools with measured benefit.

### Phase 5: specialized overlays

Add independently versioned profiles only when justified:

- compiler/macro expansion;
- OTP runtime and trace evidence;
- Phoenix/Ecto semantics;
- data-flow/security analysis;
- coverage/test relationships;
- temporal graph diff and change history;
- multi-language Erlang/native boundaries.

Each overlay needs its own producer, coverage, certainty semantics, shapes,
queries, budgets, and evaluation.

## Alternatives considered

### Continue with grep and repository trees only

Pros:

- simple, fresh, cheap, robust;
- strong baseline;
- no extractor/schema burden.

Cons:

- weak multi-hop relation explanation;
- poorer structural impact and conformance queries;
- no stable source entity/provenance layer.

Research recommendation: retain as the first retrieval stage and fallback, not
the only source intelligence.

### Put the full source AST in every prompt

Pros:

- no query planning;
- model sees raw detail.

Cons:

- infeasible context size;
- high noise and cost;
- evidence shows broad context can reduce performance;
- leaks more untrusted source text.

Research recommendation: reject.

### Let the model write arbitrary SPARQL

Pros:

- flexible exploratory questions;
- CodexGraph shows query-language interaction can be capable with strong models.

Cons:

- query injection, denial of service, unauthorized graph selection;
- unstable semantics and hard-to-review costs;
- CodexGraph depended heavily on a translator and used substantially more tokens;
- conflicts with accepted reviewed-query contracts.

Research recommendation: reject for production. Research may compare a
constrained parser and template planner inside a sandbox.

### Use Neo4j/Joern/Glean as a second durable source authority

Pros:

- mature traversal or code analysis;
- specialized performance.

Cons:

- violates current sole-authority ADR;
- creates revision, authorization, backup, and retention split brain;
- external schema/query semantics can bypass JidoCode governance.

Research recommendation: reject under the current ADR. External analyzers may
produce evidence; disposable projections may accelerate queries.

### Import raw `elixir-ontologies` RDF

Pros:

- quickest apparent route to broad semantics.

Cons:

- incompatible subject identities and closed vocabulary;
- output far exceeds current graph bounds;
- normal pipeline drops advertised data;
- call ownership, validation, output, and incrementality defects;
- overlaps existing provenance/evolution authority;
- no stable release.

Research recommendation: reject. Transform an evaluated subset through a new
adapter and closed publication contract.

### Use embeddings only

Pros:

- semantic matching across natural-language issues and code;
- useful for unknown symbol names.

Cons:

- similarity does not encode dependency or path semantics;
- weak deterministic explanation and revision consistency;
- approximate results cannot prove absence or conformance.

Research recommendation: after authorizing the scope-keyed index, use embeddings
as an optional disposable first-stage retriever, then resolve already authorized
results to authoritative graph/source entities.

## Final recommendation

Proceed with a bounded evaluation of `elixir-ontologies`, not a production
integration.

The architecture target should be a revision-pinned source knowledge graph that
acts as a semantic map and evidence layer for coding agents. Its primary product
value is not storing more code facts. Its value is answering a closed set of
high-value questions with exact identity, provenance, uncertainty, and bounded
context:

- What entity does this issue refer to?
- Which source spans are structurally connected, and why?
- What could this change affect?
- Which Elixir contracts and runtime patterns are involved?
- What remains to be edited?
- Did the new source graph change as expected?
- Which independent evidence establishes correctness?

The implementation order matters:

1. fix source ontology, identity, and graph topology contracts;
2. measure a pinned structural extractor against gold Elixir fixtures;
3. publish closed, segmented, provenance-rich source facts;
4. expose reviewed semantic tools, not raw SPARQL;
5. combine lexical anchoring with one-hop graph expansion;
6. compile source spans, reasons, uncertainty, and omissions into context;
7. reindex after edits and verify independently;
8. add deep expression, framework, data-flow, dynamic, and temporal overlays only
   when each demonstrates incremental benefit.

The result can give JidoCode a distinctive advantage: coding agents that can
navigate Elixir's actual language and OTP structure while remaining constrained
by exact snapshots, graph authority, capability boundaries, provenance,
retention, and executable verification.

## Sources

### Inspected projects and local architecture

- **S1.** pcharbon70, [Elixir Ontologies repository](https://github.com/pcharbon70/elixir-ontologies/tree/fb2432ae666062b8d0d601f742abbadda0583b02), inspected commit `fb2432ae666062b8d0d601f742abbadda0583b02`, 2026.
- **S2.** Elixir Ontologies, [README and ontology overview](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/README.md), 2026.
- **S3.** Elixir Ontologies, [`mix.exs`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/mix.exs), package and dependency metadata, 2026.
- **S4.** Elixir Ontologies, [`FileAnalyzer`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/analyzer/file_analyzer.ex), [`Function` extractor](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/extractors/function.ex), and [`Module` extractor](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/extractors/module.ex), contextual analysis, ownership, and bounds, 2026.
- **S5.** Elixir Ontologies, [`Pipeline`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/pipeline.ex) and [`elixir_ontologies.update`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/mix/tasks/elixir_ontologies.update.ex), conversion, pipeline, and persisted incremental-update behavior, 2026.
- **S6.** Elixir Ontologies, [`Builders.Orchestrator`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/orchestrator.ex), [`ModuleBuilder`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/module_builder.ex), [`FunctionBuilder`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/function_builder.ex), [`ClauseBuilder`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/clause_builder.ex), and [`CallGraphBuilder`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/builders/call_graph_builder.ex), 2026.
- **S7.** Elixir Ontologies, [`Graph`](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/graph.ex) and [SHACL SPARQL validator](https://github.com/pcharbon70/elixir-ontologies/blob/fb2432ae666062b8d0d601f742abbadda0583b02/lib/elixir_ontologies/shacl/validators/sparql.ex), 2026.

The local JidoCode conclusions additionally derive from:

- `docs/adr/0001-graph-only-source-of-truth.md`
- `docs/adr/0002-triple-store-backend-contract.md`
- `docs/architecture/source-analysis.md`
- `docs/architecture/graph-identity-and-topology.md`
- `docs/architecture/reviewed-query-catalog.md`
- `docs/architecture/query-consistency-and-temporal-state.md`
- `docs/research/secure-effective-agent-harness.md`
- `docs/research/total-agent-memory-for-software-engineering.md`
- `lib/jido_code/integrations/elixir_source_analyzer.ex`
- `lib/jido_code/knowledge/commands/publish_source_graph.ex`
- `lib/jido_code/knowledge/query_catalog.ex`
- `lib/jido_code/knowledge/query_source.ex`
- `lib/jido_code/knowledge/projections/source.ex`
- `lib/jido_code/knowledge/graph_registry.ex`
- `lib/jido_code/knowledge/semantic_snapshot.ex`
- `lib/jido_code/knowledge/resource_identity.ex`

### Foundations, ontologies, and standards

- **S8.** Ferrante, Ottenstein, and Warren, [The Program Dependence Graph and Its Use in Optimization](https://doi.org/10.1145/24039.24041), ACM TOPLAS, 1987.
- **S9.** Horwitz, Reps, and Binkley, [Interprocedural Slicing Using Dependence Graphs](https://doi.org/10.1145/77606.77608), ACM TOPLAS, 1990.
- **S10.** Reps, Horwitz, and Sagiv, [Precise Interprocedural Dataflow Analysis via Graph Reachability](https://doi.org/10.1145/199448.199462), POPL, 1995.
- **S11.** Yamaguchi et al., [Modeling and Discovering Vulnerabilities with Code Property Graphs](https://doi.org/10.1109/SP.2014.44), IEEE Symposium on Security and Privacy, 2014.
- **S12.** Joern, [Code Property Graph documentation](https://docs.joern.io/code-property-graph/), accessed 2026-08-15.
- **S13.** Joern, [CPG schema](https://cpg.joern.io/) and [CPG slicing](https://docs.joern.io/cpg-slicing/), accessed 2026-08-15.
- **S14.** Atzeni and Atzori, [CodeOntology: RDF-ization of Source Code](https://doi.org/10.1007/978-3-319-68204-4_2), ISWC, 2017.
- **S15.** Wuersch et al., [SEON: a pyramid of ontologies for software evolution and its applications](https://doi.org/10.1007/s00607-012-0204-1), Computing, 2012.
- **S16.** Kiefer, Bernstein, and Tappolet, [Mining Software Repositories with iSPAROL and a Software Evolution Ontology](https://doi.org/10.1109/MSR.2007.21), MSR, 2007.
- **S17.** OMG, [Knowledge Discovery Metamodel 1.4](https://www.omg.org/spec/KDM/1.4/About-KDM), 2016.
- **S18.** W3C, [RDF 1.1 Concepts](https://www.w3.org/TR/rdf11-concepts/), [SPARQL 1.1 Query Language](https://www.w3.org/TR/sparql11-query/), [PROV-O](https://www.w3.org/TR/prov-o/), and [SHACL](https://www.w3.org/TR/shacl/).

### Learned program representations

- **S19.** Li et al., [Gated Graph Sequence Neural Networks](https://arxiv.org/abs/1511.05493), ICLR, 2016.
- **S20.** Allamanis, Brockschmidt, and Khademi, [Learning to Represent Programs with Graphs](https://arxiv.org/abs/1711.00740), ICLR, 2018.
- **S21.** Guo et al., [GraphCodeBERT: Pre-training Code Representations with Data Flow](https://arxiv.org/abs/2009.08366), ICLR, 2021.
- **S22.** Hellendoorn et al., [Global Relational Models of Source Code](https://openreview.net/forum?id=B1lnbRNtwr), ICLR, 2020.
- **S23.** Zhou et al., [Devign: Effective Vulnerability Identification by Learning Comprehensive Program Semantics via Graph Neural Networks](https://arxiv.org/abs/1909.03496), NeurIPS, 2019.
- **S24.** Cummins et al., [ProGraML: A Graph-based Program Representation for Data Flow Analysis and Compiler Optimizations](https://proceedings.mlr.press/v139/cummins21a.html), ICML, 2021.

### Repository graphs, retrieval, and coding agents

- **S25.** Liu et al., [CodexGraph: Bridging Large Language Models and Code Repositories via Code Graph Databases](https://aclanthology.org/2025.naacl-long.7/), NAACL, 2025.
- **S26.** Ouyang et al., [RepoGraph: Enhancing AI Software Engineering with Repository-level Code Graph](https://arxiv.org/abs/2410.14684), ICLR, 2025.
- **S27.** Chen et al., [LocAgent: Graph-Guided LLM Agents for Code Localization](https://aclanthology.org/2025.acl-long.426/), ACL, 2025.
- **S28.** Liu et al., [GraphCoder: Enhancing Repository-Level Code Completion via Coarse-to-fine Retrieval Based on Code Context Graph](https://doi.org/10.1145/3691620.3695054), ASE, 2024.
- **S29.** Bairi et al., [CodePlan: Repository-level Coding using LLMs and Planning](https://doi.org/10.1145/3643757), PACMSE/FSE, 2024.
- **S30.** Chen et al., [CodeR: Issue Resolving with Multi-Agent and Task Graphs](https://arxiv.org/abs/2406.01304), preprint, 2024.
- **S31.** Zhang et al., [RepoCoder: Repository-Level Code Completion Through Iterative Retrieval and Generation](https://aclanthology.org/2023.emnlp-main.151/), EMNLP, 2023.
- **S32.** Yang et al., [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering](https://arxiv.org/abs/2405.15793), NeurIPS, 2024.
- **S33.** Xia et al., [Demystifying LLM-Based Software Engineering Agents](https://doi.org/10.1145/3715754), PACMSE/FSE, 2025; earlier preprint titled Agentless, 2024.
- **S34.** Cheng, Wu, and Hu, [DraCo: Dataflow-Guided Retrieval Augmentation for Repository-Level Code Completion](https://aclanthology.org/2024.acl-long.431/), ACL, 2024.
- **S35.** Phan et al., [RepoHyper: Search-Expand-Refine on Semantic Graphs for Repository-Level Code Completion](https://doi.org/10.1109/FORGE66646.2025.00009), FORGE, 2025.
- **S36.** Yu et al., [OrcaLoca: An LLM Agent Framework for Software Issue Localization](https://arxiv.org/abs/2502.00350), preprint, 2025.
- **S37.** Lin et al., [How Much Static Structure Do Code Agents Need? A Study of Deterministic Anchoring](https://arxiv.org/abs/2606.26979), 2026 preprint; manuscript states acceptance at ISSTA 2026.
- **S38.** Jimenez et al., [SWE-bench: Can Language Models Resolve Real-World GitHub Issues?](https://arxiv.org/abs/2310.06770), ICLR, 2024.

### Production systems, articles, and engineering blogs

- **S39.** GitHub, [About data flow analysis in CodeQL](https://codeql.github.com/docs/writing-codeql-queries/about-data-flow-analysis/) and [CodeQL CLI overview](https://docs.github.com/en/code-security/codeql-cli/about-the-codeql-cli), accessed 2026-08-15.
- **S40.** SCIP, [Code Intelligence Protocol](https://scip-code.org/), accessed 2026-08-15.
- **S41.** Sourcegraph, [Announcing SCIP](https://sourcegraph.com/blog/announcing-scip) and [Lessons from building AI coding assistants: context retrieval and evaluation](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation), accessed 2026-08-15.
- **S42.** Kythe, [An Overview of Kythe](https://kythe.io/docs/kythe-overview.html) and [Writing an Indexer](https://kythe.io/docs/schema/writing-an-indexer.html), accessed 2026-08-15.
- **S43.** Glean, [Introduction](https://glean.software/docs/introduction/) and [Databases](https://glean.software/docs/databases/), accessed 2026-08-15.
- **S44.** Marlow, [Incremental indexing with Glean](https://glean.software/blog/incremental/), Glean engineering blog, 2022.
- **S45.** Shackleton, Pincombe, and Cohn-Gordon, [Automating dead code cleanup](https://engineering.fb.com/2023/10/24/data-infrastructure/automating-dead-code-cleanup/), Engineering at Meta, 2023.
- **S46.** Gauthier, [Aider repository map](https://aider.chat/docs/repomap.html), accessed 2026-08-15.
- **S47.** Semgrep, [Perform cross-file analysis](https://semgrep.dev/docs/semgrep-code/semgrep-pro-engine-intro), accessed 2026-08-15.
- **S48.** Sourcegraph, [Precise code navigation](https://sourcegraph.com/docs/code-search/code-navigation/precise_code_navigation), accessed 2026-08-15.
- **S49.** Collard et al., [srcML: An Infrastructure for the Exploration, Analysis, and Manipulation of Source Code: A Tool Demonstration](https://doi.org/10.1109/ICSM.2013.85), ICSM, 2013, and [srcML project](https://www.srcml.org/).
- **S50.** GitHub, [Found means fixed: Secure code more than three times faster with Copilot Autofix](https://github.blog/news-insights/product-news/secure-code-more-than-three-times-faster-with-copilot-autofix/), product-reported beta data, 2024.

## Milestones

1. Corrected structural source profile: typed call relations, deterministic
   source spans, ordered clauses, and occurrence-scoped identities.
2. Segmented source publication: manifest and immutable segment protocol within
   accepted capacity and snapshot bounds.
3. Reviewed semantic tool surface: search, definitions/references, neighborhood,
   and impact tools bounded and authorized through the query catalog.
4. Hybrid retrieval service: lexical anchoring resolving to revision-pinned
   entities with bounded one-hop expansion and ranked source spans.
5. Pinned elixir-ontologies adapter spike: bounded contextual file API evaluated
   behind the SourceAnalyzer port with a closed admission contract.
6. Impact and migration planning: evidence-path impact queries and edit-obligation
   planning tools over the enriched graph.
7. Measured adoption: graph-assisted retrieval validated against exact, lexical,
   and skeleton baselines before influencing production execution.
